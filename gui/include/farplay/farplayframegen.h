// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — génération d'images (F3/F4) branchée sur la boucle de rendu.
//
// Principe : quand la frame gen interne est active, chiaki-ng passe en rendu
// à la cadence de l'écran (frame mixer) et la présentation est retardée d'une
// image source, de sorte que pl_queue fournisse toujours l'image reçue
// courante A et la suivante B. Pour chaque rafraîchissement, Farplay :
//   1. rend A et B une seule fois chacune (upscaling, post-traitement) dans
//      des textures du moteur (les effets ne touchent que les images reçues),
//   2. synthétise l'image à la phase t entre A et B (FgEngine),
//   3. présente le résultat dans la cible de chiaki (overlay QML inclus).
#pragma once

#include "farplay/fgengine.h"
#include "farplay/fsrframegen.h"

#include <libplacebo/renderer.h>

#include <QObject>
#include <QMutex>
#include <QString>
#include <atomic>


namespace farplay {

class FrameGen : public QObject
{
    Q_OBJECT
    // 0 = coupée, 1 = interne (optical flow), 2 = AFMF (pilote AMD)
    Q_PROPERTY(int mode READ mode WRITE setMode NOTIFY changed)
    // 0 = fréquence de l'écran, 2/3/4 = multiplicateur fixe
    Q_PROPERTY(int multiplier READ multiplier WRITE setMultiplier NOTIFY changed)
    Q_PROPERTY(bool hudProtect READ hudProtect WRITE setHudProtect NOTIFY changed)
    // Raccourci F4 : coupe/rétablit la frame gen interne sans changer le réglage
    Q_PROPERTY(bool suspended READ suspended NOTIFY changed)
    Q_PROPERTY(bool amdGpu READ amdGpu CONSTANT)
    // Lissage du pacing : présentation sur une horloge régulière estimée à
    // partir des arrivées, avec une marge adaptée à la gigue mesurée.
    Q_PROPERTY(bool pacing READ pacing WRITE setPacing NOTIFY changed)
    // Moteur de la frame gen interne : 0 = Farplay (flux optique maison),
    // 1 = AMD FSR (4.0 IA sur RX 9000, 3.1 sinon ; repli automatique sur Farplay)
    Q_PROPERTY(int engine READ engine WRITE setEngine NOTIFY changed)
    // Mouvement fourni à FSR : 0 = aucun (flux interne de FSR), 1 = flux Farplay
    Q_PROPERTY(int fsrMotion READ fsrMotion WRITE setFsrMotion NOTIFY changed)
    // État de FSR pour l'interface (version ou raison de l'indisponibilité)
    Q_PROPERTY(QString fsrStatus READ fsrStatus NOTIFY fsrStatusChanged)

public:
    static FrameGen &instance();
    static void registerQml(bool amd_gpu);

    int mode() const { return mode_.load(std::memory_order_relaxed); }
    void setMode(int v);
    int multiplier() const { return multiplier_.load(std::memory_order_relaxed); }
    void setMultiplier(int v);
    bool hudProtect() const { return hud_.load(std::memory_order_relaxed); }
    void setHudProtect(bool v);
    bool suspended() const { return suspended_.load(std::memory_order_relaxed); }
    Q_INVOKABLE void toggleSuspended();
    bool amdGpu() const { return amd_; }
    bool pacing() const { return pacing_.load(std::memory_order_relaxed); }
    void setPacing(bool v);
    int engine() const { return engine_sel_.load(std::memory_order_relaxed); }
    void setEngine(int v);
    int fsrMotion() const { return fsr_motion_.load(std::memory_order_relaxed); }
    void setFsrMotion(int v);
    QString fsrStatus() const;

    // Présentation cadencée par l'horloge des images (frame gen ou lissage).
    bool timedPresentation() const { return internalActive() || pacing(); }

