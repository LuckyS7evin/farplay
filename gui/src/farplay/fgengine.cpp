// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#include "farplay/fgengine.h"

#include <libplacebo/shaders/custom.h>

#include <algorithm>
#include <cstdio>
#include <cstring>

namespace farplay {

namespace {

pl_shader_desc texDesc(const char *name, pl_tex tex)
{
    pl_shader_desc d = {};
    d.desc.name = name;
    d.desc.type = PL_DESC_SAMPLED_TEX;
    d.binding.object = tex;
    d.binding.address_mode = PL_TEX_ADDRESS_CLAMP;
    d.binding.sample_mode = PL_TEX_SAMPLE_LINEAR;
    return d;
}

pl_shader_var vec2Var(const char *name, const float *data)
{
    pl_shader_var v = {};
    v.var = pl_var_vec2(name);
    v.data = data;
    v.dynamic = true;
    return v;
}

pl_shader_var floatVar(const char *name, const float *data)
{
    pl_shader_var v = {};
    v.var = pl_var_float(name);
    v.data = data;
    v.dynamic = true;
    return v;
}

// --- Shaders --------------------------------------------------------------
// Toutes les passes sont des passes « couleur » : `fp_pos` (0..1) est la
// coordonnée normalisée du pixel de sortie, `color` la valeur écrite.
// Les valeurs RGB sont celles de la sortie (PQ pour du HDR10) : l'appariement
// se fait donc dans un espace perceptuel.

// Luminance du niveau 0 (1/4 de la sortie) : moyenne 4×4 via 4 lectures bilinéaires.
const char *kLumaHeader = R"(
float fp_lum(vec2 uv) { return dot(texture(src, uv).rgb, vec3(0.2627, 0.6780, 0.0593)); }
)";
const char *kLumaBody = R"(
    vec2 uv = fp_pos;
    float s = fp_lum(uv + vec2(-1.0, -1.0) * src_px) + fp_lum(uv + vec2(1.0, -1.0) * src_px)
            + fp_lum(uv + vec2(-1.0,  1.0) * src_px) + fp_lum(uv + vec2(1.0,  1.0) * src_px);
    color = vec4(0.25 * s, 0.0, 0.0, 1.0);
)";

// Réduction ×2 : une lecture bilinéaire au coin commun des 4 texels source.
const char *kDownBody = R"(
    color = vec4(texture(src, fp_pos).r, 0.0, 0.0, 1.0);
)";

// Appariement de blocs 5×5 autour d'une prédiction (niveau plus grossier),
// rayon de recherche FP_R, pénalité de régularité, candidat « immobile »
// favorisé (zones fixes / HUD), affinage sous-pixel parabolique.
const char *kFlowHeader = R"(
float fp_a[25];
float fp_sad(vec2 uv, vec2 d) {
    float s = 0.0;
    int n = 0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            s += abs(fp_a[n] - texture(lb, uv + d + vec2(float(i), float(j)) * px).r);
            n++;
        }
    }
    return s;
}
)";
const char *kFlowBodyFmt = R"(
    vec2 uv = fp_pos;
    {
        int n = 0;
        for (int j = -2; j <= 2; j++) {
            for (int i = -2; i <= 2; i++) {
                fp_a[n] = texture(la, uv + vec2(float(i), float(j)) * px).r;
                n++;
            }
        }
    }
    // Prédicteurs : flux du niveau grossier au pixel et chez ses voisins
    // (propagation façon 3DRS), flux de la paire précédente (cohérence temporelle).
    vec2 v0 = vec2(0.0);
    float bp = fp_sad(uv, v0);
    %s
    float best = 1e9;
    vec2 bd = v0;
    for (int y = -%d; y <= %d; y++) {
        for (int x = -%d; x <= %d; x++) {
            vec2 d = v0 + vec2(float(x), float(y)) * px;
            float c = fp_sad(uv, d) + lambda * float(abs(x) + abs(y));
            if (c < best) { best = c; bd = d; }
        }
    }
    float cz = 0.9 * fp_sad(uv, vec2(0.0));
    if (cz <= best) { best = cz; bd = vec2(0.0); }
    float bc = fp_sad(uv, bd);
    float cx0 = fp_sad(uv, bd - vec2(px.x, 0.0)), cx1 = fp_sad(uv, bd + vec2(px.x, 0.0));
    float cy0 = fp_sad(uv, bd - vec2(0.0, px.y)), cy1 = fp_sad(uv, bd + vec2(0.0, px.y));
    float sx = 0.5 * (cx0 - cx1) / max(cx0 - 2.0 * bc + cx1, 1e-5);
    float sy = 0.5 * (cy0 - cy1) / max(cy0 - 2.0 * bc + cy1, 1e-5);
    bd += vec2(clamp(sx, -0.5, 0.5) * px.x, clamp(sy, -0.5, 0.5) * px.y);
    color = vec4(bd, bc * (1.0 / 25.0), 1.0);
)";

