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
    engine_sel_.store(std::clamp(st.value(QStringLiteral("framegen/engine"), 1).toInt(), 0, 1));
    fsr_motion_.store(std::clamp(st.value(QStringLiteral("framegen/fsr_motion"), 0).toInt(), 0, 1));
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
    st.setValue(QStringLiteral("framegen/engine"), engine());
    st.setValue(QStringLiteral("framegen/fsr_motion"), fsrMotion());
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

void FrameGen::setEngine(int v)
{
    v = std::clamp(v, 0, 1);
    if (v != engine()) {
        engine_sel_.store(v);
        save();
    }
}

void FrameGen::setFsrMotion(int v)
{
    v = std::clamp(v, 0, 1);
    if (v != fsrMotion()) {
        fsr_motion_.store(v);
        save();
    }
}

QString FrameGen::fsrStatus() const
{
    QMutexLocker l(&fsr_status_mutex_);
    return fsr_status_;
}

// Thread de rendu → interface (signal mis en file vers le thread GUI).
void FrameGen::publishFsrStatus()
{
    const QString s = fsr_.status();
    {
        QMutexLocker l(&fsr_status_mutex_);
        if (s == fsr_status_)
            return;
        fsr_status_ = s;
    }
    QMetaObject::invokeMethod(this, [this]() { emit fsrStatusChanged(); }, Qt::QueuedConnection);
    Stats::instance().setFsrStatus(s);
}

void FrameGen::setPacing(bool v)
{
    if (v != pacing()) {
        pacing_.store(v);
        save();
    }
}

void FrameGen::noteSourceArrival(int64_t now_us, double pts_s, bool lost)
{
    // A (affichée) et B (suivante) ont un retard d'environ une image : l'image
    // corrompue sera B puis A ; on tient sur les 3 prochaines images affichées.
    if (lost)
        loss_hold_.store(3, std::memory_order_relaxed);
    const double offset = now_us / 1e6 - pts_s;
    // Saut du pts (nouvelle session, remise à zéro du flux) : on repart de zéro.
    if (num_arrivals_ > 0 && std::fabs(offset - last_offset_) > 1.0) {
        num_arrivals_ = 0;
        arrival_head_ = 0;
        base_valid_.store(false, std::memory_order_relaxed);
    }
    last_offset_ = offset;
    offsets_[arrival_head_] = offset;
    times_[arrival_head_] = now_us / 1e6;
    arrival_head_ = (arrival_head_ + 1) % kArrivals;
    if (num_arrivals_ < kArrivals)
        num_arrivals_++;
    // Estimation toutes les 5 images (ajustement sur 60 points : négligeable).
    if (++since_estimate_ >= 5) {
        since_estimate_ = 0;
        estimateJitter();
    }
}

void FrameGen::estimateJitter()
{
    // Décalage arrivée − pts des ~2 dernières secondes, ajusté par une droite :
    // la pente suit la dérive entre l'horloge du flux et le temps réel (horloges
    // PS5/PC, et surtout jeu sous 30 fps alors que les pts avancent de 1/30 s :
    // +0,3 % à 29,9 fps, soit 20 ms sur 8 s, ce qui faisait viser trop tard).
    // Base = droite + 5e centile des écarts ; marge = 95e − 5e centile + 2 ms.
    const int n = std::min(num_arrivals_, kFit);
    if (n < 10)
        return;
    double t[kFit], o[kFit];
    for (int k = 0; k < n; k++) {
        const int idx = (arrival_head_ - n + k + kArrivals) % kArrivals;
        t[k] = times_[idx];
        o[k] = offsets_[idx];
    }
    const double t_ref = t[n - 1];
    double st = 0, so = 0, stt = 0, sto = 0;
    for (int k = 0; k < n; k++) {
        const double x = t[k] - t_ref;
        st += x; so += o[k]; stt += x * x; sto += x * o[k];
    }
    const double den = n * stt - st * st;
    double slope = den > 1e-12 ? (n * sto - st * so) / den : 0.0;
    slope = std::clamp(slope, -0.01, 0.01);
    const double icpt = (so - slope * st) / n;
    double res[kFit];
    for (int k = 0; k < n; k++)
        res[k] = o[k] - (icpt + slope * (t[k] - t_ref));
    const int lo = int(n * 0.05);
    const int hi = std::min(n - 1, int(n * 0.95));
    std::nth_element(res, res + lo, res + n);
    const double r_lo = res[lo];
    std::nth_element(res, res + hi, res + n);
    const double late_ms = (res[hi] - r_lo) * 1000.0;
    margin_ms_.store(std::clamp(late_ms + 2.0, 3.0, 60.0), std::memory_order_relaxed);
    base_slope_.store(slope, std::memory_order_relaxed);
    base_t_.store(t_ref, std::memory_order_relaxed);
    base_offset_.store(icpt + r_lo, std::memory_order_relaxed);
    base_valid_.store(true, std::memory_order_relaxed);
}

bool FrameGen::displayPts(int64_t now_us, double queue_origin_s, double vsync_s, double delay_s, double *out_pts) const
{
    if (!timedPresentation() || !base_valid_.load(std::memory_order_relaxed))
        return false;
    // Une image de pts P arrive (au mieux) à P + base(t) : on l'affiche à P + base(t) + retard.
    const double now = now_us / 1e6;
    const double dt = std::clamp(now - base_t_.load(std::memory_order_relaxed), 0.0, 0.5);
    const double base = base_offset_.load(std::memory_order_relaxed) + base_slope_.load(std::memory_order_relaxed) * dt;
    double pts = now - base - queue_origin_s + vsync_s - delay_s;
    // pl_queue exige des pts croissants : une nouvelle estimation ne fait pas reculer la cible.
    if (queue_origin_s == last_origin_ && pts < last_out_pts_)
        pts = last_out_pts_;
    last_out_pts_ = pts;
    last_origin_ = queue_origin_s;
    *out_pts = pts;
    return true;
}

