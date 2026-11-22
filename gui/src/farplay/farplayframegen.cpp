// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#include "farplay/farplayframegen.h"
#include "farplay/farplaystats.h"

#include <QQmlEngine>
#include <QSettings>

#include <algorithm>
#include <cmath>

namespace farplay {

namespace {

QSettings farplaySettings()
{
    return QSettings(QStringLiteral("Farplay"), QStringLiteral("Farplay"));
}

// Image RGB (texture du moteur) dans l'espace couleur de la sortie.
pl_frame textureFrame(pl_tex tex, const pl_color_space &color)
{
    pl_frame f = {};
    f.num_planes = 1;
    f.planes[0].texture = tex;
    f.planes[0].components = 4;
    f.planes[0].component_mapping[0] = 0;
    f.planes[0].component_mapping[1] = 1;
    f.planes[0].component_mapping[2] = 2;
    f.planes[0].component_mapping[3] = 3;
    f.repr = pl_color_repr_rgb;
    f.color = color;
    f.crop.x1 = static_cast<float>(tex->params.w);
    f.crop.y1 = static_cast<float>(tex->params.h);
    return f;
}

} // namespace

FrameGen &FrameGen::instance()
{
    static FrameGen *s = new FrameGen();
    return *s;
}

FrameGen::FrameGen(QObject *parent)
    : QObject(parent)
{
    QSettings st = farplaySettings();
    mode_.store(std::clamp(st.value(QStringLiteral("framegen/mode"), 1).toInt(), 0, 2));
    const int m = st.value(QStringLiteral("framegen/multiplier"), 2).toInt();
    multiplier_.store(m == 0 || (m >= 2 && m <= 4) ? m : 2);
    hud_.store(st.value(QStringLiteral("framegen/hud_protect"), true).toBool());
}

void FrameGen::registerQml(bool amd_gpu)
{
    FrameGen &s = instance();
    s.amd_ = amd_gpu;
    QQmlEngine::setObjectOwnership(&s, QQmlEngine::CppOwnership);
    qmlRegisterSingletonInstance("org.streetpea.chiaking", 1, 0, "FarplayFrameGen", &s);
}

void FrameGen::save()
{
    QSettings st = farplaySettings();
    st.setValue(QStringLiteral("framegen/mode"), mode());
    st.setValue(QStringLiteral("framegen/multiplier"), multiplier());
    st.setValue(QStringLiteral("framegen/hud_protect"), hudProtect());
    emit changed();
}

void FrameGen::setMode(int v)
{
    v = std::clamp(v, 0, 2);
    if (v != mode()) {
        mode_.store(v);
        suspended_.store(false);
        save();
    }
}

void FrameGen::setMultiplier(int v)
{
    if (!(v == 0 || (v >= 2 && v <= 4)))
        v = 2;
    if (v != multiplier()) {
        multiplier_.store(v);
        save();
    }
}

void FrameGen::setHudProtect(bool v)
{
    if (v != hudProtect()) {
        hud_.store(v);
        save();
    }
}

void FrameGen::toggleSuspended()
{
    suspended_.store(!suspended());
    emit changed();
}

void FrameGen::initGpu(pl_gpu gpu, pl_log log)
{
    gpu_ok_ = engine_.init(gpu, log);
    if (!gpu_ok_)
        qWarning("Farplay: moteur de frame gen indisponible (formats GPU manquants)");
}

void FrameGen::destroyGpu()
{
    engine_.destroy();
    gpu_ok_ = false;
}

double FrameGen::presentDelaySeconds(double source_interval_s) const
{
    if (!internalActive())
        return 0.0;
    // Une image source + 3 ms de marge pour la gigue d'arrivée : l'image
    // suivante B est alors (presque) toujours disponible pour l'interpolation.
    const double interval = source_interval_s > 0.005 ? source_interval_s : 1.0 / 30.0;
    return interval + 0.003;
}

bool FrameGen::render(pl_renderer renderer, const struct pl_frame_mix *mix,
                      const struct pl_frame *target, const struct pl_render_params *params)
{
    Stats &stats = Stats::instance();
    if (!internalActive() || !gpu_ok_ || !mix || mix->num_frames <= 0) {
        stats.setFrameGenState(mode() == 2 ? Stats::FgState::Afmf
                               : (mode() == 1 ? Stats::FgState::Suspended : Stats::FgState::Off));
        return false;
    }

    // A = dernière image dont l'instant est passé, B = la suivante.
    int ia = -1, ib = -1;
    for (int i = 0; i < mix->num_frames; i++) {
        if (mix->timestamps[i] <= 0.0f)
            ia = i;
        else if (ib < 0)
            ib = i;
    }
    if (ia < 0 || ib < 0 || ib != ia + 1) {
        stats.setFrameGenState(Stats::FgState::Waiting);
        return false;
    }
    const float ta = static_cast<float>(mix->timestamps[ia]);
    const float tb = static_cast<float>(mix->timestamps[ib]);
    float t = tb > ta ? -ta / (tb - ta) : 0.0f;
    t = std::clamp(t, 0.0f, 0.999f);
    const int mult = multiplier();
    if (mult >= 2)
        t = std::floor(t * mult) / mult;

    const int w = static_cast<int>(std::lround(std::fabs(target->crop.x1 - target->crop.x0)));
    const int h = static_cast<int>(std::lround(std::fabs(target->crop.y1 - target->crop.y0)));
    if (w < 16 || h < 16)
        return false;

    // Rendu (une fois) des images reçues A et B avec tout le pipeline
    // (upscaling FSR, lissage, HDR) dans les textures du moteur.
    const uint64_t sig[2] = { mix->signatures[ia], mix->signatures[ib] };
    const pl_frame *src[2] = { mix->frames[ia], mix->frames[ib] };
    pl_tex tex[2] = {};
    for (int k = 0; k < 2; k++) {
        bool need = false;
        tex[k] = engine_.acquireSlot(sig[k], w, h, &need);
        if (!tex[k])
            return false;
        if (need) {
            pl_frame dst = textureFrame(tex[k], target->color);
            if (!pl_render_image(renderer, src[k], &dst, params) || !engine_.finishSlot(sig[k]))
                return false;
        }
    }

    pl_tex show = tex[0];
    if (t > 1e-3f) {
        show = engine_.synthesize(sig[0], sig[1], t, hudProtect());
        if (!show)
            return false;
    }

    // Présentation : simple copie vers la cible de chiaki-ng (overlay QML,
    // zoom/étirement conservés), sans réappliquer les effets.
    pl_render_params p = *params;
    p.hooks = nullptr;
    p.num_hooks = 0;
    p.deband_params = nullptr;
    p.color_adjustment = nullptr;
    p.peak_detect_params = nullptr;
    p.deinterlace_params = nullptr;
    p.frame_mixer = nullptr;
    pl_frame img = textureFrame(show, target->color);
    if (!pl_render_image(renderer, &img, target, &p))
        return false;

    const FgEngine::Timings tm = engine_.timings();
    stats.setFrameGenState(Stats::FgState::Active);
    stats.onFrameGenOutput(t > 1e-3f, tm.pyramid_ms, tm.flow_ms, tm.synth_ms);
    return true;
}

} // namespace farplay