// Médiane vectorielle 3×3 (élimine les vecteurs aberrants).
const char *kMedianBody = R"(
    vec2 v[9];
    float cost = texture(src, fp_pos).z;
    int n = 0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            v[n] = texture(src, fp_pos + vec2(float(i), float(j)) * px).xy;
            n++;
        }
    }
    int bi = 4;
    float bs = 1e9;
    for (int a = 0; a < 9; a++) {
        float s = 0.0;
        for (int b = 0; b < 9; b++) {
            vec2 dd = abs(v[a] - v[b]);
            s += dd.x + dd.y;
        }
        if (s < bs) { bs = s; bi = a; }
    }
    color = vec4(v[bi], cost, 1.0);
)";

// Synthèse à la phase t : moyenne des deux images recalées le long du flux,
// repli sur l'image la plus proche dans le temps en cas d'occlusion
// (désaccord entre les deux échantillons), et pixels fixes (HUD, textes)
// recopiés sans déplacement.
const char *kSynthHeader = R"(
float fp_max3(vec3 c) { return max(c.r, max(c.g, c.b)); }
)";
const char *kSynthBody = R"(
    vec2 uv = fp_pos;
    vec4 a0 = texture(ta, uv);
    vec4 b0 = texture(tb, uv);
    // Sélection du vecteur par pixel parmi le flux local, ses voisins et
    // « immobile » : corrige les blocs à cheval sur deux mouvements (bords
    // d'objets, décor autour du HUD).
    vec2 v = texture(flow, uv).xy;
    vec4 a = texture(ta, uv - t * v);
    vec4 b = texture(tb, uv + (1.0 - t) * v);
    float be = fp_max3(abs(a.rgb - b.rgb));
    for (int k = 1; k < 6; k++) {
        vec2 o = k == 1 ? vec2(1.5, 0.0) : (k == 2 ? vec2(-1.5, 0.0) : (k == 3 ? vec2(0.0, 1.5) : vec2(0.0, -1.5)));
        vec2 c = k == 5 ? vec2(0.0) : texture(flow, uv + o * flow_px).xy;
        vec4 ca = texture(ta, uv - t * c);
        vec4 cb = texture(tb, uv + (1.0 - t) * c);
        float ce = fp_max3(abs(ca.rgb - cb.rgb)) + 0.01;
        if (ce < be) { be = ce; v = c; a = ca; b = cb; }
    }
    vec4 mc = mix(a, b, t);
    float err = fp_max3(abs(a.rgb - b.rgb));
    vec4 near = t < 0.5 ? a : b;
    vec4 res = mix(mc, near, smoothstep(0.03, 0.10, err));
    float sdiff = fp_max3(abs(a0.rgb - b0.rgb));
    float w_static = hud * (1.0 - smoothstep(0.004, 0.02, sdiff));
    res = mix(res, mix(a0, b0, t), w_static);
    color = vec4(res.rgb, 1.0);
)";

} // namespace

