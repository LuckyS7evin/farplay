// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay : test des agrandisseurs (lavapipe). Usage : upscale_test <shader.glsl> [<shader2.glsl> ...]
// Image de référence 1280x720, réduite ×2 (moyenne 2×2), puis agrandie ×2 par
// libplacebo seul et par chaque shader : PSNR de luminance face à la référence.
// Échec si un shader ne se charge pas, ne s'exécute pas, ou fait pire que libplacebo seul de plus de 1 dB.
#include <libplacebo/vulkan.h>
#include <libplacebo/renderer.h>
#include <libplacebo/shaders/custom.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <string>
static const int W = 1280, H = 720, LW = W / 2, LH = H / 2;
static float hsh(int x, int y) { unsigned h = x * 374761393u + y * 668265263u; h = (h ^ (h >> 13)) * 1274126177u; return (h & 0xffff) / 65535.f; }
static float vn(float x, float y) {
    int ix = (int)floorf(x), iy = (int)floorf(y); float fx = x - ix, fy = y - iy; fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
    float a = hsh(ix, iy), b = hsh(ix + 1, iy), c = hsh(ix, iy + 1), d = hsh(ix + 1, iy + 1);
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}
int main(int argc, char **argv)
{
    pl_log_params lp = {}; lp.log_cb = pl_log_color; lp.log_level = PL_LOG_WARN;
    pl_log log = pl_log_create(PL_API_VER, &lp);
    pl_vulkan_params vp = pl_vulkan_default_params; vp.allow_software = true;
    pl_vulkan vk = pl_vulkan_create(log, &vp);
    if (!vk) return 2;
    pl_gpu gpu = vk->gpu;
    // Référence : texture douce + bords nets (rayures fines, disque, texte simulé)
    std::vector<float> ref(W * H);
    for (int y = 0; y < H; y++)
        for (int x = 0; x < W; x++) {
            float v = 0.25f + 0.5f * vn(x / 40.f, y / 40.f) + 0.15f * vn(x / 6.f, y / 6.f);
            if (x > 100 && x < 500 && y > 100 && y < 400) v = ((int)((x + 0.5f * y) / 9) % 2) ? 0.85f : 0.15f;
            float dx = x - 900.f, dy = y - 360.f;
            if (dx * dx + dy * dy < 150.f * 150.f) v = 0.9f;
            if (y > 600 && y < 620 && (x / 7) % 3 != 0 && x > 200 && x < 1100) v = 0.05f;
            ref[y * W + x] = std::min(1.f, std::max(0.f, v));
        }
    std::vector<float> low(LW * LH);
    for (int y = 0; y < LH; y++)
        for (int x = 0; x < LW; x++)
            low[y * LW + x] = 0.25f * (ref[2 * y * W + 2 * x] + ref[2 * y * W + 2 * x + 1] + ref[(2 * y + 1) * W + 2 * x] + ref[(2 * y + 1) * W + 2 * x + 1]);
    std::vector<float> chroma(LW * LH * 2, 0.5f);
    pl_fmt fr = pl_find_named_fmt(gpu, "r32f"), frg = pl_find_named_fmt(gpu, "rg32f"), fo = pl_find_named_fmt(gpu, "rgba32f");
    auto mk = [&](pl_fmt fm, int w, int h, const void *d, bool rd) {
        pl_tex_params tp = {}; tp.w = w; tp.h = h; tp.format = fm; tp.sampleable = true; tp.renderable = rd;
        tp.host_writable = true; tp.host_readable = true; tp.storable = rd && (fm->caps & PL_FMT_CAP_STORABLE);
        pl_tex t = pl_tex_create(gpu, &tp);
        if (d) { pl_tex_transfer_params up = {}; up.tex = t; up.ptr = (void *)d; pl_tex_upload(gpu, &up); }
        return t;
    };
    pl_tex ty = mk(fr, LW, LH, low.data(), false), tc = mk(frg, LW, LH, chroma.data(), false), out = mk(fo, W, H, nullptr, true);
    pl_renderer rr = pl_renderer_create(log, gpu);
    auto run = [&](const pl_hook *hook, std::vector<float> &res) {
        pl_frame s = {}; s.num_planes = 2;
        s.planes[0].texture = ty; s.planes[0].components = 1; s.planes[0].component_mapping[0] = PL_CHANNEL_Y;
        s.planes[1].texture = tc; s.planes[1].components = 2; s.planes[1].component_mapping[0] = PL_CHANNEL_CB; s.planes[1].component_mapping[1] = PL_CHANNEL_CR;
        s.repr = pl_color_repr_sdtv; s.repr.sys = PL_COLOR_SYSTEM_BT_709; s.repr.levels = PL_COLOR_LEVELS_FULL; s.color = pl_color_space_srgb;
        s.crop = {0, 0, (float)LW, (float)LH};
        pl_frame t = {}; t.num_planes = 1; t.planes[0].texture = out; t.planes[0].components = 4;
        for (int i = 0; i < 4; i++) t.planes[0].component_mapping[i] = i;
        t.repr = pl_color_repr_rgb; t.color = pl_color_space_srgb; t.crop = {0, 0, (float)W, (float)H};
        pl_render_params p = pl_render_default_params; p.hooks = &hook; p.num_hooks = hook ? 1 : 0; p.deband_params = nullptr; p.dither_params = nullptr;
        if (!pl_render_image(rr, &s, &t, &p)) return false;
        res.resize(W * H * 4); pl_tex_transfer_params dl = {}; dl.tex = out; dl.ptr = res.data();
        return pl_tex_download(gpu, &dl);
    };
    auto psnr = [&](const std::vector<float> &a) {
        double s = 0; int c = 0;
        for (int y = 8; y < H - 8; y++)
            for (int x = 8; x < W - 8; x++) {
                const float *p = &a[(y * W + x) * 4];
                double yy = 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2];
                double d = yy - ref[y * W + x]; s += d * d; c++;
            }
        return 10 * log10(1.0 / (s / c));
    };
    std::vector<float> base;
    if (!run(nullptr, base)) { puts("rendu de base impossible"); return 1; }
    const double p0 = psnr(base);
    printf("libplacebo seul : %.2f dB\n", p0);
    int rc = 0;
    for (int i = 1; i < argc; i++) {
        FILE *f = fopen(argv[i], "rb"); if (!f) { printf("%s : introuvable\n", argv[i]); rc = 1; continue; }
        fseek(f, 0, 2); long n = ftell(f); rewind(f); std::string src(n, 0);
        if (fread(&src[0], 1, n, f) != (size_t)n) return 2; fclose(f);
        const pl_hook *hook = pl_mpv_user_shader_parse(gpu, src.data(), src.size());
        std::vector<float> res;
        if (!hook || !run(hook, res)) { printf("%s : ÉCHEC (chargement ou exécution)\n", argv[i]); rc = 1; continue; }
        const double p1 = psnr(res);
        printf("%s : %.2f dB (%+.2f)\n", argv[i], p1, p1 - p0);
        if (p1 < p0 - 1.0) { printf("ÉCHEC : nettement moins bon que libplacebo seul\n"); rc = 1; }
        pl_mpv_user_shader_destroy(&hook);
    }
    return rc;
}
