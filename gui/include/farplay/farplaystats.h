// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — collecte des statistiques de rendu (fps, temps GPU par étape, HDR).
//
// Les points d'entrée "hot path" (onSourceFrame, onDisplayFrame,
// plInfoCallback) sont appelés depuis les threads décodage/rendu : ils
// n'allouent pas et ne tiennent qu'un mutex non contendu quelques ns.
// Le snapshot destiné à l'overlay est calculé à 2 Hz sur le thread GUI.
#pragma once

#include <QObject>
#include <QMutex>
#include <QTimer>
#include <QVariantMap>
#include <QFile>
#include <QPointer>
#include <atomic>
#include <cstdint>
#include <functional>

struct AVFrame;
struct pl_render_info;
class QmlMainWindow;
class QmlBackend;

namespace farplay {

// Fenêtre glissante de N échantillons (ms), allouée une fois.
template<int N>
struct SampleRing {
    float v[N] = {};
    int count = 0;
    int head = 0;
    void push(float x) { v[head] = x; head = (head + 1) % N; if (count < N) count++; }
    void clear() { count = 0; head = 0; }
};

struct NetSample {
    double bitrate_mbps = 0.0;
    double packet_loss = 0.0;   // 0..1
    int frames_lost = 0;
    double rtt_ms = 0.0;
    double requested_bitrate_mbps = 0.0; // demandé à la PS5 (réglage)
    double target_bitrate_mbps = 0.0;    // cible annoncée par la PS5
    bool connected = false;
};

class Stats : public QObject
{
    Q_OBJECT
    // 0 = masqué, 1 = compact, 2 = détaillé
    Q_PROPERTY(int overlayLevel READ overlayLevel WRITE setOverlayLevel NOTIFY overlayLevelChanged)
    Q_PROPERTY(bool mailbox READ mailbox WRITE setMailbox NOTIFY mailboxChanged)
    Q_PROPERTY(bool csvLogging READ csvLogging WRITE setCsvLogging NOTIFY csvLoggingChanged)
    Q_PROPERTY(QString csvPath READ csvPath NOTIFY csvLoggingChanged)
    Q_PROPERTY(QVariantMap snapshot READ snapshot NOTIFY snapshotChanged)
    Q_PROPERTY(QString monoFont READ monoFont CONSTANT)
    Q_PROPERTY(QString uiFont READ uiFont CONSTANT)
    Q_PROPERTY(bool firstLaunch READ firstLaunch NOTIFY firstLaunchChanged)
    // Barre du haut en jeu : la souris est près du haut de l'écran pendant une session
    Q_PROPERTY(bool topBarActive READ topBarActive NOTIFY topBarActiveChanged)
    Q_PROPERTY(QString buildId READ buildId CONSTANT)
    Q_PROPERTY(QString iconBase READ iconBase CONSTANT)

public:
    // Budgets du cahier des charges (ms GPU).
    static constexpr double kBudgetTotalMs = 8.0;
    static constexpr double kBudgetDecodeMs = 3.0;
    static constexpr double kBudgetUpscaleMs = 1.0;
    static constexpr double kBudgetUpscaleNetMs = 4.0;

    enum class Upscaler { None, Builtin, Chiaki, Fsr1, Fsrcnnx, Fallback };
    enum class FgState { Off, Active, Waiting, Suspended, Afmf, Unavailable, Pacing };

    static Stats &instance();

    // Enregistre le singleton QML "Farplay" (module org.streetpea.chiaking),
    // relie les réglages au QmlMainWindow et suit la session en cours.
    static void registerQml(QmlBackend *backend, QmlMainWindow *window);

    // --- hot path ---
    void onSourceFrame(const AVFrame *frame);
    void onDisplayFrame(int64_t now_us);
    static void plInfoCallback(void *priv, const struct pl_render_info *info);
    void setPresentMode(int vk_present_mode, bool supported);
    void setSessionActive(bool active);
    // Phase 2 : upscaling et diagnostic HDR (thread de rendu)
    void setUpscaler(Upscaler used, float factor);
    void setOutputColor(int pl_transfer, int pl_primaries, int width, int height);
    void setSourcePeak(float nits);
    // Phase 3 : génération d'images (thread de rendu)
    void setFrameGenState(FgState state);
    // new_image = image différente de la précédente (à 120 Hz en x2, chaque image est présentée deux fois)
    void onFrameGenOutput(bool generated, bool new_image, double pyramid_ms, double flow_ms, double synth_ms);
    void setFrameGenDelay(double ms);
    static constexpr double kBudgetFrameGenMs = 4.0;
    // Âge de la dernière image source (µs), ou -1 si aucune.
    int64_t lastSourceAgeUs() const;