bool FgEngine::init(pl_gpu gpu, pl_log log)
{
    destroy();
    gpu_ = gpu;
    log_ = log;
    dp_ = pl_dispatch_create(log, gpu);
    if (!dp_) {
        gpu_ = nullptr;
        return false;
    }
    pl_dispatch_callback(dp_, this, &FgEngine::dispatchInfo);
    const pl_fmt_caps caps = static_cast<pl_fmt_caps>(PL_FMT_CAP_RENDERABLE | PL_FMT_CAP_SAMPLEABLE | PL_FMT_CAP_LINEAR);
    fmt_rgba_ = pl_find_fmt(gpu, PL_FMT_FLOAT, 4, 16, 16, caps);
    fmt_r_ = pl_find_fmt(gpu, PL_FMT_FLOAT, 1, 16, 16, caps);
    fmt_flow_ = pl_find_fmt(gpu, PL_FMT_FLOAT, 4, 32, 32, caps);
    if (!fmt_flow_)
        fmt_flow_ = fmt_rgba_;
    fmt_va_ = pl_find_vertex_fmt(gpu, PL_FMT_FLOAT, 2);
    return ready() && fmt_va_;
}

void FgEngine::destroy()
{
    if (gpu_) {
        for (Slot &s : slots_) {
            pl_tex_destroy(gpu_, &s.rgb);
            for (pl_tex &t : s.lum)
                pl_tex_destroy(gpu_, &t);
            s = Slot{};
        }
        destroyFlow(fwd_);
        destroyFlow(bwd_);
        pl_tex_destroy(gpu_, &out_);
        pl_tex_destroy(gpu_, &dummy_);
    }
    if (dp_)
        pl_dispatch_destroy(&dp_);
    gpu_ = nullptr;
    fwd_ = FlowSet{};
    bwd_ = FlowSet{};
    num_pass_times_ = 0;
}

void FgEngine::setQuality(int q)
{
    q = std::clamp(q, 0, 2);
    if (q == quality_)
        return;
    quality_ = q;
    fwd_.valid = bwd_.valid = false;
}

void FgEngine::destroyFlow(FlowSet &fs)
{
    for (pl_tex &t : fs.lvl)
        pl_tex_destroy(gpu_, &t);
    pl_tex_destroy(gpu_, &fs.smooth);
    fs = FlowSet{};
}

void FgEngine::invalidateFlows(uint64_t sig)
{
    for (FlowSet *fs : { &fwd_, &bwd_ })
        if (fs->valid && (sig == fs->a || sig == fs->b))
            fs->valid = false;
}

void FgEngine::dispatchInfo(void *priv, const struct pl_dispatch_info *info)
{
    auto *self = static_cast<FgEngine *>(priv);
    if (!info || !info->shader || !info->shader->description)
        return;
    const char *name = info->shader->description;
    for (int i = 0; i < self->num_pass_times_; i++) {
        if (std::strncmp(self->pass_times_[i].name, name, sizeof(self->pass_times_[i].name) - 1) == 0) {
            self->pass_times_[i].last_ns = info->last;
            return;
        }
    }
    if (self->num_pass_times_ < kMaxPasses) {
        PassTime &p = self->pass_times_[self->num_pass_times_++];
        std::snprintf(p.name, sizeof(p.name), "%s", name);
        p.last_ns = info->last;
    }
}

FgEngine::Timings FgEngine::timings()
{
    Timings t;
    for (int i = 0; i < num_pass_times_; i++) {
        const double ms = pass_times_[i].last_ns / 1e6;
        if (std::strncmp(pass_times_[i].name, "fg-pyr", 6) == 0)
            t.pyramid_ms += ms;
        else if (std::strncmp(pass_times_[i].name, "fg-flow", 7) == 0)
            t.flow_ms += ms;
        else if (std::strncmp(pass_times_[i].name, "fg-synth", 8) == 0)
            t.synth_ms += ms;
    }
    return t;
}