    // Arrivée d'une image source (thread décodage) : horodatage d'arrivée et
    // pts du flux (s). Alimente l'horloge d'affichage et l'estimation de la gigue.
    // `lost` : des images ont été perdues juste avant celle-ci (paquets manquants) ;
    // l'image et les suivantes peuvent être corrompues jusqu'à la reprise du flux.
    void noteSourceArrival(int64_t now_us, double pts_s, bool lost = false);
    // Horloge d'affichage (thread de rendu) : pts relatif à la file à viser
    // pour la vsync courante, calé sur l'arrivée la plus précoce récente
    // (insensible à la dérive entre l'horloge de la PS5 et celle du PC).
    // false tant qu'il n'y a pas assez de mesures.
    bool displayPts(int64_t now_us, double queue_origin_s, double vsync_s, double delay_s, double *out_pts) const;
    // Marge anti-gigue actuelle (ms) et retard total appliqué à l'image (ms),
    // que le son doit aussi subir pour rester synchronisé.
    double jitterMarginMs() const { return margin_ms_.load(std::memory_order_relaxed); }
    double audioDelayMs() const { return audio_delay_ms_.load(std::memory_order_relaxed); }

    // Frame gen interne effectivement demandée (réglage + raccourci).
    bool internalActive() const { return mode() == 1 && !suspended(); }

    // --- thread de rendu ---
    void initGpu(pl_gpu gpu, pl_log log, pl_vulkan vk = nullptr);
    void destroyGpu();
    // Retard de présentation (s) à appliquer à l'horloge de pl_queue.
    double presentDelaySeconds(double source_interval_s) const;
    // Profondeur minimale de la file d'images source.
    // Avec la présentation retardée, la file contient l'image affichée A, la
    // suivante B et celles arrivées pendant le retard : une limite trop basse
    // fait mettre B de côté (image « en attente » de chiaki) et bloque la synthèse.
    int minQueueDepth() const { return internalActive() ? 5 : (pacing() ? 3 : 0); }
    // Rend la vsync courante ; false = laisser chiaki-ng rendre normalement.
    bool render(pl_renderer renderer, const struct pl_frame_mix *mix,
                const struct pl_frame *target, const struct pl_render_params *params);

signals:
    void changed();
    void fsrStatusChanged();

private:
    explicit FrameGen(QObject *parent = nullptr);
    void save();

    std::atomic<int> mode_{1};
    std::atomic<int> multiplier_{2};
    std::atomic<bool> hud_{true};
    std::atomic<bool> suspended_{false};
    std::atomic<bool> pacing_{true};
    std::atomic<int> engine_sel_{1};
    std::atomic<int> fsr_motion_{0};
    // FSR (thread de rendu)
    FsrFrameGen fsr_;
    uint64_t fsr_a_ = 0, fsr_b_ = 0;  // paire dont fsr_out_ est l'image du milieu
    pl_tex fsr_out_ = nullptr;
    pl_tex fsr_in_ = nullptr;   // copie 8/10 bits de B pour FSR
    bool fsr_out_valid_ = false;
    mutable QMutex fsr_status_mutex_;
    QString fsr_status_;
    void publishFsrStatus();
    std::atomic<double> margin_ms_{3.0};
    mutable std::atomic<double> audio_delay_ms_{0.0};

    // Estimation de la gigue (thread décodage uniquement) : décalage
    // arrivée − pts de chaque image ; le minimum sur la fenêtre = arrivée
    // « sans retard », l'écart au minimum = retard de l'image.
    static constexpr int kArrivals = 240; // ≈ 8 s à 30 fps
    double offsets_[kArrivals] = {};
    double times_[kArrivals] = {};   // instants d'arrivée (s)
    static constexpr int kFit = 60;  // ≈ 2 s : fenêtre de l'ajustement de la dérive
    int num_arrivals_ = 0;
    int arrival_head_ = 0;
    int since_estimate_ = 0;
    double last_offset_ = 0.0;
    std::atomic<double> base_offset_{0.0};  // base à l'instant base_t_
    std::atomic<double> base_slope_{0.0};   // dérive de la base (s par s)
    std::atomic<double> base_t_{0.0};
    mutable double last_out_pts_ = -1.0, last_origin_ = -1.0; // pts visé croissant (thread rendu)
    std::atomic<bool> base_valid_{false};
    void estimateJitter();
    bool amd_ = false;

    FgEngine engine_;
    bool gpu_ok_ = false;
    // Dernière image présentée (évite de resynthétiser une image répétée)
    uint64_t last_sig_a_ = 0, last_sig_b_ = 0;
    float last_t_ = -1.0f;
    pl_tex last_show_ = nullptr;
    // Après une perte : pas d'interpolation pendant quelques images reçues
    // (on affiche l'image reçue telle quelle plutôt que d'étaler les défauts).
    std::atomic<int> loss_hold_{0};
    uint64_t hold_sig_ = 0;
    bool holding_ = false;
};

} // namespace farplay
