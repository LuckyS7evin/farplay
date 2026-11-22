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
    upscaler_.store(std::clamp(st.value(QStringLiteral("image/upscaler"), 1).toInt(), 0, 3));
    sharpness_.store(std::clamp(st.value(QStringLiteral("image/sharpness"), 30).toInt(), 0, 100));
    deband_.store(std::clamp(st.value(QStringLiteral("image/deband"), 1).toInt(), 0, 2));
    sdr_to_hdr_.store(st.value(QStringLiteral("image/sdr_to_hdr"), true).toBool());
    sdr_white_.store(std::clamp(st.value(QStringLiteral("image/sdr_white_nits"), 200).toInt(), 80, 400));
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
    st.setValue(QStringLiteral("image/sdr_to_hdr"), sdrToHdr());
    st.setValue(QStringLiteral("image/sdr_white_nits"), sdrWhiteNits());
    emit changed();
}

void Image::setUpscaler(int v) { v = std::clamp(v, 0, 3); if (v != upscaler()) { upscaler_.store(v); save(); } }
void Image::setSharpness(int v) { v = std::clamp(v, 0, 100); if (v != sharpness()) { sharpness_.store(v); save(); } }
void Image::setDeband(int v) { v = std::clamp(v, 0, 2); if (v != deband()) { deband_.store(v); save(); } }
void Image::setSdrToHdr(bool v) { if (v != sdrToHdr()) { sdr_to_hdr_.store(v); save(); } }
void Image::setSdrWhiteNits(int v) { v = std::clamp(v, 80, 400); if (v != sdrWhiteNits()) { sdr_white_.store(v); save(); } }

void Image::resetRecommended()
{
    upscaler_.store(1);
    sharpness_.store(30);
    deband_.store(1);
    sdr_to_hdr_.store(true);
    sdr_white_.store(200);
    save();
}

void Image::initGpu(pl_gpu gpu)
{
    destroyGpu();
    gpu_ = gpu;
    fsr_sdr_ = loadFsr(gpu, false);
    fsr_pq_ = loadFsr(gpu, true);
}

void Image::destroyGpu()
{
    if (fsr_sdr_)
        pl_mpv_user_shader_destroy(&fsr_sdr_);
    if (fsr_pq_)
        pl_mpv_user_shader_destroy(&fsr_pq_);
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
    } else if (mode == 0) {
        hook = chiaki_hook;
        used = hook ? Stats::Upscaler::Chiaki : Stats::Upscaler::Builtin;
    } else if (mode == 1) {
        hook = source_pq ? fsr_pq_ : fsr_sdr_;
        used = Stats::Upscaler::Fsr1;
    } else if (mode == 2) {
        // FSRCNNX est un x2 : au-delà, libplacebo termine le redimensionnement.
        hook = fsrcnnx8;
        used = Stats::Upscaler::Fsrcnnx;
    }
    if (!hook && (mode == 1 || mode == 2))
        used = Stats::Upscaler::Builtin; // shader indisponible → repli libplacebo

    // Netteté : 100 % = 0 stop (maximum), 0 % = 2 stops.
    const float stops = 2.0f * (1.0f - sharpness() / 100.0f);
    setSharpnessParam(fsr_sdr_, stops);
    setSharpnessParam(fsr_pq_, stops);

    stats.setUpscaler(used, upscale_factor);
    return hook;
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