bool FgEngine::ensureTex(pl_tex *tex, pl_fmt fmt, int w, int h)
{
    w = std::max(w, 1);
    h = std::max(h, 1);
    if (*tex && (*tex)->params.w == w && (*tex)->params.h == h && (*tex)->params.format == fmt)
        return true;
    pl_tex_params p = {};
    p.w = w;
    p.h = h;
    p.format = fmt;
    p.sampleable = true;
    p.renderable = true;
    p.storable = (fmt->caps & PL_FMT_CAP_STORABLE) != 0;
    p.host_writable = host_io_;
    p.host_readable = host_io_;
    return pl_tex_recreate(gpu_, tex, &p);
}

FgEngine::Slot *FgEngine::find(uint64_t sig)
{
    for (Slot &s : slots_)
        if (s.rgb && s.sig == sig)
            return &s;
    return nullptr;
}

const FgEngine::Slot *FgEngine::find(uint64_t sig) const
{
    for (const Slot &s : slots_)
        if (s.rgb && s.sig == sig)
            return &s;
    return nullptr;
}

pl_tex FgEngine::acquireSlot(uint64_t sig, int w, int h, bool *needs_render)
{
    *needs_render = false;
    if (!ready())
        return nullptr;
    Slot *s = find(sig);
    if (s && s->valid && s->rgb->params.w == w && s->rgb->params.h == h) {
        s->lru = ++lru_clock_;
        return s->rgb;
    }
    if (!s) {
        s = &slots_[0];
        for (Slot &c : slots_)
            if (!c.rgb || c.lru < s->lru)
                s = &c;
        if (s->rgb)
            invalidateFlows(s->sig);
    }
    if (!ensureTex(&s->rgb, fmt_rgba_, w, h))
        return nullptr;
    s->sig = sig;
    s->valid = false;
    s->lru = ++lru_clock_;
    *needs_render = true;
    return s->rgb;
}

pl_tex FgEngine::slotTexture(uint64_t sig) const
{
    const Slot *s = find(sig);
    return s && s->valid ? s->rgb : nullptr;
}

pl_tex FgEngine::coarseLuma(uint64_t sig) const
{
    const Slot *s = find(sig);
    return s && s->valid ? s->lum[kLevels - 1] : nullptr;
}

bool FgEngine::finishSlot(uint64_t sig)
{
    Slot *s = find(sig);
    if (!s)
        return false;
    const int w = s->rgb->params.w, h = s->rgb->params.h;
    int lw = (w + 3) / 4, lh = (h + 3) / 4;
    for (int k = 0; k < kLevels; k++) {
        if (!ensureTex(&s->lum[k], fmt_r_, lw, lh))
            return false;
        lw = (lw + 1) / 2;
        lh = (lh + 1) / 2;
    }
    {
        const float src_px[2] = { 1.0f / w, 1.0f / h };
        pl_shader_desc d = texDesc("src", s->rgb);
        pl_shader_var v = vec2Var("src_px", src_px);
        if (!pass(s->lum[0], "fg-pyr-L0", kLumaHeader, kLumaBody, &d, 1, &v, 1))
            return false;
    }
    for (int k = 1; k < kLevels; k++) {
        pl_shader_desc d = texDesc("src", s->lum[k - 1]);
        char name[16];
        std::snprintf(name, sizeof(name), "fg-pyr-L%d", k);
        if (!pass(s->lum[k], name, "", kDownBody, &d, 1, nullptr, 0))
            return false;
    }
    s->valid = true;
    invalidateFlows(s->sig);
    return true;
}