void FrameGen::toggleSuspended()
{
    suspended_.store(!suspended());
    emit changed();
}

void FrameGen::initGpu(pl_gpu gpu, pl_log log, pl_vulkan vk)
{
    gpu_ok_ = engine_.init(gpu, log);
    if (!gpu_ok_)
        qWarning("Farplay: moteur de frame gen indisponible (formats GPU manquants)");
    fsr_.init(vk, log);
    fsr_a_ = fsr_b_ = 0;
    fsr_out_ = nullptr;
    fsr_out_valid_ = false;
    publishFsrStatus();
}

void FrameGen::destroyGpu()
{
    last_show_ = nullptr;
    fsr_out_ = nullptr;
    fsr_out_valid_ = false;
    if (fsr_in_ && engine_.gpu())
        pl_tex_destroy(engine_.gpu(), &fsr_in_);
    fsr_.destroy();
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
        stats.noteFrameGenWait(ia < 0 ? 0 : (ib < 0 ? 1 : 2), mix->num_frames);
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
    if (interp && mix->signatures[ia] != hold_sig_) {
        hold_sig_ = mix->signatures[ia];
        int pending = loss_hold_.load(std::memory_order_relaxed);
        holding_ = pending > 0;
        if (holding_)
            loss_hold_.compare_exchange_strong(pending, pending - 1, std::memory_order_relaxed);
    }
    if (holding_)
        t = 0.0f; // perte récente : image reçue seule, sans interpolation
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

    // Moteur AMD FSR : une image du milieu par paire (x2), calculée dès que la
    // paire (A, B) est connue ; repli sur le moteur Farplay en cas d'échec.
    const bool use_fsr = interp && engine() == 1 && fsr_.usable();
    if (use_fsr) {
        t = t >= 0.5f ? 0.5f : 0.0f;
        if (sig[0] != fsr_a_ || sig[1] != fsr_b_) {
            // FSR interpole entre l'image courante précédente (son historique) et B :
            // si la précédente n'était pas A, l'historique est rompu → reset.
            const bool reset = sig[0] != fsr_b_;
            pl_tex mv = nullptr;
            float sx = 1.0f, sy = 1.0f;
            if (fsrMotion() == 1) {
                // Flux Farplay : A→B en coordonnées normalisées ; FSR attend, pour
                // chaque pixel de B, le déplacement vers A en pixels (échelle négative).
                mv = engine_.flowFor(sig[0], sig[1]);
                if (mv) {
                    sx = -static_cast<float>(mv->params.w);
                    sy = -static_cast<float>(mv->params.h);
                }
            }
            const bool pq = target->color.transfer == PL_COLOR_TRC_PQ;
            const float peak = target->color.hdr.max_luma > 0.0f ? target->color.hdr.max_luma : 1000.0f;
            const float dt_ms = 1000.0f / 30.0f; // flux PS5 à 30 images/s
            // FSR attend une image d'écran encodée : 8 bits sRGB (SDR) ou 10 bits PQ
            // (HDR). Nos slots sont en flottant 16 bits mais encodés comme la sortie,
            // ce que FSR prendrait pour du linéaire (scRGB) → images générées d'une
            // autre luminosité que les vraies (scintillement). On lui passe une copie.
            pl_fmt in_fmt = pl_find_named_fmt(engine_.gpu(), pq ? "rgb10a2" : "rgba8");
            pl_tex fsr_src = nullptr;
            if (in_fmt) {
                struct pl_tex_params ip = {};
                ip.w = tex[1]->params.w;
                ip.h = tex[1]->params.h;
                ip.format = in_fmt;
                ip.sampleable = true;
                ip.renderable = true;
                if (pl_tex_recreate(engine_.gpu(), &fsr_in_, &ip) && engine_.copyInto(tex[1], fsr_in_))
                    fsr_src = fsr_in_;
            }
            fsr_out_ = fsr_src ? fsr_.generate(fsr_src, reset, mv, sx, sy, pq, peak, dt_ms) : nullptr;
            fsr_out_valid_ = fsr_out_ && !reset;
            fsr_a_ = sig[0];
            fsr_b_ = sig[1];
            publishFsrStatus();
        }
    }

    // Même image qu'à la vsync précédente (ex. x2 à 120 Hz) : pas de nouvelle synthèse.
    const bool new_image = !(sig[0] == last_sig_a_ && sig[1] == last_sig_b_ && t == last_t_ && last_show_);
    pl_tex show = tex[0];
    if (t > 1e-3f) {
        if (use_fsr)
            show = fsr_out_valid_ ? fsr_out_ : tex[0];
        else
            show = new_image ? engine_.synthesize(sig[0], sig[1], t, hudProtect()) : last_show_;
        if (!show)
            return false;
    }
    last_sig_a_ = sig[0];
    last_sig_b_ = sig[1];
    last_t_ = t;
    last_show_ = show;

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
    stats.onFrameGenOutput(t > 1e-3f, new_image, tm.pyramid_ms, tm.flow_ms, tm.synth_ms);
    return true;
}

} // namespace farplay
