// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — génération d'images AMD FSR (FidelityFX SDK 2.4, backend Vulkan).
//
// FSR 4.0.x (IA) sur RX 9000, 3.1.x ailleurs (choisi par le chargeur AMD).
// Utilisé en « dispatch manuel » : FSR produit seulement l'image intermédiaire,
// Farplay garde son affichage et son pacing. Les DLL signées d'AMD
// (amd_fidelityfx_loader_vk.dll, amd_fidelityfx_framegeneration_vk.dll) sont
// chargées à l'exécution depuis le dossier de l'application ; sans elles (ou hors
// Windows), FSR est simplement indisponible et la frame gen maison prend le relais.
//
// Synchronisation avec libplacebo : les textures sont « tenues » (pl_vulkan_hold_ex)
// avec un sémaphore timeline, FSR enregistre son travail dans notre propre
// command buffer soumis sur la file graphique de libplacebo, puis les textures
// sont rendues (pl_vulkan_release_ex) sur le sémaphore de fin.
#pragma once

#include <libplacebo/gpu.h>
#include <libplacebo/vulkan.h>

#include <QString>
#include <cstdint>

namespace farplay {

class FsrFrameGen
{
public:
    FsrFrameGen() = default;
    ~FsrFrameGen();

    // Thread de rendu. `vk` peut être nul (moteur OpenGL) : FSR reste indisponible.
    void init(pl_vulkan vk, pl_log log);
    void destroy();

    // Prêt à générer (DLL chargées, Vulkan présent, pas d'erreur fatale).
    bool usable() const { return usable_ && !failed_; }
    // Texte d'état pour l'overlay : version du fournisseur ou raison de l'échec.
    QString status() const;
    // Version du fournisseur effectivement utilisée (ex. « 4.0.2 »), vide sinon.
    QString providerVersion() const { return provider_; }

    // Génère l'image intermédiaire entre l'image courante précédente (historique
    // interne de FSR) et `cur`. `reset` : discontinuité (l'image précédente n'était
    // pas la voisine de `cur`). `mv` : vecteurs de mouvement de l'image courante
    // (nul = aucun mouvement fourni), multipliés par (mv_sx, mv_sy) pour obtenir
    // des pixels de `mv` (FSR : pixelSpaceMV = mv × scale). Retourne la texture de
    // sortie (propriété de l'objet) ou nullptr en cas d'échec.
    pl_tex generate(pl_tex cur, bool reset, pl_tex mv, float mv_sx, float mv_sy,
                    bool hdr_pq, float max_nits, float frame_dt_ms);

private:
    bool loadLibrary();
    bool ensureContext(int w, int h, pl_fmt fmt, bool hdr);
    void destroyContext();
    bool ensureAux(int w, int h, int rw, int rh);
    void fail(const QString &why);

    pl_vulkan vk_ = nullptr;
    pl_gpu gpu_ = nullptr;
    pl_log log_ = nullptr;
    bool usable_ = false;
    bool failed_ = false;
    QString error_;
    QString provider_;

    void *module_ = nullptr;     // HMODULE du chargeur AMD
    void *fns_[5] = {};          // CreateContext, DestroyContext, Configure, Query, Dispatch
    void *ctx_ = nullptr;        // ffxContext
    int ctx_w_ = 0, ctx_h_ = 0;
    pl_fmt ctx_fmt_ = nullptr;
    bool ctx_hdr_ = false;
    uint64_t frame_id_ = 0;

    // Fonctions Vulkan du périphérique de libplacebo
    struct Vk;
    Vk *vkf_ = nullptr;

    pl_tex out_ = nullptr;       // image générée (RGBA16F, stockable)
    pl_tex depth_ = nullptr;     // profondeur constante (R32F)
    pl_tex zero_mv_ = nullptr;   // vecteurs nuls (RG16F)

    VkSemaphore sem_ = VK_NULL_HANDLE; // timeline partagée avec libplacebo
    uint64_t sem_val_ = 0;
    static constexpr int kCmd = 3;
    VkCommandPool pool_ = VK_NULL_HANDLE;
    VkCommandBuffer cmd_[kCmd] = {};
    VkQueue queue_ = VK_NULL_HANDLE;
    uint32_t qf_ = 0, qidx_ = 0;
    uint64_t cmd_done_[kCmd] = {};
    int cmd_next_ = 0;
};

} // namespace farplay