bool FgEngine::computeFlow(Slot &a, Slot &b, FlowSet &fs, int final_level)
{
    {
        const pl_tex fl = a.lum[final_level];
        if (!fs.smooth || fs.smooth->params.w != fl->params.w || fs.smooth->params.h != fl->params.h)
            fs.has_tprev = false;
    }
    for (int k = kLevels - 1; k >= final_level; k--) {
        const int lw = a.lum[k]->params.w, lh = a.lum[k]->params.h;
        if (!ensureTex(&fs.lvl[k], fmt_flow_, lw, lh))
            return false;
        const bool coarsest = k == kLevels - 1;
        // Rayon de recherche (pixels du niveau) selon la qualité. Au niveau le plus
        // fin la prédiction du niveau supérieur est déjà bonne : rayon réduit.
        static constexpr int kCoarse[3] = { 3, 4, 6 }, kMid[3] = { 1, 2, 3 }, kFine[3] = { 1, 1, 2 };
        const int radius = coarsest ? kCoarse[quality_] : (k == 0 ? kFine[quality_] : kMid[quality_]);
        char body[4096];
        const char *pred_coarse =
            "if (use_tprev > 0.5) { for (int k = 0; k < 5; k++) {"
            " vec2 o = k == 0 ? vec2(0.0) : (k == 1 ? vec2(2.0, 0.0) : (k == 2 ? vec2(-2.0, 0.0) : (k == 3 ? vec2(0.0, 2.0) : vec2(0.0, -2.0))));"
            " vec2 c = texture(tprev, uv + o * px).xy; float cs = fp_sad(uv, c); if (cs < bp) { bp = cs; v0 = c; } } }";
        const char *pred_fine =
            "v0 = texture(prev, uv).xy; bp = fp_sad(uv, v0);"
            " for (int k = 1; k < 5; k++) {"
            " vec2 o = k == 1 ? vec2(2.0, 0.0) : (k == 2 ? vec2(-2.0, 0.0) : (k == 3 ? vec2(0.0, 2.0) : vec2(0.0, -2.0)));"
            " vec2 c = texture(prev, uv + o * px).xy; float cs = fp_sad(uv, c); if (cs < 0.97 * bp) { bp = cs; v0 = c; } }"
            " if (use_tprev > 0.5) { vec2 c = texture(tprev, uv).xy; float cs = fp_sad(uv, c); if (cs < 0.97 * bp) { bp = cs; v0 = c; } }";
        std::snprintf(body, sizeof(body), kFlowBodyFmt, coarsest ? pred_coarse : pred_fine,
                      radius, radius, radius, radius);
        const float px[2] = { 1.0f / lw, 1.0f / lh };
        const float lambda = 0.004f;
        // Flux temporel : résultat de la paire précédente (ou un flux nul au départ).
        const float use_tprev = fs.has_tprev ? 1.0f : 0.0f;
        // Sans flux précédent, « tprev » n'est pas lu mais doit être lié : une petite
        // texture à part (lier deux fois la même texture invalide la passe).
        if (!fs.has_tprev && !ensureTex(&dummy_, fmt_flow_, 1, 1))
            return false;
        pl_shader_desc descs[4] = { texDesc("la", a.lum[k]), texDesc("lb", b.lum[k]),
                                    texDesc("tprev", fs.has_tprev ? fs.smooth : dummy_) };
        int nd = 3;
        if (!coarsest)
            descs[nd++] = texDesc("prev", fs.lvl[k + 1]);
        pl_shader_var vars[3] = { vec2Var("px", px), floatVar("lambda", &lambda), floatVar("use_tprev", &use_tprev) };
        char name[16];
        std::snprintf(name, sizeof(name), "fg-flow-L%d", k);
        if (!pass(fs.lvl[k], name, kFlowHeader, body, descs, nd, vars, 3))
            return false;
    }
    const pl_tex f = fs.lvl[final_level];
    if (!ensureTex(&fs.smooth, fmt_flow_, f->params.w, f->params.h))
        return false;
    const float px[2] = { 1.0f / f->params.w, 1.0f / f->params.h };
    pl_shader_desc d = texDesc("src", f);
    d.binding.sample_mode = PL_TEX_SAMPLE_NEAREST;
    pl_shader_var v = vec2Var("px", px);
    if (!pass(fs.smooth, "fg-flow-median", "", kMedianBody, &d, 1, &v, 1))
        return false;
    fs.has_tprev = true;
    return true;
}

