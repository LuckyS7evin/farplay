// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Banc de test du moteur de frame gen (hors application, Vulkan quelconque,
// p. ex. lavapipe). Deux images synthétiques : un décor texturé qui défile de
// (DX, DY) pixels et un « HUD » fixe. On interpole à t = 0,5 et on compare à
// la vraie image intermédiaire (PSNR), ainsi qu'au simple fondu A/B.
//
// Construction (Linux) :
//   g++ -std=c++17 -O2 fg_test.cpp ../fgengine.cpp -I../../../include \
//       $(pkg-config --cflags --libs libplacebo) -o fg_test
#include "farplay/fgengine.h"

#include <libplacebo/vulkan.h>

#include <cmath>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <cstdlib>
#include <vector>
#include <algorithm>

namespace {

constexpr int W = 1280, H = 720;

uint16_t toHalf(float f)
{
    uint32_t x;
    std::memcpy(&x, &f, 4);
    const uint32_t sign = (x >> 16) & 0x8000;
    int32_t exp = int32_t((x >> 23) & 0xff) - 127 + 15;
    uint32_t mant = x & 0x7fffff;
    if (exp <= 0)
        return uint16_t(sign);
    if (exp >= 31)
        return uint16_t(sign | 0x7c00);
    return uint16_t(sign | (exp << 10) | (mant >> 13));
}

float fromHalf(uint16_t h)
{
    const uint32_t sign = uint32_t(h & 0x8000) << 16;
    const uint32_t exp = (h >> 10) & 0x1f;
    const uint32_t mant = h & 0x3ff;
    uint32_t x;
    if (exp == 0)
        x = sign;
    else if (exp == 31)
        x = sign | 0x7f800000 | (mant << 13);
    else
        x = sign | ((exp - 15 + 127) << 23) | (mant << 13);
    float f;
    std::memcpy(&f, &x, 4);
    return f;
}

// Décor non périodique : bruit de valeur multi-octave (évite les ambiguïtés d'appariement).
float hash2(int x, int y)
{
    uint32_t h = uint32_t(x) * 374761393u + uint32_t(y) * 668265263u;
    h = (h ^ (h >> 13)) * 1274126177u;
    return float(h ^ (h >> 16)) / 4294967295.0f;
}
float vnoise(float x, float y)
{
    const int xi = int(std::floor(x)), yi = int(std::floor(y));
    const float fx = x - xi, fy = y - yi;
    const float sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    const float a = hash2(xi, yi), b = hash2(xi + 1, yi), c = hash2(xi, yi + 1), d = hash2(xi + 1, yi + 1);
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy;
}
float scene(float x, float y)
{
    return 0.15f + 0.45f * vnoise(x / 48.0f, y / 48.0f) + 0.25f * vnoise(x / 12.0f + 7.1f, y / 12.0f + 3.3f)
         + 0.15f * vnoise(x / 3.0f + 1.7f, y / 3.0f + 9.2f);
}

bool inHud(int x, int y) { return x >= 40 && x < 280 && y >= 580 && y < 680; }

void makeFrame(std::vector<float> &rgb, float ox, float oy)
{
    rgb.resize(size_t(W) * H * 4);
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            float v = scene(x - ox, y - oy);
            float r = v, g = 0.8f * v + 0.1f, b = 0.6f * v + 0.2f;
            if (inHud(x, y)) {
                const bool txt = ((x / 6) + (y / 9)) % 3 == 0;
                r = g = b = txt ? 0.95f : 0.1f;
            }
            float *p = &rgb[(size_t(y) * W + x) * 4];
            p[0] = r; p[1] = g; p[2] = b; p[3] = 1.0f;
        }
    }
}

bool upload(pl_gpu gpu, pl_tex tex, const std::vector<float> &rgb)
{
    std::vector<uint16_t> half(rgb.size());
    for (size_t i = 0; i < rgb.size(); i++)
        half[i] = toHalf(rgb[i]);
    pl_tex_transfer_params p = {};
    p.tex = tex;
    p.ptr = half.data();
    return pl_tex_upload(gpu, &p);
}

