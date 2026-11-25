// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#include "farplay/farplaystats.h"

#include "qmlbackend.h"
#include "qmlmainwindow.h"
#include "streamsession.h"
#include "chiaki/time.h"
#include "farplay/farplayimage.h"
#include "farplay/farplayframegen.h"

#include <libplacebo/renderer.h>

extern "C" {
#include <libavutil/frame.h>
#include <libavutil/hwcontext.h>
#include <libavutil/pixdesc.h>
#include <libavutil/pixfmt.h>
}

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFontDatabase>
#include <QMutexLocker>
#include <QQmlEngine>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>

#include <algorithm>
#include <array>
#include <cstring>

#ifndef FARPLAY_GIT_HASH
#define FARPLAY_GIT_HASH "dev"
#endif

namespace farplay {

namespace {

constexpr int kVkPresentImmediate = 0;
constexpr int kVkPresentMailbox = 1;
constexpr int kVkPresentFifo = 2;
constexpr int kVkPresentFifoRelaxed = 3;

struct RingStats { double avg = 0.0, p99 = 0.0, max = 0.0; int n = 0; };

template<int N>
RingStats computeStats(const SampleRing<N> &r)
{
    RingStats s;
    s.n = r.count;
    if (r.count == 0)
        return s;
    std::array<float, N> tmp;
    double sum = 0.0;
    for (int i = 0; i < r.count; i++) {
        tmp[i] = r.v[i];
        sum += r.v[i];
    }
    s.avg = sum / r.count;
    const int idx = std::min(r.count - 1, (int)(r.count * 0.99));
    std::nth_element(tmp.begin(), tmp.begin() + idx, tmp.begin() + r.count);
    s.p99 = tmp[idx];
    s.max = *std::max_element(tmp.begin(), tmp.begin() + r.count);
    return s;
}

QString presentModeName(int mode)
{
    switch (mode) {
    case kVkPresentImmediate: return QStringLiteral("Immediate");
    case kVkPresentMailbox: return QStringLiteral("Mailbox");
    case kVkPresentFifo: return QStringLiteral("FIFO (VSync)");
    case kVkPresentFifoRelaxed: return QStringLiteral("FIFO relaxed");
    default: return QStringLiteral("—");
    }
}

QString decoderName(int pix_fmt, bool *zero_copy)
{
    *zero_copy = false;
    switch (pix_fmt) {
    case AV_PIX_FMT_VULKAN: *zero_copy = true; return QStringLiteral("Vulkan Video");
    case AV_PIX_FMT_D3D11: return QStringLiteral("D3D11VA");
    case AV_PIX_FMT_DXVA2_VLD: return QStringLiteral("DXVA2");
    case AV_PIX_FMT_VAAPI: return QStringLiteral("VA-API");
    case AV_PIX_FMT_CUDA: return QStringLiteral("CUDA");
    case AV_PIX_FMT_VIDEOTOOLBOX: return QStringLiteral("VideoToolbox");
    case -1: return QStringLiteral("—");
    default: return QStringLiteral("Logiciel (CPU)");
    }
}

QString hdrName(int trc)
{
    switch (trc) {
    case AVCOL_TRC_SMPTE2084: return QStringLiteral("HDR10 (PQ)");
    case AVCOL_TRC_ARIB_STD_B67: return QStringLiteral("HLG");
    default: return QStringLiteral("SDR");
    }
}

QString primName(int prim)
{
    switch (prim) {
    case AVCOL_PRI_BT2020: return QStringLiteral("BT.2020");
    case AVCOL_PRI_BT709: return QStringLiteral("BT.709");
    case AVCOL_PRI_UNSPECIFIED: return QStringLiteral("non spécifié");
    default: {
        const char *name = av_color_primaries_name((AVColorPrimaries)prim);
        return QString::fromUtf8(name ? name : "?");
    }
    }
}

} // namespace

Stats &Stats::instance()
{
    static Stats *s = new Stats();
    return *s;
}

Stats::Stats(QObject *parent)
    : QObject(parent)
    , timer(this)
{
    // Le minuteur doit vivre sur le thread GUI, quel que soit le premier appelant.
    if (QCoreApplication::instance() && thread() != QCoreApplication::instance()->thread())
        moveToThread(QCoreApplication::instance()->thread());
    QSettings st(QStringLiteral("Farplay"), QStringLiteral("Farplay"));
    overlay_level = std::clamp(st.value(QStringLiteral("overlay/level"), 1).toInt(), 0, 2);
    mailbox_enabled.store(st.value(QStringLiteral("present/mailbox"), false).toBool());
    timer.setInterval(500); // 2 Hz : chaque mise à jour QML déclenche un rendu de la scène Qt Quick
    timer.setTimerType(Qt::CoarseTimer);
    connect(&timer, &QTimer::timeout, this, &Stats::tick);
}

void Stats::registerQml(QmlBackend *backend, QmlMainWindow *window)
{
    Stats &s = instance();
    const int font_id = QFontDatabase::addApplicationFont(QStringLiteral(":/farplay/fonts/JetBrainsMono-Regular.ttf"));
    const QStringList families = QFontDatabase::applicationFontFamilies(font_id);
    s.mono_font = families.isEmpty() ? QStringLiteral("monospace") : families.first();
    const QStringList ui_families = QFontDatabase::applicationFontFamilies(
        QFontDatabase::addApplicationFont(QStringLiteral(":/farplay/fonts/Sora-Variable.ttf")));
    s.ui_font = ui_families.isEmpty() ? QString() : ui_families.first();

    QQmlEngine::setObjectOwnership(&s, QQmlEngine::CppOwnership);
    qmlRegisterSingletonInstance("org.streetpea.chiaking", 1, 0, "Farplay", &s);
    Image::registerQml();
    FrameGen::registerQml(window->amdCard());

    QPointer<QmlBackend> b(backend);
    s.net = [b]() {
        NetSample n;
        StreamSession *session = b ? b->qmlSession() : nullptr;
        if (!session)
            return n;
        n.connected = session->GetConnected();
        n.bitrate_mbps = session->GetMeasuredBitrate();
        n.packet_loss = session->GetAveragePacketLoss();
        n.frames_lost = session->GetFramesLost();
        n.rtt_ms = session->GetRttUs() / 1000.0;
        n.requested_bitrate_mbps = session->GetFarplayRequestedBitrate() / 1000.0;
        n.target_bitrate_mbps = session->GetFarplayTargetBitrate() / 1e6; // bit/s (97087000 pour 100 Mbps demandés)
        return n;
    };
    connect(backend, &QmlBackend::sessionChanged, &s, [&s](StreamSession *session) {
        s.setSessionActive(session != nullptr);
    });
    // Le mode de présentation est lu à la (re)création de la swapchain.
    connect(&s, &Stats::mailboxChanged, window, &QmlMainWindow::updateVSync);
}

bool Stats::firstLaunch() const
{
    return !QSettings(QStringLiteral("Farplay"), QStringLiteral("Farplay")).value(QStringLiteral("ui/wizard_done"), false).toBool();
}

void Stats::setFirstLaunchDone()
{
    QSettings(QStringLiteral("Farplay"), QStringLiteral("Farplay")).setValue(QStringLiteral("ui/wizard_done"), true);
    emit firstLaunchChanged();
}

QString Stats::buildId() const
{
    return QStringLiteral(FARPLAY_GIT_HASH);
}

void Stats::onSourceFrame(const AVFrame *frame)
{
    if (!frame)
        return;
    const int64_t now = (int64_t)chiaki_time_now_monotonic_us();
    int sw_fmt = frame->format;
    if (frame->hw_frames_ctx && frame->hw_frames_ctx->data)
        sw_fmt = ((const AVHWFramesContext *)frame->hw_frames_ctx->data)->sw_format;
    last_src_seen_us.store(now, std::memory_order_relaxed);
    QMutexLocker lock(&mutex);
    if (last_src_us > 0 && now > last_src_us)
        src_interval_ms.push((now - last_src_us) / 1000.0f);
    last_src_us = now;
    src_count++;
    src_width = frame->width;
    src_height = frame->height;
    src_pix_fmt = frame->format;
    src_sw_fmt = sw_fmt;
    src_trc = frame->color_trc;
    src_prim = frame->color_primaries;
    src_space = frame->colorspace;
    src_range = frame->color_range;
}

void Stats::onDisplayFrame(int64_t now_us)
{
    QMutexLocker lock(&mutex);
    if (last_disp_us > 0 && now_us > last_disp_us)
        disp_interval_ms.push((now_us - last_disp_us) / 1000.0f);
    last_disp_us = now_us;
    disp_count++;
    if (acc_frame_ns)
        gpu_frame_ms.push(acc_frame_ns / 1e6f);
    if (acc_blend_ns)
        gpu_blend_ms.push(acc_blend_ns / 1e6f);
    if (acc_upscale_ns)
        gpu_upscale_ms.push(acc_upscale_ns / 1e6f);
    if (acc_denoise_ns)
        gpu_denoise_ms.push(acc_denoise_ns / 1e6f);
    acc_frame_ns = 0;
    acc_blend_ns = 0;
    acc_upscale_ns = 0;
    acc_denoise_ns = 0;
}

void Stats::plInfoCallback(void *priv, const struct pl_render_info *info)
{
    // libplacebo rapporte ici le temps GPU de chaque passe de shader, mesuré
    // par ses propres requêtes de timestamp Vulkan (lues de façon asynchrone :
    // `last` est la dernière mesure disponible, sans bloquer le GPU).
    Stats *s = static_cast<Stats *>(priv);
    if (!s || !info || !info->pass)
        return;
    const uint64_t ns = info->pass->last;
    const char *desc = info->pass->shader ? info->pass->shader->description : nullptr;
    // Passes d'upscaling : shaders Farplay (FSR1), FSR de chiaki-ng et FSRCNNX.
    const bool upscale = desc && (std::strstr(desc, "Farplay FSR") || std::strstr(desc, "FidelityFX")
                                  || std::strstr(desc, "feature map") || std::strstr(desc, "mapping ")
                                  || std::strstr(desc, "sub-band") || std::strstr(desc, "aggregation"));
    QMutexLocker lock(&s->mutex);
    if (info->stage == PL_RENDER_STAGE_FRAME)
        s->acc_frame_ns += ns;
    else
        s->acc_blend_ns += ns;
    if (upscale)
        s->acc_upscale_ns += ns;
    if (desc && (std::strstr(desc, "Farplay reduction artefacts") || std::strstr(desc, "Farplay chroma")))
        s->acc_denoise_ns += ns;
}

void Stats::setUpscaler(Upscaler used, float factor)
{
    QMutexLocker lock(&mutex);
    upscaler = used;
    upscale_factor = factor;
}

void Stats::setOutputColor(int pl_transfer, int pl_primaries, int width, int height)
{
    QMutexLocker lock(&mutex);
    out_trc = pl_transfer;
    out_prim = pl_primaries;
    out_width = width;
    out_height = height;
}

void Stats::setSourcePeak(float nits)
{
    QMutexLocker lock(&mutex);
    src_peak_nits = nits;
}

void Stats::setFrameGenState(FgState state)
{
    QMutexLocker lock(&mutex);
    if (state == FgState::Waiting || state == FgState::Active || state == FgState::Pacing) {
        fg_vsync_total++;
        if (state == FgState::Waiting)
            fg_vsync_wait++;
        else
            fg_state = state; // au moins une vsync rendue sur le tick : état actif
        return;
    }
    fg_state = state;
}

void Stats::noteFrameGenWait(int reason, int mix_frames)
{
    QMutexLocker lock(&mutex);
    if (reason >= 0 && reason < 3)
        fg_wait_reason[reason]++;
    fg_mix_frames_sum += static_cast<uint32_t>(mix_frames > 0 ? mix_frames : 0);
}

void Stats::notePresent(int kind)
{
    QMutexLocker lock(&mutex);
    if (kind >= 0 && kind < 10)
        present_kind[kind]++;
}

void Stats::noteQueueDiag(int depth, double lead_ms, bool kept, bool clamped)
{
    QMutexLocker lock(&mutex);
    qdiag_n++;
    qdiag_depth += depth;
    qdiag_lead += lead_ms;
    qdiag_lead_min = std::min(qdiag_lead_min, lead_ms);
    if (kept)
        qdiag_kept++;
    if (clamped)
        qdiag_clamped++;
}

void Stats::onFrameGenOutput(bool generated, bool new_image, double pyramid_ms, double flow_ms, double synth_ms)
{
    QMutexLocker lock(&mutex);
    if (new_image) {
        fg_distinct++;
        if (generated)
            fg_generated++;
    }
    fg_pyr_ms = pyramid_ms;
    fg_flow_ms = flow_ms;
    fg_synth_ms = synth_ms;
}

void Stats::setFrameGenDelay(double ms)
{
    QMutexLocker lock(&mutex);
    fg_delay_ms = ms;
}

int64_t Stats::lastSourceAgeUs() const
{
    const int64_t last = last_src_seen_us.load(std::memory_order_relaxed);
    if (last <= 0)
        return -1;
    return (int64_t)chiaki_time_now_monotonic_us() - last;
}

void Stats::setPresentMode(int vk_present_mode, bool supported)
{
    QMutexLocker lock(&mutex);
    present_mode = vk_present_mode;
    present_supported = supported;
}

void Stats::setSessionActive(bool active)
{
    session_active.store(active);
    if (active) {
        {
            QMutexLocker lock(&mutex);
            src_interval_ms.clear();
            disp_interval_ms.clear();
            gpu_frame_ms.clear();
            gpu_blend_ms.clear();
            gpu_upscale_ms.clear();
            gpu_denoise_ms.clear();
            last_src_us = last_disp_us = 0;
            src_count = disp_count = 0;
            src_pix_fmt = -1;
        }
        prev_src_count = prev_disp_count = 0;
        prev_tick_us = 0;
        session_start_us = (int64_t)chiaki_time_now_monotonic_us();
        timer.start();
    } else {
        // Aucune activité au repos (exigence : < 1 % CPU hors session).
        timer.stop();
        if (csv_file.isOpen())
            csv_file.close();
    }
}

void Stats::setOverlayLevel(int level)
{
    level = std::clamp(level, 0, 2);
    if (level == overlay_level)
        return;
    overlay_level = level;
    QSettings(QStringLiteral("Farplay"), QStringLiteral("Farplay")).setValue(QStringLiteral("overlay/level"), level);
    emit overlayLevelChanged();
}

void Stats::setMailbox(bool enabled)
{
    if (enabled == mailbox())
        return;
    mailbox_enabled.store(enabled);
    QSettings(QStringLiteral("Farplay"), QStringLiteral("Farplay")).setValue(QStringLiteral("present/mailbox"), enabled);
    emit mailboxChanged();
}

void Stats::setCsvLogging(bool enabled)
{
    if (enabled == csv_enabled)
        return;
    csv_enabled = enabled;
    if (!enabled && csv_file.isOpen())
        csv_file.close();
    emit csvLoggingChanged();
}

void Stats::tick()
{
    const int64_t now = (int64_t)chiaki_time_now_monotonic_us();
    RingStats src, disp, gframe, gblend, gup, gden;
    double fg_wait_pct = 0.0;
    double fg_calls_per_s = 0.0;
    QString fg_wait_detail;
    QString fg_queue_detail;
    Upscaler up;
    float up_factor, peak;
    int otrc, oprim, ow, oh;
    FgState fgs;
    uint64_t fgg, fgd;
    double fpyr, fflow, fsynth, fdelay;
    uint64_t sc, dc;
    int w, h, pf, swf, trc, prim, pmode;
    bool psup;
    {
        QMutexLocker lock(&mutex);
        src = computeStats(src_interval_ms);
        disp = computeStats(disp_interval_ms);
        gframe = computeStats(gpu_frame_ms);
        gblend = computeStats(gpu_blend_ms);
        gup = computeStats(gpu_upscale_ms);
        gden = computeStats(gpu_denoise_ms);
        up = upscaler; up_factor = upscale_factor; peak = src_peak_nits;
        otrc = out_trc; oprim = out_prim; ow = out_width; oh = out_height;
        fgs = fg_state; fgg = fg_generated; fgd = fg_distinct;
        fg_wait_pct = fg_vsync_total ? 100.0 * fg_vsync_wait / fg_vsync_total : 0.0;
        fg_calls_per_s = fg_vsync_total / 0.5;
        if (fg_vsync_wait) {
            fg_wait_detail = QStringLiteral("sans A %1 % · sans B %2 % · trou %3 % · %4 img/mix")
                .arg(100.0 * fg_wait_reason[0] / fg_vsync_wait, 0, 'f', 0)
                .arg(100.0 * fg_wait_reason[1] / fg_vsync_wait, 0, 'f', 0)
                .arg(100.0 * fg_wait_reason[2] / fg_vsync_wait, 0, 'f', 0)
                .arg(double(fg_mix_frames_sum) / fg_vsync_wait, 0, 'f', 1);
        }
        fg_wait_reason[0] = fg_wait_reason[1] = fg_wait_reason[2] = 0;
        {
            const uint32_t *k = present_kind;
            fg_queue_detail = QStringLiteral("file %1 img · avance moy %2 / min %3 ms · bridées %15 % · ré-enfilées %4 · arrivées : directes %5, promues %6, ajoutées %7, appliquées au rendu %8 · retenues : verrou %9, après promo %10, file %11, reset %12, recov %13 · resets %14")
                .arg(qdiag_n ? qdiag_depth / qdiag_n : 0.0, 0, 'f', 1)
                .arg(qdiag_n ? qdiag_lead / qdiag_n : 0.0, 0, 'f', 0)
                .arg(qdiag_n ? qdiag_lead_min : 0.0, 0, 'f', 0)
                .arg(qdiag_kept)
                .arg(k[0]).arg(k[1]).arg(k[2]).arg(k[9])
                .arg(k[3]).arg(k[4]).arg(k[7]).arg(k[6]).arg(k[5]).arg(k[8])
                .arg(qdiag_n ? 100.0 * qdiag_clamped / qdiag_n : 0.0, 0, 'f', 0);
            for (uint32_t &v : present_kind) v = 0;
            qdiag_n = qdiag_kept = qdiag_clamped = 0; qdiag_depth = qdiag_lead = 0; qdiag_lead_min = 1e9;
        }
        fg_mix_frames_sum = 0;
        // Majorité de vsyncs sans image suivante sur le tick : état « attente »
        if (fg_vsync_total && fg_vsync_wait * 2 > fg_vsync_total)
            fgs = FgState::Waiting;
        if (fg_vsync_total)
            fg_state = FgState::Waiting; // le prochain tick repassera « actif » s'il synthétise
        fg_vsync_wait = fg_vsync_total = 0;
        fpyr = fg_pyr_ms; fflow = fg_flow_ms; fsynth = fg_synth_ms; fdelay = fg_delay_ms;
        sc = src_count; dc = disp_count;
        w = src_width; h = src_height;
        pf = src_pix_fmt; swf = src_sw_fmt;
        trc = src_trc; prim = src_prim;
        pmode = present_mode; psup = present_supported;
    }

    double fps_in = 0.0, fps_out = 0.0;
    if (prev_tick_us > 0 && now > prev_tick_us) {
        const double dt = (now - prev_tick_us) / 1e6;
        fps_in = (sc - prev_src_count) / dt;
        fps_out = (dc - prev_disp_count) / dt;
    }
    prev_tick_us = now;
    prev_src_count = sc;
    prev_disp_count = dc;
    // Lissage léger de l'affichage.
    const double prev_in = snap.value(QStringLiteral("fpsIn")).toDouble();
    const double prev_out = snap.value(QStringLiteral("fpsOut")).toDouble();
    if (prev_in > 0.0)
        fps_in = 0.6 * fps_in + 0.4 * prev_in;
    if (prev_out > 0.0)
        fps_out = 0.6 * fps_out + 0.4 * prev_out;

    bool zero_copy = false;
    const QString decoder = decoderName(pf, &zero_copy);
    const AVPixFmtDescriptor *desc = swf >= 0 ? av_pix_fmt_desc_get((AVPixelFormat)swf) : nullptr;
    const int bit_depth = desc ? desc->comp[0].depth : 0;

    // Coût GPU par image source = traitement de l'image + compositions
    // affichées pour cette image.
    const double disp_per_src = fps_in > 1.0 ? std::max(1.0, fps_out / fps_in) : 1.0;
    const double gpu_total = gframe.avg + gblend.avg * disp_per_src;

    const NetSample n = net ? net() : NetSample{};

    QVariantMap s;
    s[QStringLiteral("active")] = session_active.load();
    s[QStringLiteral("fpsIn")] = fps_in;
    s[QStringLiteral("fpsOut")] = fps_out;
    s[QStringLiteral("srcIntervalAvg")] = src.avg;
    s[QStringLiteral("srcIntervalP99")] = src.p99;
    s[QStringLiteral("dispIntervalAvg")] = disp.avg;
    s[QStringLiteral("dispIntervalP99")] = disp.p99;
    s[QStringLiteral("dispIntervalMax")] = disp.max;
    s[QStringLiteral("gpuFrameAvg")] = gframe.avg;
    s[QStringLiteral("gpuFrameP99")] = gframe.p99;
    s[QStringLiteral("gpuBlendAvg")] = gblend.avg;
    s[QStringLiteral("gpuBlendP99")] = gblend.p99;
    s[QStringLiteral("gpuTotal")] = gpu_total;
    s[QStringLiteral("gpuTimingAvailable")] = gframe.n > 0 || gblend.n > 0;
    s[QStringLiteral("budgetTotal")] = kBudgetTotalMs;
    s[QStringLiteral("overBudget")] = gpu_total > kBudgetTotalMs;
    s[QStringLiteral("decoder")] = decoder;
    s[QStringLiteral("zeroCopy")] = zero_copy;
    s[QStringLiteral("bitDepth")] = bit_depth;
    s[QStringLiteral("resolution")] = w > 0 ? QStringLiteral("%1×%2").arg(w).arg(h) : QStringLiteral("—");
    s[QStringLiteral("hdr")] = pf >= 0 ? hdrName(trc) : QStringLiteral("—");
    s[QStringLiteral("hdrReceived")] = trc == AVCOL_TRC_SMPTE2084 || trc == AVCOL_TRC_ARIB_STD_B67;
    s[QStringLiteral("primaries")] = pf >= 0 ? primName(prim) : QStringLiteral("—");
    s[QStringLiteral("presentMode")] = presentModeName(pmode);
    s[QStringLiteral("presentFallback")] = !psup;
    s[QStringLiteral("bitrate")] = n.bitrate_mbps;
    s[QStringLiteral("packetLoss")] = n.packet_loss * 100.0;
    s[QStringLiteral("framesLost")] = n.frames_lost;
    s[QStringLiteral("rttMs")] = n.rtt_ms;
    s[QStringLiteral("targetBitrate")] = n.target_bitrate_mbps;
    s[QStringLiteral("requestedBitrate")] = n.requested_bitrate_mbps;

    // --- Phase 2 : upscaling ---
    const bool has_up_shader = up == Upscaler::Fsr1 || up == Upscaler::Fsrcnnx || up == Upscaler::Chiaki;
    QString up_name;
    switch (up) {
    case Upscaler::None: up_name = QStringLiteral("aucun (×1)"); break;
    case Upscaler::Builtin: up_name = QStringLiteral("libplacebo"); break;
    case Upscaler::Chiaki: up_name = QStringLiteral("réglage chiaki-ng"); break;
    case Upscaler::Fsr1: up_name = QStringLiteral("FSR 1"); break;
    case Upscaler::Fsrcnnx: up_name = QStringLiteral("FSRCNNX"); break;
    case Upscaler::Fallback: up_name = QStringLiteral("libplacebo (shader indisponible)"); break;
    }
    s[QStringLiteral("upscaler")] = up_name;
    s[QStringLiteral("upscaleFactor")] = up_factor;
    s[QStringLiteral("outResolution")] = ow > 0 ? QStringLiteral("%1×%2").arg(ow).arg(oh) : QStringLiteral("—");
    // Budgets du cahier des charges : FSR 1 ≤ 1 ms, réseau léger ≤ 4 ms.
    const double up_budget = up == Upscaler::Fsrcnnx ? kBudgetUpscaleNetMs : kBudgetUpscaleMs;
    s[QStringLiteral("upscaleBudget")] = up_budget;
    s[QStringLiteral("gpuUpscaleAvg")] = has_up_shader ? gup.avg : 0.0;
    s[QStringLiteral("gpuUpscaleP99")] = has_up_shader ? gup.p99 : 0.0;
    const bool den_on = denoise_active.load(std::memory_order_relaxed);
    s[QStringLiteral("denoiseOn")] = den_on;
    s[QStringLiteral("gpuDenoiseAvg")] = den_on ? gden.avg : 0.0;
    s[QStringLiteral("gpuDenoiseP99")] = den_on ? gden.p99 : 0.0;
    s[QStringLiteral("upscaleOverBudget")] = has_up_shader && gup.avg > up_budget;

    // --- Phase 2 : diagnostic HDR (source → sortie) ---
    const bool src_known = pf >= 0;
    const bool src_hdr = trc == AVCOL_TRC_SMPTE2084 || trc == AVCOL_TRC_ARIB_STD_B67;
    const bool out_hdr = otrc == PL_COLOR_TRC_PQ || otrc == PL_COLOR_TRC_HLG;
    s[QStringLiteral("outHdr")] = out_hdr;
    s[QStringLiteral("output")] = otrc ? QStringLiteral("%1 · %2").arg(out_hdr ? QStringLiteral("HDR10 (PQ)") : QStringLiteral("SDR"),
                                                            oprim == PL_COLOR_PRIM_BT_2020 ? QStringLiteral("BT.2020") : QStringLiteral("BT.709"))
                                      : QStringLiteral("—");
    s[QStringLiteral("srcPeakNits")] = peak;
    QString diag;
    int diag_level = 0; // 0 = ok, 1 = info, 2 = problème
    if (!src_known || !otrc) {
        diag = QStringLiteral("En attente du flux");
    } else if (src_hdr && out_hdr) {
        diag = QStringLiteral("HDR de bout en bout");
    } else if (src_hdr && !out_hdr) {
        diag = QStringLiteral("Écran en SDR : activez « Utiliser le HDR » dans Windows, en plein écran");
        diag_level = 2;
    } else if (!src_hdr && out_hdr) {
        diag = QStringLiteral("La PS5 envoie du SDR, converti en HDR (%1 nits)").arg(Image::instance().sdrWhiteNits());
        diag_level = 1;
    } else {
        diag = QStringLiteral("La PS5 envoie du SDR : vérifiez son réglage HDR et la chaîne HDMI (ampli)");
        diag_level = 2;
    }
    s[QStringLiteral("hdrDiag")] = diag;
    s[QStringLiteral("hdrDiagLevel")] = diag_level;
    // --- Phase 3 : génération d'images ---
    double fps_gen = 0.0;
    if (prev_tick_us > 0 && fgg >= prev_fg_generated)
        fps_gen = (fgg - prev_fg_generated) / 0.5; // tick de 500 ms
    prev_fg_generated = fgg;
    // Images distinctes affichées (cadence réelle du contenu, hors répétitions de vsync)
    double fps_distinct = 0.0;
    if (prev_tick_us > 0 && fgd >= prev_fg_distinct)
        fps_distinct = (fgd - prev_fg_distinct) / 0.5;
    prev_fg_distinct = fgd;
    QString fg_name;
    switch (fgs) {
    case FgState::Active:
        fg_name = fg_wait_pct >= 1.0 ? QStringLiteral("interne · attente %1 %").arg(fg_wait_pct, 0, 'f', 0)
                                     : QStringLiteral("interne");
        break;
    case FgState::Off: fg_name = QStringLiteral("coupée"); break;
    case FgState::Waiting: fg_name = QStringLiteral("interne · attente de l'image suivante"); break;
    case FgState::Suspended: fg_name = QStringLiteral("interne · suspendue (F4)"); break;
    case FgState::Afmf: fg_name = QStringLiteral("AFMF (pilote AMD)"); break;
    case FgState::Unavailable: fg_name = QStringLiteral("indisponible (mode direct)"); break;
    case FgState::Pacing: fg_name = QStringLiteral("coupée · lissage du pacing"); break;
    }
    // Coût GPU par image source : pyramide + flux une fois, synthèse par image générée.
    const double gen_per_src = fps_in > 1.0 ? fps_gen / fps_in : 0.0;
    const double fg_cost = fgs == FgState::Active ? fpyr + fflow + fsynth * gen_per_src : 0.0;
    s[QStringLiteral("fgState")] = fg_name;
    s[QStringLiteral("fgActive")] = fgs == FgState::Active;
    s[QStringLiteral("fpsGen")] = fps_gen;
    // Quand la frame gen n'a pas rendu, chiaki-ng affiche les images reçues :
    // la cadence distincte vaut au moins celle du flux (jamais la fréquence écran).
    s[QStringLiteral("fpsDistinct")] = std::max(fps_distinct, fps_in);
    s[QStringLiteral("fgWaitPct")] = fg_wait_pct;
    s[QStringLiteral("fgWaitDetail")] = fg_wait_detail;
    s[QStringLiteral("fgQueueDetail")] = fg_queue_detail;
    s[QStringLiteral("fgCallsPerSec")] = fg_calls_per_s; // rendus de la frame gen par seconde (devrait suivre l'écran)
    s[QStringLiteral("fgFlowMs")] = fflow;
    s[QStringLiteral("fgSynthMs")] = fsynth;
    s[QStringLiteral("fgPyrMs")] = fpyr;
    s[QStringLiteral("fgCostMs")] = fg_cost;
    s[QStringLiteral("fgOverBudget")] = fg_cost > kBudgetFrameGenMs;
    s[QStringLiteral("fgDelayMs")] = fdelay;
    // Lissage du pacing et synchronisation du son
    s[QStringLiteral("pacingOn")] = FrameGen::instance().timedPresentation();
    s[QStringLiteral("pacingMarginMs")] = FrameGen::instance().jitterMarginMs();
    s[QStringLiteral("audioDelayMs")] = FrameGen::instance().audioDelayMs();
    // 1 % low des images affichées (cadence correspondant au 99e centile de l'intervalle)
    s[QStringLiteral("fpsOut1Low")] = disp.p99 > 0.0 ? 1000.0 / disp.p99 : 0.0;
    s[QStringLiteral("overBudget")] = gpu_total > kBudgetTotalMs || (has_up_shader && gup.avg > up_budget)
        || fg_cost > kBudgetFrameGenMs;
    snap = s;
    emit snapshotChanged();

    if (csv_enabled && session_active.load() && ++csv_ticks >= 2) {
        csv_ticks = 0;
        writeCsv(s);
    }
}

void Stats::writeCsv(const QVariantMap &s)
{
    if (!csv_file.isOpen()) {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + QStringLiteral("/Farplay");
        QDir().mkpath(dir);
        csv_file.setFileName(dir + QStringLiteral("/stats-%1.csv").arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss"))));
        if (!csv_file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            csv_enabled = false;
            emit csvLoggingChanged();
            return;
        }
        QTextStream(&csv_file)
            << "t_s,build,fps_in,fps_out,src_interval_avg_ms,src_interval_p99_ms,disp_interval_avg_ms,disp_interval_p99_ms,disp_interval_max_ms,"
               "gpu_frame_avg_ms,gpu_frame_p99_ms,gpu_blend_avg_ms,gpu_blend_p99_ms,gpu_total_ms,decoder,zero_copy,bit_depth,resolution,hdr,primaries,"
               "present_mode,bitrate_mbps,packet_loss_pct,frames_lost,rtt_ms,"
               "upscaler,upscale_factor,gpu_upscale_avg_ms,gpu_upscale_p99_ms,out_resolution,output,src_peak_nits,"
               "requested_bitrate_mbps,target_bitrate_mbps,"
               "fg_state,fps_gen,fg_pyr_ms,fg_flow_ms,fg_synth_ms,fg_cost_ms,fg_delay_ms,"
               "fps_out_1pct_low,pacing_margin_ms,audio_delay_ms,fps_distinct,gpu_denoise_avg_ms,fg_wait_pct,fg_calls_per_s,fg_wait_detail,fg_queue_detail\n";
        emit csvLoggingChanged();
    }
    const double t = ((int64_t)chiaki_time_now_monotonic_us() - session_start_us) / 1e6;
    auto f = [&](const char *k) { return QString::number(s.value(QLatin1String(k)).toDouble(), 'f', 3); };
    auto str = [&](const char *k) { return s.value(QLatin1String(k)).toString(); };
    QTextStream out(&csv_file);
    out << QString::number(t, 'f', 1) << ',' << buildId() << ','
        << f("fpsIn") << ',' << f("fpsOut") << ',' << f("srcIntervalAvg") << ',' << f("srcIntervalP99") << ','
        << f("dispIntervalAvg") << ',' << f("dispIntervalP99") << ',' << f("dispIntervalMax") << ','
        << f("gpuFrameAvg") << ',' << f("gpuFrameP99") << ',' << f("gpuBlendAvg") << ',' << f("gpuBlendP99") << ',' << f("gpuTotal") << ','
        << str("decoder") << ',' << (s.value(QStringLiteral("zeroCopy")).toBool() ? 1 : 0) << ',' << str("bitDepth") << ','
        << str("resolution") << ',' << str("hdr") << ',' << str("primaries") << ',' << str("presentMode") << ','
        << f("bitrate") << ',' << f("packetLoss") << ',' << str("framesLost") << ',' << f("rttMs") << ','
        << str("upscaler") << ',' << f("upscaleFactor") << ',' << f("gpuUpscaleAvg") << ',' << f("gpuUpscaleP99") << ','
        << str("outResolution") << ',' << str("output") << ',' << f("srcPeakNits") << ','
        << f("requestedBitrate") << ',' << f("targetBitrate") << ','
        << str("fgState") << ',' << f("fpsGen") << ',' << f("fgPyrMs") << ',' << f("fgFlowMs") << ','
        << f("fgSynthMs") << ',' << f("fgCostMs") << ',' << f("fgDelayMs") << ','
        << f("fpsOut1Low") << ',' << f("pacingMarginMs") << ',' << f("audioDelayMs") << ',' << f("fpsDistinct") << ',' << f("gpuDenoiseAvg") << ',' << f("fgWaitPct") << ',' << f("fgCallsPerSec") << ",\"" << str("fgWaitDetail") << "\",\"" << str("fgQueueDetail") << "\"\n";
    out.flush();
}

} // namespace farplay
