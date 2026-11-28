// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#include "farplay/farplayimage.h"
#include "farplay/farplaystats.h"

#include <libplacebo/renderer.h>
#include <libplacebo/shaders/custom.h>

#include <QFile>
#include <QQmlEngine>
#include <QSettings>

#include <algorithm>
#include <cstring>

namespace farplay {

namespace {

QSettings farplaySettings()
{
    return QSettings(QStringLiteral("Farplay"), QStringLiteral("Farplay"));
}

const struct pl_hook *loadFsr(pl_gpu gpu, bool pq)
{
    QFile file(QStringLiteral(":/farplay/shaders/FSR.glsl"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return nullptr;
    QByteArray src = file.readAll();
    if (pq)
        src.replace("#define FSR_PQ 0", "#define FSR_PQ 1");
    return pl_mpv_user_shader_parse(gpu, src.constData(), static_cast<size_t>(src.size()));
}

const struct pl_hook *loadShader(pl_gpu gpu, const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return nullptr;
    const QByteArray src = file.readAll();
    return pl_mpv_user_shader_parse(gpu, src.constData(), static_cast<size_t>(src.size()));
}

void setFloatParam(const struct pl_hook *hook, const char *name, float v)
{
    if (!hook)
        return;
    for (int i = 0; i < hook->num_parameters; i++) {
        const struct pl_hook_par &p = hook->parameters[i];
        if (p.data && p.name && std::strcmp(p.name, name) == 0)
            p.data->f = v;
    }
}

void setSharpnessParam(const struct pl_hook *hook, float stops)
{
    if (!hook)
        return;
    for (int i = 0; i < hook->num_parameters; i++) {
        const struct pl_hook_par &p = hook->parameters[i];
        if (p.data && p.name && std::strcmp(p.name, "farplay_sharpness") == 0)
            p.data->f = stops;
    }
}

// Lissage des dégradés (debanding libplacebo), sans grain ajouté au niveau faible.
const struct pl_deband_params kDebandLow = { .iterations = 1, .threshold = 2.0f, .radius = 16.0f, .grain = 0.0f };
const struct pl_deband_params kDebandMedium = { .iterations = 2, .threshold = 3.0f, .radius = 16.0f, .grain = 2.0f };

} // namespace

Image &Image::instance()
{
    static Image *s = new Image();
    return *s;
}

Image::Image(QObject *parent)
    : QObject(parent)
{
    QSettings st = farplaySettings();
    // Choix d'agrandissement : 1 = FSR 1, 2 = NIS. Avant, 2 désignait FSRCNNX et
    // 0/3 les modes chiaki-ng/libplacebo, retirés : tout ancien réglage → FSR 1.
    if (!st.value(QStringLiteral("image/upscaler_v2"), false).toBool()) {
        st.setValue(QStringLiteral("image/upscaler"), 1);
        st.setValue(QStringLiteral("image/upscaler_v2"), true);
    }
    upscaler_.store(std::clamp(st.value(QStringLiteral("image/upscaler"), 1).toInt(), 1, 2));
    sharpness_.store(std::clamp(st.value(QStringLiteral("image/sharpness"), 50).toInt(), 0, 100));
    deband_.store(std::clamp(st.value(QStringLiteral("image/deband"), 1).toInt(), 0, 2));
    denoise_.store(std::clamp(st.value(QStringLiteral("image/denoise"), 2).toInt(), 0, 3));
    cfl_.store(st.value(QStringLiteral("image/chroma_from_luma"), true).toBool());
    sdr_to_hdr_.store(st.value(QStringLiteral("image/sdr_to_hdr"), true).toBool());
    sdr_white_.store(std::clamp(st.value(QStringLiteral("image/sdr_white_nits"), 200).toInt(), 80, 400));
    contrast_.store(std::clamp(st.value(QStringLiteral("image/contrast"), 0).toInt(), -50, 50));
    saturation_.store(std::clamp(st.value(QStringLiteral("image/saturation"), 0).toInt(), -50, 50));
    vibrance_.store(std::clamp(st.value(QStringLiteral("image/vibrance"), 0).toInt(), 0, 100));
}

void Image::registerQml()
{
    QQmlEngine::setObjectOwnership(&instance(), QQmlEngine::CppOwnership);
    qmlRegisterSingletonInstance("org.streetpea.chiaking", 1, 0, "FarplayImage", &instance());
}

void Image::save()
{
    QSettings st = farplaySettings();
    st.setValue(QStringLiteral("image/upscaler"), upscaler());
    st.setValue(QStringLiteral("image/sharpness"), sharpness());
    st.setValue(QStringLiteral("image/deband"), deband());
    st.setValue(QStringLiteral("image/denoise"), denoise());
    st.setValue(QStringLiteral("image/chroma_from_luma"), chromaFromLuma());
    st.setValue(QStringLiteral("image/sdr_to_hdr"), sdrToHdr());
    st.setValue(QStringLiteral("image/sdr_white_nits"), sdrWhiteNits());
    st.setValue(QStringLiteral("image/contrast"), contrast());
    st.setValue(QStringLiteral("image/saturation"), saturation());
    st.setValue(QStringLiteral("image/vibrance"), vibrance());
    emit changed();
}

void Image::setUpscaler(int v) { v = std::clamp(v, 1, 2); if (v != upscaler()) { upscaler_.store(v); save(); } }
void Image::setSharpness(int v) { v = std::clamp(v, 0, 100); if (v != sharpness()) { sharpness_.store(v); save(); } }
void Image::setDeband(int v) { v = std::clamp(v, 0, 2); if (v != deband()) { deband_.store(v); save(); } }
void Image::setDenoise(int v) { v = std::clamp(v, 0, 3); if (v != denoise()) { denoise_.store(v); save(); } }
void Image::setChromaFromLuma(bool v) { if (v != chromaFromLuma()) { cfl_.store(v); save(); } }
void Image::setSdrToHdr(bool v) { if (v != sdrToHdr()) { sdr_to_hdr_.store(v); save(); } }
void Image::setSdrWhiteNits(int v) { v = std::clamp(v, 80, 400); if (v != sdrWhiteNits()) { sdr_white_.store(v); save(); } }
void Image::setContrast(int v) { v = std::clamp(v, -50, 50); if (v != contrast()) { contrast_.store(v); save(); } }
void Image::setSaturation(int v) { v = std::clamp(v, -50, 50); if (v != saturation()) { saturation_.store(v); save(); } }
void Image::setVibrance(int v) { v = std::clamp(v, 0, 100); if (v != vibrance()) { vibrance_.store(v); save(); } }

void Image::resetColor()
{
    contrast_.store(0);
    saturation_.store(0);
    vibrance_.store(0);
    save();
}

void Image::resetRecommended()
{
    upscaler_.store(1);
    sharpness_.store(50);
    deband_.store(1);
    denoise_.store(2);
    cfl_.store(true);
    sdr_to_hdr_.store(true);
    sdr_white_.store(200);
    contrast_.store(0);
    saturation_.store(0);
    vibrance_.store(0);
    save();
}

void Image::initGpu(pl_gpu gpu)
{
    destroyGpu();
    gpu_ = gpu;
    fsr_sdr_ = loadFsr(gpu, false);
    fsr_pq_ = loadFsr(gpu, true);
    if (!fsr_sdr_ || !fsr_pq_)
        qWarning("Farplay: échec du chargement du shader FSR 1 (repli libplacebo)");
    deartifact_ = loadShader(gpu, QStringLiteral(":/farplay/shaders/Deartifact.glsl"));
    cfl_hook_ = loadShader(gpu, QStringLiteral(":/farplay/shaders/ChromaFromLuma.glsl"));
    nis_ = loadShader(gpu, QStringLiteral(":/farplay/shaders/NIS.glsl"));
    if (!nis_)
        qWarning("Farplay: échec du chargement du shader NIS (repli libplacebo)");
    post_color_ = loadShader(gpu, QStringLiteral(":/farplay/shaders/PostColor.glsl"));
    if (!post_color_)
        qWarning("Farplay: échec du chargement du shader de post-traitement couleur");
    if (!cfl_hook_)
        qWarning("Farplay: échec du chargement du shader de chroma");
    if (!deartifact_)
        qWarning("Farplay: échec du chargement du shader de réduction d'artefacts");
}

void Image::destroyGpu()
{
    if (fsr_sdr_)
        pl_mpv_user_shader_destroy(&fsr_sdr_);
    if (fsr_pq_)
        pl_mpv_user_shader_destroy(&fsr_pq_);
    if (deartifact_)
        pl_mpv_user_shader_destroy(&deartifact_);
    if (cfl_hook_)
        pl_mpv_user_shader_destroy(&cfl_hook_);
    if (nis_)
        pl_mpv_user_shader_destroy(&nis_);
    if (post_color_)
        pl_mpv_user_shader_destroy(&post_color_);
    gpu_ = nullptr;
}

bool Image::isHdrTransfer(enum pl_color_transfer trc)
{
    return trc == PL_COLOR_TRC_PQ || trc == PL_COLOR_TRC_HLG;
}

const struct pl_hook *Image::selectHook(bool source_pq, float upscale_factor,
                                        const struct pl_hook *chiaki_hook,
                                        const struct pl_hook *fsrcnnx8)
{
    Stats &stats = Stats::instance();
    const int mode = upscaler();
    const struct pl_hook *hook = nullptr;
    Stats::Upscaler used = Stats::Upscaler::Builtin;

    if (upscale_factor <= 1.0f) {
        hook = nullptr;
        used = Stats::Upscaler::None;
    } else if (mode == 2) {
        hook = nis_;
        used = Stats::Upscaler::Nis;
    } else {
        hook = source_pq ? fsr_pq_ : fsr_sdr_;
        used = Stats::Upscaler::Fsr1;
    }
    if (!hook && upscale_factor > 1.0f)
        used = Stats::Upscaler::Fallback; // shader indisponible → repli libplacebo, signalé
    Q_UNUSED(chiaki_hook);
    Q_UNUSED(fsrcnnx8);

    // Netteté FSR 1 : 100 % = 0 stop (maximum), 0 % = 2 stops.
    const float stops = 2.0f * (1.0f - sharpness() / 100.0f);
    setSharpnessParam(fsr_sdr_, stops);
    setSharpnessParam(fsr_pq_, stops);
    // Netteté NIS (0..1, 0,25 par défaut chez NVIDIA) : 50 % → 0,25, 100 % → 0,5.
    // Constante de spécialisation : un changement recompile le shader une fois.
    setFloatParam(nis_, "Sharpness", sharpness() / 200.0f);

    stats.setUpscaler(used, upscale_factor);
    return hook;
}

int Image::buildHooks(const struct pl_hook *upscale_hook, const struct pl_hook **out, bool source_pq)
{
    // Force (écart de patch toléré en valeur de code) et part de l'image filtrée.
    // Réglés sur un test synthétique bruit + blocs 8x8 : +2 / +4 / +5 dB.
    // Allégés après le test sur GTA : au niveau fort, le feuillage lointain
    // (texture fine de faible contraste) était lissé comme du bruit.
    static constexpr float kH[4] = {0.0f, 0.012f, 0.02f, 0.03f};
    static constexpr float kMix[4] = {0.0f, 0.6f, 0.8f, 0.9f};
    int n = 0;
    if (chromaFromLuma() && cfl_hook_)
        out[n++] = cfl_hook_;
    const int level = denoise();
    if (level > 0 && deartifact_) {
        setFloatParam(deartifact_, "farplay_denoise_h", kH[level]);
        setFloatParam(deartifact_, "farplay_denoise_mix", kMix[level]);
        out[n++] = deartifact_;
    }
    if (upscale_hook)
        out[n++] = upscale_hook;
    if (post_color_ && (contrast() != 0 || saturation() != 0 || vibrance() != 0)) {
        setFloatParam(post_color_, "farplay_contrast", contrast() / 100.0f);
        setFloatParam(post_color_, "farplay_saturation", saturation() / 100.0f);
        setFloatParam(post_color_, "farplay_vibrance", vibrance() / 100.0f);
        // Gris moyen : ~18 % en sRGB (0,45), ~100 nits en PQ (0,51)
        setFloatParam(post_color_, "farplay_pivot", source_pq ? 0.51f : 0.45f);
        out[n++] = post_color_;
    }
    Stats::instance().setDenoiseActive((level > 0 && deartifact_) || (chromaFromLuma() && cfl_hook_));
    return n;
}

void Image::applyRenderParams(struct pl_render_params *params)
{
    switch (deband()) {
    case 0: params->deband_params = nullptr; break;
    case 1: params->deband_params = &kDebandLow; break;
    case 2: params->deband_params = &kDebandMedium; break;
    }
}

void Image::adjustSourceColor(struct pl_color_space *color) const
{
    if (!color || isHdrTransfer(color->transfer) || !sdrToHdr())
        return;
    // Un flux SDR est "display-referred" : son blanc est affiché à max_luma.
    color->hdr.max_luma = static_cast<float>(sdrWhiteNits());
}

void Image::adjustSwapchainHint(struct pl_color_space *hint) const
{
    if (!hint || isHdrTransfer(hint->transfer) || !sdrToHdr())
        return;
    // Garder l'écran en HDR10 : libplacebo replie en SDR si la surface ne le permet pas.
    hint->primaries = PL_COLOR_PRIM_BT_2020;
    hint->transfer = PL_COLOR_TRC_PQ;
    hint->hdr = pl_hdr_metadata{};
    hint->hdr.prim = *pl_raw_primaries_get(PL_COLOR_PRIM_BT_2020);
}

} // namespace farplay
