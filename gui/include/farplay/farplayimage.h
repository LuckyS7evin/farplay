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
    // 1 = FSR 1 (défaut), 2 = NIS (NVIDIA Image Scaling). Les anciens choix
    // (réglage chiaki-ng, FSRCNNX, libplacebo seul) sont retirés et migrés vers FSR 1.
    Q_PROPERTY(int upscaler READ upscaler WRITE setUpscaler NOTIFY changed)
    // Netteté en % (0..100), 50 par défaut : RCAS pour FSR 1, affûtage intégré pour NIS
    Q_PROPERTY(int sharpness READ sharpness WRITE setSharpness NOTIFY changed)
    // Lissage des dégradés : 0 = coupé, 1 = faible (défaut), 2 = moyen
    Q_PROPERTY(int deband READ deband WRITE setDeband NOTIFY changed)
    // Réduction des artefacts de compression (NLM sur la luminance, avant
    // l'agrandissement) : 0 = coupée, 1 = faible, 2 = moyenne (défaut), 3 = forte
    Q_PROPERTY(int denoise READ denoise WRITE setDenoise NOTIFY changed)
    // Couleur 4:2:0 reconstruite à pleine résolution guidée par la luminance
    Q_PROPERTY(bool chromaFromLuma READ chromaFromLuma WRITE setChromaFromLuma NOTIFY changed)
    // Afficher un flux SDR en HDR sur un écran HDR, avec luminosité de référence
    Q_PROPERTY(bool sdrToHdr READ sdrToHdr WRITE setSdrToHdr NOTIFY changed)
    Q_PROPERTY(int sdrWhiteNits READ sdrWhiteNits WRITE setSdrWhiteNits NOTIFY changed)
    // Post-traitement des couleurs (F7), en % : contraste et saturation -50..+50, vibrance 0..100
    Q_PROPERTY(int contrast READ contrast WRITE setContrast NOTIFY changed)
    Q_PROPERTY(int saturation READ saturation WRITE setSaturation NOTIFY changed)
    Q_PROPERTY(int vibrance READ vibrance WRITE setVibrance NOTIFY changed)

public:
    static Image &instance();
    static void registerQml();

    int upscaler() const { return upscaler_.load(std::memory_order_relaxed); }
    void setUpscaler(int v);
    int sharpness() const { return sharpness_.load(std::memory_order_relaxed); }
    void setSharpness(int v);
    int deband() const { return deband_.load(std::memory_order_relaxed); }
    void setDeband(int v);
    int denoise() const { return denoise_.load(std::memory_order_relaxed); }
    void setDenoise(int v);
    bool chromaFromLuma() const { return cfl_.load(std::memory_order_relaxed); }
    void setChromaFromLuma(bool v);
    bool sdrToHdr() const { return sdr_to_hdr_.load(std::memory_order_relaxed); }
    void setSdrToHdr(bool v);
    int sdrWhiteNits() const { return sdr_white_.load(std::memory_order_relaxed); }
    void setSdrWhiteNits(int v);
    int contrast() const { return contrast_.load(std::memory_order_relaxed); }
    void setContrast(int v);
    int saturation() const { return saturation_.load(std::memory_order_relaxed); }
    void setSaturation(int v);
    int vibrance() const { return vibrance_.load(std::memory_order_relaxed); }
    void setVibrance(int v);
    Q_INVOKABLE void resetRecommended();
    Q_INVOKABLE void resetColor();

    // --- thread de rendu ---
    void initGpu(pl_gpu gpu);
    void destroyGpu();

    // Choisit le hook d'upscaling. `chiaki_hook` est celui que chiaki-ng aurait
    // utilisé (réglage d'origine), `fsrcnnx8` le hook FSRCNNX déjà chargé.
    const struct pl_hook *selectHook(bool source_pq, float upscale_factor,
                                     const struct pl_hook *chiaki_hook,
                                     const struct pl_hook *fsrcnnx8);
    // Liste des hooks à appliquer, dans l'ordre : chroma, réduction d'artefacts,
    // upscaling, post-traitement couleur. Renvoie le nombre de hooks écrits dans
    // `out` (kMaxHooks au plus). `source_pq` : pivot du contraste en PQ.
    static constexpr int kMaxHooks = 4;
    int buildHooks(const struct pl_hook *upscale_hook, const struct pl_hook **out, bool source_pq = false);

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
    std::atomic<int> sharpness_{50};
    std::atomic<int> deband_{1};
    std::atomic<int> denoise_{2};
    const struct pl_hook *deartifact_ = nullptr;
    const struct pl_hook *cfl_hook_ = nullptr;
    std::atomic<bool> cfl_{true};
    std::atomic<bool> sdr_to_hdr_{true};
    std::atomic<int> sdr_white_{200};
    std::atomic<int> contrast_{0};
    std::atomic<int> saturation_{0};
    std::atomic<int> vibrance_{0};
    const struct pl_hook *nis_ = nullptr;
    const struct pl_hook *post_color_ = nullptr;

    pl_gpu gpu_ = nullptr;
    const struct pl_hook *fsr_sdr_ = nullptr;
    const struct pl_hook *fsr_pq_ = nullptr;
};

} // namespace farplay
