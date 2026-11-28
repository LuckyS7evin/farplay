// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — moteur de génération d'images (piste A) : estimation du mouvement
// (optical flow multi-échelle par appariement de blocs) et interpolation
// compensée en mouvement, entièrement sur le GPU via libplacebo.
//
// Indépendant de Qt : utilisable par le banc de test (tests/fg_test.cpp).
//
// Pipeline pour une paire d'images reçues A (antérieure) et B (suivante),
// déjà rendues (upscaling + post-traitement) dans des textures RGBA16F :
//   1. pyramide de luminance par image (une seule fois par image)
//   2. flux A→B du niveau le plus grossier au plus fin (une fois par paire)
//   3. synthèse à la phase t ∈ ]0,1[ (une fois par image affichée)
#pragma once

#include <libplacebo/dispatch.h>
#include <libplacebo/gpu.h>
#include <libplacebo/log.h>

#include <cstdint>

namespace farplay {

class FgEngine
{
public:
    static constexpr int kLevels = 5;   // L0 = 1/4 de la sortie, puis /2 à chaque niveau
    static constexpr int kFlowLevel = 1; // niveau du flux final (≈ un vecteur par bloc 8×8 de la sortie)
    static constexpr int kSlots = 3;

    struct Timings {
        double pyramid_ms = 0.0; // dernière mesure GPU disponible (asynchrone)
        double flow_ms = 0.0;
        double synth_ms = 0.0;
    };

    bool init(pl_gpu gpu, pl_log log);
    void destroy();
    bool ready() const { return gpu_ != nullptr && fmt_rgba_ && fmt_r_ && fmt_flow_; }

    // Texture (RGBA16F, w×h) dans laquelle rendre l'image `sig`.
    // *needs_render = true si son contenu doit être (re)produit.
    pl_tex acquireSlot(uint64_t sig, int w, int h, bool *needs_render);
    // À appeler après avoir rendu dans le slot : construit sa pyramide.
    bool finishSlot(uint64_t sig);
    pl_tex slotTexture(uint64_t sig) const;
    // Luminance la plus réduite de la pyramide du slot (≈ 1/64 de la sortie), nul si absent.
    pl_tex coarseLuma(uint64_t sig) const;

    // Synthétise l'image à la phase t entre les slots a et b.
    // Le flux de la paire est calculé au premier appel puis réutilisé.
    // Retourne la texture de sortie (propriété du moteur) ou nullptr.
    pl_tex synthesize(uint64_t sig_a, uint64_t sig_b, float t, bool hud_protect);
    // Vecteurs de mouvement pour FSR : pour chaque pixel de B, déplacement vers sa
    // position dans A (B→A, coordonnées normalisées, RGBA32F), sur la grille fine
    // L0 (1/4 de la sortie). Calculé dans ce sens et à cette finesse plutôt que
    // d'inverser le flux A→B de la synthèse : les détails fins (cheveux, grillages)
    // gardent leur propre vecteur.
    pl_tex flowFor(uint64_t sig_a, uint64_t sig_b);
    // Copie (avec conversion de format) d'une texture dans une autre, même taille.
    bool copyInto(pl_tex src, pl_tex dst);

    // Qualité du flux : 0 = rapide, 1 = équilibrée (défaut), 2 = qualité.
    // Rapide : grille plus grossière et recherche réduite ; qualité : grille fine
    // aussi pour la synthèse et recherche élargie (mouvements rapides).
    void setQuality(int q);
    int quality() const { return quality_; }

    Timings timings();
    pl_fmt rgbaFormat() const { return fmt_rgba_; }
    pl_gpu gpu() const { return gpu_; }
    // Banc de test : textures lisibles/écrivables depuis le CPU.
    void setHostIo(bool on) { host_io_ = on; }
    pl_tex debugFlow(int level) const { return level < 0 ? fwd_.smooth : fwd_.lvl[level]; }

private:
    struct Slot {
        uint64_t sig = 0;
        bool valid = false;
        uint64_t lru = 0;
        pl_tex rgb = nullptr;
        pl_tex lum[kLevels] = {};
    };

    Slot *find(uint64_t sig);
    const Slot *find(uint64_t sig) const;
    bool ensureTex(pl_tex *tex, pl_fmt fmt, int w, int h);
    // Jeu de textures d'un flux (une direction, un niveau final).
    struct FlowSet {
        pl_tex lvl[kLevels] = {};
        pl_tex smooth = nullptr;
        uint64_t a = 0, b = 0;
        bool valid = false;
        bool has_tprev = false; // `smooth` contient le flux de la paire précédente
    };
    // Flux de `a` vers `b` (bloc de `a` cherché dans `b`) jusqu'au niveau `final_level`.
    bool computeFlow(Slot &a, Slot &b, FlowSet &fs, int final_level);
    void invalidateFlows(uint64_t sig);
    void destroyFlow(FlowSet &fs);

    // Passe « fragment » : écrit `color` dans `target`.
    bool pass(pl_tex target, const char *desc, const char *header, const char *body,
              const struct pl_shader_desc *descs, int num_descs,
              const struct pl_shader_var *vars, int num_vars);
    static void dispatchInfo(void *priv, const struct pl_dispatch_info *info);

    pl_gpu gpu_ = nullptr;
    pl_log log_ = nullptr;
    pl_dispatch dp_ = nullptr;
    pl_fmt fmt_rgba_ = nullptr;
    pl_fmt fmt_r_ = nullptr;
    pl_fmt fmt_flow_ = nullptr;
    pl_fmt fmt_va_ = nullptr;

    Slot slots_[kSlots];
    uint64_t lru_clock_ = 0;

    int quality_ = 1;
    int fwdLevel() const { return quality_ == 0 ? 2 : (quality_ == 2 ? 0 : kFlowLevel); }
    int bwdLevel() const { return quality_ == 0 ? 1 : 0; }
    FlowSet fwd_; // A→B, niveau kFlowLevel (selon la qualité) : synthèse du moteur Farplay
    FlowSet bwd_; // B→A, niveau 0 : vecteurs fournis à FSR

    pl_tex out_ = nullptr;
    bool host_io_ = false;

    // Temps GPU de la dernière exécution de chaque passe (rapportés par
    // libplacebo via pl_dispatch_callback, mesures asynchrones).
    static constexpr int kMaxPasses = 32;
    struct PassTime { char name[24]; uint64_t last_ns; };
    PassTime pass_times_[kMaxPasses] = {};
    int num_pass_times_ = 0;
};

} // namespace farplay