bool download(pl_gpu gpu, pl_tex tex, std::vector<float> &rgb)
{
    std::vector<uint16_t> half(size_t(W) * H * 4);
    pl_tex_transfer_params p = {};
    p.tex = tex;
    p.ptr = half.data();
    if (!pl_tex_download(gpu, &p))
        return false;
    rgb.resize(half.size());
    for (size_t i = 0; i < half.size(); i++)
        rgb[i] = fromHalf(half[i]);
    return true;
}

// PSNR sur les canaux RGB, hors bordure (les bords entrants sont inconnus).
double psnr(const std::vector<float> &a, const std::vector<float> &b, bool hud_only = false)
{
    double se = 0.0;
    size_t n = 0;
    for (int y = 24; y < H - 24; y++) {
        for (int x = 32; x < W - 32; x++) {
            if (hud_only != inHud(x, y))
                continue;
            for (int c = 0; c < 3; c++) {
                const double d = a[(size_t(y) * W + x) * 4 + c] - b[(size_t(y) * W + x) * 4 + c];
                se += d * d;
                n++;
            }
        }
    }
    const double mse = se / double(n);
    return mse <= 1e-12 ? 99.0 : 10.0 * std::log10(1.0 / mse);
}

void writePpm(const char *path, const std::vector<float> &rgb)
{
    FILE *f = std::fopen(path, "wb");
    if (!f)
        return;
    std::fprintf(f, "P6\n%d %d\n255\n", W, H);
    for (size_t i = 0; i < size_t(W) * H; i++) {
        for (int c = 0; c < 3; c++) {
            float v = rgb[i * 4 + c];
            v = v < 0 ? 0 : (v > 1 ? 1 : v);
            std::fputc(int(v * 255.0f + 0.5f), f);
        }
    }
    std::fclose(f);
}

} // namespace

