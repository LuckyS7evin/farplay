// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — réglages d'image appliqués au rendu libplacebo (phase 2) :
// upscaling (FSR 1 / FSRCNNX), netteté, lissage des dégradés, SDR sur écran HDR.
//
// Les réglages sont écrits sur le thread GUI et lus par le thread de rendu
// via des atomiques ; les ressources GPU (hooks) sont créées/détruites sur le
// thread de rendu par initGpu()/destroyGpu().
#pragma once

#include <QObject>
#include <atomic>

#include <libplacebo/gpu.h>
#include <libplacebo/colorspace.h>

struct pl_hook;
struct pl_render_params;

namespace farplay {

class Image : public QObject
{
    Q_OBJECT
    // 0 = réglage chiaki-ng, 1 = FSR 1 (défaut), 2 = FSRCNNX (réseau léger), 3 = libplacebo seul
    Q_PROPERTY(int upscaler READ upscaler WRITE setUpscaler NOTIFY changed)
    // Netteté RCAS en % (0..100), 70 par défaut (choix utilisateur)
    Q_PROPERTY(int sharpness READ sharpness WRITE setSharpness NOTIFY changed)
    // Lissage des dégradés : 0 = coupé, 1 = faible (défaut), 2 = moyen
    Q_PROPERTY(int deband READ deband WRITE setDeband NOTIFY changed)
    // Afficher un flux SDR en HDR sur un écran HDR, avec luminosité de référence
    Q_PROPERTY(bool sdrToHdr READ sdrToHdr WRITE setSdrToHdr NOTIFY changed)
    Q_PROPERTY(int sdrWhiteNits READ sdrWhiteNits WRITE setSdrWhiteNits NOTIFY changed)

public:
    static Image &instance();
    static void registerQml();

    int upscaler() const { return upscaler_.load(std::memory_order_relaxed); }
    void setUpscaler(int v);
    int sharpness() const { return sharpness_.load(std::memory_order_relaxed); }
    void setSharpness(int v);
    int deband() const { return deband_.load(std::memory_order_relaxed); }
    void setDeband(int v);
    bool sdrToHdr() const { return sdr_to_hdr_.load(std::memory_order_relaxed); }
    void setSdrToHdr(bool v);
    int sdrWhiteNits() const { return sdr_white_.load(std::memory_order_relaxed); }
    void setSdrWhiteNits(int v);
    Q_INVOKABLE void resetRecommended();

    // --- thread de rendu ---
    void initGpu(pl_gpu gpu);
    void destroyGpu();

    // Choisit le hook d'upscaling. `chiaki_hook` est celui que chiaki-ng aurait
    // utilisé (réglage d'origine), `fsrcnnx8` le hook FSRCNNX déjà chargé.
    const struct pl_hook *selectHook(bool source_pq, float upscale_factor,
                                     const struct pl_hook *chiaki_hook,
                                     const struct pl_hook *fsrcnnx8);

    // Ajuste les paramètres de rendu (lissage des dégradés).
    void applyRenderParams(struct pl_render_params *params);

    // Image source mappée : luminosité de référence d'un flux SDR.
    void adjustSourceColor(struct pl_color_space *color) const;

    // Indication de sortie à la swapchain : demande du HDR10 pour un flux SDR
    // quand "SDR sur écran HDR" est actif.
    void adjustSwapchainHint(struct pl_color_space *hint) const;

    static bool isHdrTransfer(enum pl_color_transfer trc);

signals:
    void changed();

private:
    explicit Image(QObject *parent = nullptr);
    void save();

    std::atomic<int> upscaler_{1};
    std::atomic<int> sharpness_{70};
    std::atomic<int> deband_{1};
    std::atomic<bool> sdr_to_hdr_{true};
    std::atomic<int> sdr_white_{200};

    pl_gpu gpu_ = nullptr;
    const struct pl_hook *fsr_sdr_ = nullptr;
    const struct pl_hook *fsr_pq_ = nullptr;
};

} // namespace farplay
