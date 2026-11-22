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
    pacing_.store(st.value(QStringLiteral("framegen/pacing"), true).toBool());
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
    st.setValue(QStringLiteral("framegen/pacing"), pacing());
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

void FrameGen::setPacing(bool v)
{
    if (v != pacing()) {
        pacing_.store(v);
        save();
    }
}

void FrameGen::noteSourceArrival(int64_t now_us, double nominal_interval_s)
{
    // Une coupure (> 1 s) relance l'estimation.
    if (last_arrival_us_ > 0 && now_us - last_arrival_us_ > 1000000) {
        num_arrivals_ = 0;
        arrival_head_ = 0;
    }
    last_arrival_us_ = now_us;
    arrivals_[arrival_head_] = now_us;
    arrival_head_ = (arrival_head_ + 1) % kArrivals;
    if (num_arrivals_ < kArrivals)
        num_arrivals_++;
    if (++since_estimate_ >= 30) {
        since_estimate_ = 0;
        estimateJitter(nominal_interval_s);
    }
}

void FrameGen::estimateJitter(double nominal_interval_s)
{
    // Horloge des images : chaque arrivée reçoit l'indice d'image le plus
    // proche (une image perdue ne décale pas la suite), puis on ajuste une
    // droite t = t0 + i·T (T estimé : absorbe la dérive entre l'horloge de
    // la PS5 et celle du PC). Le retard d'une image = son écart au-dessus de
    // la droite, ramené à l'arrivée la plus précoce. Marge = 95e centile + 2 ms.
    const int n = num_arrivals_;
    if (n < 60 || nominal_interval_s <= 0.0)
        return;
    const double tn = nominal_interval_s * 1e6;
    const int first = (arrival_head_ - n + kArrivals) % kArrivals;
    const int64_t t0 = arrivals_[first];
    double idx[kArrivals], tt[kArrivals];
    double si = 0, st = 0, sii = 0, sit = 0;
    for (int k = 0; k < n; k++) {
        const double t = double(arrivals_[(first + k) % kArrivals] - t0);
        const double i = std::floor(t / tn + 0.5);
        idx[k] = i;
        tt[k] = t;
        si += i; st += t; sii += i * i; sit += i * t;
    }
    const double den = n * sii - si * si;
    if (den <= 0.0)
        return;
    const double slope = (n * sit - si * st) / den;
    const double icpt = (st - slope * si) / n;
    double res[kArrivals];
    double mn = 1e18;
    for (int k = 0; k < n; k++) {
        res[k] = tt[k] - (icpt + slope * idx[k]);
        mn = std::min(mn, res[k]);
    }
    for (int k = 0; k < n; k++)
        res[k] -= mn;
    const int p = std::min(n - 1, int(n * 0.95));
    std::nth_element(res, res + p, res + n);
    const double margin = std::clamp(res[p] / 1000.0 + 2.0, 3.0, 60.0);
    margin_ms_.store(margin, std::memory_order_relaxed);
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
    // Frame gen : une image source + la marge anti-gigue, pour que l'image
    // suivante B soit (presque) toujours arrivée. Lissage seul : la marge.
    // Marge : 3 ms fixes sans lissage ; sinon la marge mesurée, plafonnée
    // pour tenir la latence (la frame gen ajoute déjà une image source).
    const double cap_ms = internalActive() ? 12.0 : 25.0;
    const double margin = (pacing() ? std::min(jitterMarginMs(), cap_ms) : 3.0) / 1000.0;
    double delay = 0.0;
    if (internalActive()) {
        const double interval = source_interval_s > 0.005 ? source_interval_s : 1.0 / 30.0;
        delay = interval + margin;
    } else if (pacing()) {
        delay = margin;
    }
    audio_delay_ms_.store(delay * 1000.0, std::memory_order_relaxed);
    return delay;
}

bool FrameGen::render(pl_renderer renderer, const struct pl_frame_mix *mix,
                      const struct pl_frame *target, const struct pl_render_params *params)
{
    Stats &stats = Stats::instance();
    const bool interp = internalActive();
    if (!timedPresentation() || !gpu_ok_ || !mix || mix->num_frames <= 0) {
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
    if (ia < 0 || (interp && (ib < 0 || ib != ia + 1))) {
        stats.setFrameGenState(Stats::FgState::Waiting);
        return false;
    }
    // Lissage seul : l'image reçue courante est affichée à l'instant prévu par
    // l'horloge des images (pas d'interpolation ni de mélange).
    if (!interp)
        ib = ia;
    const float ta = static_cast<float>(mix->timestamps[ia]);
    const float tb = static_cast<float>(mix->timestamps[ib]);
    float t = (interp && tb > ta) ? -ta / (tb - ta) : 0.0f;
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
    const int n_src = interp ? 2 : 1;
    for (int k = 0; k < n_src; k++) {
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
    stats.setFrameGenState(interp ? Stats::FgState::Active : Stats::FgState::Pacing);
    stats.onFrameGenOutput(t > 1e-3f, tm.pyramid_ms, tm.flow_ms, tm.synth_ms);
    return true;
}

} // namespace farplay