int main(int argc, char **argv)
{
    const float dx = argc > 1 ? std::atof(argv[1]) : 24.0f;
    const float dy = argc > 2 ? std::atof(argv[2]) : 10.0f;
    const char *outdir = argc > 3 ? argv[3] : nullptr;

    pl_log_params lp = {};
    lp.log_cb = pl_log_color;
    lp.log_level = PL_LOG_WARN;
    pl_log log = pl_log_create(PL_API_VER, &lp);
    pl_vulkan_params vp = pl_vulkan_default_params;
    vp.allow_software = true;
    pl_vulkan vk = pl_vulkan_create(log, &vp);
    if (!vk) {
        std::fprintf(stderr, "Vulkan indisponible\n");
        return 2;
    }
    farplay::FgEngine eng;
    eng.setHostIo(true);
    if (!eng.init(vk->gpu, log)) {
        std::fprintf(stderr, "init moteur échouée\n");
        return 3;
    }

    std::vector<float> fa, fb, fmid, out;
    makeFrame(fa, 0, 0);
    makeFrame(fb, dx, dy);
    makeFrame(fmid, dx * 0.5f, dy * 0.5f);

    bool need = false;
    pl_tex ta = eng.acquireSlot(1, W, H, &need);
    if (!ta || !upload(vk->gpu, ta, fa) || !eng.finishSlot(1)) { std::fprintf(stderr, "slot A\n"); return 4; }
    pl_tex tb = eng.acquireSlot(2, W, H, &need);
    if (!tb || !upload(vk->gpu, tb, fb) || !eng.finishSlot(2)) { std::fprintf(stderr, "slot B\n"); return 4; }

    pl_tex o = eng.synthesize(1, 2, 0.5f, true);
    if (!o || !download(vk->gpu, o, out)) { std::fprintf(stderr, "synthèse échouée\n"); return 5; }

    for (int lv = -1; lv < farplay::FgEngine::kLevels; lv++) {
        pl_tex ft = eng.debugFlow(lv);
        if (!ft || (lv >= 0 && lv < farplay::FgEngine::kFlowLevel))
            continue;
        const int fw = ft->params.w, fh = ft->params.h;
        std::vector<float> fl(size_t(fw) * fh * 4);
        pl_tex_transfer_params tp = {};
        tp.tex = ft;
        tp.ptr = fl.data();
        if (ft->params.format->texel_size == 16 && pl_tex_download(vk->gpu, &tp)) {
            std::vector<float> xs, ys;
            for (int y = fh / 4; y < 3 * fh / 4; y++)
                for (int x = fw / 4; x < 3 * fw / 4; x++) {
                    xs.push_back(fl[(size_t(y) * fw + x) * 4] * W);
                    ys.push_back(fl[(size_t(y) * fw + x) * 4 + 1] * H);
                }
            std::sort(xs.begin(), xs.end());
            std::sort(ys.begin(), ys.end());
            std::printf("flux niveau %d (%dx%d) : médiane (%.2f, %.2f) px, quartiles x [%.2f %.2f]\n", lv, fw, fh,
                        xs[xs.size() / 2], ys[ys.size() / 2], xs[xs.size() / 4], xs[3 * xs.size() / 4]);
        }
    }

    // Vecteurs fournis à FSR : B→A sur la grille fine (L0), attendus ≈ (−dx, −dy).
    int rc_mv = 0;
    {
        pl_tex mv = eng.flowFor(1, 2);
        const int fw = mv ? mv->params.w : 0, fh = mv ? mv->params.h : 0;
        std::vector<float> fl(size_t(fw) * fh * 4);
        pl_tex_transfer_params tp = {};
        tp.tex = mv;
        tp.ptr = fl.data();
        if (!mv || mv->params.format->texel_size != 16 || !pl_tex_download(vk->gpu, &tp)) {
            std::printf("ÉCHEC : vecteurs FSR indisponibles\n");
            rc_mv = 1;
        } else {
            std::vector<float> xs, ys;
            for (int y = fh / 4; y < 3 * fh / 4; y++)
                for (int x = fw / 4; x < 3 * fw / 4; x++) {
                    xs.push_back(fl[(size_t(y) * fw + x) * 4] * W);
                    ys.push_back(fl[(size_t(y) * fw + x) * 4 + 1] * H);
                }
            std::sort(xs.begin(), xs.end());
            std::sort(ys.begin(), ys.end());
            const float mx = xs[xs.size() / 2], my = ys[ys.size() / 2];
            std::printf("vecteurs FSR B→A (%dx%d) : médiane (%.2f, %.2f) px, quartiles x [%.2f %.2f]\n", fw, fh,
                        mx, my, xs[xs.size() / 4], xs[3 * xs.size() / 4]);
            if (std::fabs(mx + dx) > 1.5f || std::fabs(my + dy) > 1.5f) {
                std::printf("ÉCHEC : vecteurs FSR éloignés de (%.1f, %.1f)\n", -dx, -dy);
                rc_mv = 1;
            }
        }
    }

    std::vector<float> blend(fa.size());
    for (size_t i = 0; i < fa.size(); i++)
        blend[i] = 0.5f * (fa[i] + fb[i]);

    std::printf("déplacement (%.1f, %.1f) px\n", dx, dy);
    std::printf("PSNR décor  : interpolé %.2f dB | fondu A/B %.2f dB | image A %.2f dB\n",
                psnr(out, fmid), psnr(blend, fmid), psnr(fa, fmid));
    std::printf("PSNR HUD    : interpolé %.2f dB | fondu A/B %.2f dB\n",
                psnr(out, fmid, true), psnr(blend, fmid, true));

    // Critères de non-régression : l'interpolation doit battre nettement le
    // fondu sur le décor et laisser le HUD intact.
    const double gain = psnr(out, fmid) - psnr(blend, fmid);
    const double hud = psnr(out, fmid, true);
    int rc = rc_mv;
    if (gain < 5.0) { std::printf("ÉCHEC : gain %.2f dB < 5 dB\n", gain); rc = 1; }
    if (hud < 40.0) { std::printf("ÉCHEC : HUD %.2f dB < 40 dB\n", hud); rc = 1; }

    if (outdir) {
        char p[512];
        std::snprintf(p, sizeof(p), "%s/a.ppm", outdir); writePpm(p, fa);
        std::snprintf(p, sizeof(p), "%s/b.ppm", outdir); writePpm(p, fb);
        std::snprintf(p, sizeof(p), "%s/mid_vrai.ppm", outdir); writePpm(p, fmid);
        std::snprintf(p, sizeof(p), "%s/mid_interp.ppm", outdir); writePpm(p, out);
        std::snprintf(p, sizeof(p), "%s/mid_fondu.ppm", outdir); writePpm(p, blend);
    }

    eng.destroy();
    pl_vulkan_destroy(&vk);
    pl_log_destroy(&log);
    return rc;
}