    int overlayLevel() const { return overlay_level; }
    void setOverlayLevel(int level);
    Q_INVOKABLE void cycleOverlayLevel() { setOverlayLevel((overlay_level + 1) % 3); }
    bool mailbox() const { return mailbox_enabled.load(std::memory_order_relaxed); }
    void setMailbox(bool enabled);
    bool csvLogging() const { return csv_enabled; }
    void setCsvLogging(bool enabled);
    QString csvPath() const { return csv_file.fileName(); }
    QVariantMap snapshot() const { return snap; }
    QString monoFont() const { return mono_font; }
    QString uiFont() const { return ui_font; }
    bool firstLaunch() const;
    bool topBarActive() const { return top_bar_active; }
    void setTopBarActive(bool v) { if (v != top_bar_active) { top_bar_active = v; emit topBarActiveChanged(); } }
    Q_INVOKABLE void setFirstLaunchDone();
    QString buildId() const;
    QString iconBase() const { return QStringLiteral("qrc:/farplay/icons/ui/"); }

signals:
    void overlayLevelChanged();
    void mailboxChanged();
    void csvLoggingChanged();
    void snapshotChanged();
    void firstLaunchChanged();
    void topBarActiveChanged();

private:
    explicit Stats(QObject *parent = nullptr);
    void tick();
    void writeCsv(const QVariantMap &s);

    static constexpr int kRing = 256;

    mutable QMutex mutex;
    // Protégé par mutex
    SampleRing<kRing> src_interval_ms;
    SampleRing<kRing> disp_interval_ms;
    SampleRing<kRing> gpu_frame_ms;   // PL_RENDER_STAGE_FRAME : traitement d'une image source
    SampleRing<kRing> gpu_blend_ms;   // PL_RENDER_STAGE_BLEND : composition/mélange par image affichée
    SampleRing<kRing> gpu_upscale_ms; // passes d'upscaling (shaders FSR / FSRCNNX), incluses dans FRAME
    Upscaler upscaler = Upscaler::None;
    float upscale_factor = 0.0f;
    int out_trc = 0, out_prim = 0, out_width = 0, out_height = 0;
    float src_peak_nits = 0.0f;
    FgState fg_state = FgState::Off;
    uint64_t fg_generated = 0;
    uint64_t fg_distinct = 0;
    uint64_t prev_fg_distinct = 0;
    double fg_pyr_ms = 0.0, fg_flow_ms = 0.0, fg_synth_ms = 0.0, fg_delay_ms = 0.0;
    uint64_t prev_fg_generated = 0;
    std::atomic<int64_t> last_src_seen_us{0};
    int64_t last_src_us = 0;
    int64_t last_disp_us = 0;
    uint64_t src_count = 0;
    uint64_t disp_count = 0;
    int src_width = 0, src_height = 0;
    int src_pix_fmt = -1, src_sw_fmt = -1;
    int src_trc = 0, src_prim = 0, src_space = 0, src_range = 0;
    int present_mode = -1;
    bool present_supported = true;

    // Accumulateurs du frame en cours (thread rendu uniquement)
    uint64_t acc_frame_ns = 0;
    uint64_t acc_blend_ns = 0;
    uint64_t acc_upscale_ns = 0;

    std::atomic<bool> mailbox_enabled{false};
    std::atomic<bool> session_active{false};
    int overlay_level = 1;
    bool csv_enabled = false;
    QFile csv_file;
    uint64_t prev_src_count = 0, prev_disp_count = 0;
    int64_t prev_tick_us = 0;
    int csv_ticks = 0;

    QVariantMap snap;
    QTimer timer;
    QString mono_font;
    QString ui_font;
    bool top_bar_active = false;
    std::function<NetSample()> net;
    int64_t session_start_us = 0;
};

} // namespace farplay
