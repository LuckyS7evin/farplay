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

#include <libplacebo/renderer.h>

#include <QObject>
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

    // Frame gen interne effectivement demandée (réglage + raccourci).
    bool internalActive() const { return mode() == 1 && !suspended(); }

    // --- thread de rendu ---
    void initGpu(pl_gpu gpu, pl_log log);
    void destroyGpu();
    // Retard de présentation (s) à appliquer à l'horloge de pl_queue.
    double presentDelaySeconds(double source_interval_s) const;
    // Profondeur minimale de la file d'images source.
    int minQueueDepth() const { return internalActive() ? 3 : 0; }
    // Rend la vsync courante ; false = laisser chiaki-ng rendre normalement.
    bool render(pl_renderer renderer, const struct pl_frame_mix *mix,
                const struct pl_frame *target, const struct pl_render_params *params);

signals:
    void changed();

private:
    explicit FrameGen(QObject *parent = nullptr);
    void save();

    std::atomic<int> mode_{1};
    std::atomic<int> multiplier_{2};
    std::atomic<bool> hud_{true};
    std::atomic<bool> suspended_{false};
    bool amd_ = false;

    FgEngine engine_;
    bool gpu_ok_ = false;
};

} // namespace farplay