bool FgEngine::copyInto(pl_tex src, pl_tex dst)
{
    if (!src || !dst)
        return false;
    pl_shader_desc d = texDesc("src", src);
    return pass(dst, "fg-copy", "", "    color = texture(src, fp_pos);\n", &d, 1, nullptr, 0);
}

pl_tex FgEngine::flowFor(uint64_t sig_a, uint64_t sig_b)
{
    Slot *a = find(sig_a);
    Slot *b = find(sig_b);
    if (!a || !b || !a->valid || !b->valid)
        return nullptr;
    if (!bwd_.valid || bwd_.a != sig_a || bwd_.b != sig_b) {
        // Blocs de B cherchés dans A : vecteur B→A en chaque pixel de B.
        if (!computeFlow(*b, *a, bwd_, bwdLevel()))
            return nullptr;
        bwd_.a = sig_a;
        bwd_.b = sig_b;
        bwd_.valid = true;
    }
    return bwd_.smooth;
}

pl_tex FgEngine::synthesize(uint64_t sig_a, uint64_t sig_b, float t, bool hud_protect)
{
    Slot *a = find(sig_a);
    Slot *b = find(sig_b);
    if (!a || !b || !a->valid || !b->valid)
        return nullptr;
    if (a->rgb->params.w != b->rgb->params.w || a->rgb->params.h != b->rgb->params.h)
        return nullptr;
    if (!fwd_.valid || fwd_.a != sig_a || fwd_.b != sig_b) {
        if (!computeFlow(*a, *b, fwd_, fwdLevel()))
            return nullptr;
        fwd_.a = sig_a;
        fwd_.b = sig_b;
        fwd_.valid = true;
    }
    if (!ensureTex(&out_, fmt_rgba_, a->rgb->params.w, a->rgb->params.h))
        return nullptr;
    const float tt = std::clamp(t, 0.0f, 1.0f);
    const float hud = hud_protect ? 1.0f : 0.0f;
    pl_shader_desc descs[3] = { texDesc("ta", a->rgb), texDesc("tb", b->rgb), texDesc("flow", fwd_.smooth) };
    const float flow_px[2] = { 1.0f / fwd_.smooth->params.w, 1.0f / fwd_.smooth->params.h };
    pl_shader_var vars[3] = { floatVar("t", &tt), floatVar("hud", &hud), vec2Var("flow_px", flow_px) };
    if (!pass(out_, "fg-synth", kSynthHeader, kSynthBody, descs, 3, vars, 3))
        return nullptr;
    return out_;
}

bool FgEngine::pass(pl_tex target, const char *desc, const char *header, const char *body,
                    const struct pl_shader_desc *descs, int num_descs,
                    const struct pl_shader_var *vars, int num_vars)
{
    static const float c00[2] = { 0.0f, 0.0f }, c10[2] = { 1.0f, 0.0f };
    static const float c01[2] = { 0.0f, 1.0f }, c11[2] = { 1.0f, 1.0f };
    pl_shader sh = pl_dispatch_begin(dp_);
    pl_shader_va va = {};
    va.attr.name = "fp_pos";
    va.attr.fmt = fmt_va_;
    va.data[0] = c00;
    va.data[1] = c10;
    va.data[2] = c01;
    va.data[3] = c11;
    pl_custom_shader cs = {};
    cs.description = desc;
    cs.header = header;
    cs.body = body;
    cs.input = PL_SHADER_SIG_NONE;
    cs.output = PL_SHADER_SIG_COLOR;
    cs.descriptors = descs;
    cs.num_descriptors = num_descs;
    cs.variables = vars;
    cs.num_variables = num_vars;
    cs.vertex_attribs = &va;
    cs.num_vertex_attribs = 1;
    if (!pl_shader_custom(sh, &cs)) {
        pl_dispatch_abort(dp_, &sh);
        return false;
    }
    pl_dispatch_params p = {};
    p.shader = &sh;
    p.target = target;
    return pl_dispatch_finish(dp_, &p);
}

} // namespace farplay
