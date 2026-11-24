# Farplay — feuille de route

État au 24/11/2026. ✅ fait · 🧪 fait, à tester · ⏳ prévu · 💤 seulement si besoin.

## Phase 3 — Frame generation (en validation)

| Élément | Origine | État |
|---|---|---|
| Frame gen interne (flux optique + interpolation, protection du HUD) | Farplay | ✅ |
| Lissage du pacing calé sur les arrivées | PushFPS | ✅ |
| Son retardé du même délai que l'image | PushFPS, smoovplay | ✅ |
| 1 % low dans l'overlay | PushFPS | ✅ |
| Déblocage de la frame gen (profondeur de file, base d'horloge robuste) | Farplay | 🧪 |
| Pas d'interpolation après une perte de paquets | smoovplay | 🧪 |
| Validation : 60 fps stables, latence ajoutée ≤ 33 ms, HUD lisible | cahier des charges | ⏳ |
| Pas d'interpolation sur un changement de plan | smoovplay, ConsoleEnhancer | ⏳ |
| Candidat de mouvement global (panoramiques) | ConsoleEnhancer | ⏳ |
| Échelle du flux optique réglable (1/4 ou 1/2 de la sortie) | Lossless Scaling | ⏳ |
| Mode faible latence par extrapolation (option) | ConsoleEnhancer | ⏳ |
| Frame gen « éco » (simple fondu) | Asobi | 💤 |
| Piste B : RIFE via ncnn | cahier des charges | 💤 |

## Phase 4 — Interface et finitions

| Élément | Origine | État |
|---|---|---|
| Nouvelle interface, profils, assistant, diagnostic | Farplay | ✅ |
| Plus aucun écran chiaki, réglages rapides en jeu, barre du haut, animation | Farplay | 🧪 |
| Réduction des artefacts de compression (NLM) | Farplay | 🧪 |
| Couleurs nettes (chroma guidée par la luminance) | Farplay | 🧪 |
| Archive de build simple, README avec captures | Farplay | 🧪 |
| Navigation complète à la manette vérifiée partout | cahier des charges | ⏳ |
| Post-traitement (F7) | cahier des charges | ⏳ |
| Éditeur de masque HUD | cahier des charges | ⏳ |
| Petit réseau de super-résolution entraîné sur le flux PS5 (runtime Vulkan, ex. DLSSNR-AMD à évaluer) | cahier des charges | ⏳ |
| Outil de mesure de latence (appui simulé → écran) | smoovplay | ⏳ |
| Compteurs FEC / images clés dans l'overlay et le CSV | Nixani | ⏳ |
| Ne pas débruiter les zones déjà plates | ConsoleEnhancer | ⏳ |
| Suppression des fichiers QML chiaki inutilisés | Farplay | ⏳ (fin de phase) |

## Plus tard

| Élément | Origine | État |
|---|---|---|
| Retard audio corrigé en douceur (±0,5–1 %) | smoovplay | 💤 |
| Cadence cible adaptative | Lossless Scaling | 💤 (le mode « Écran » s'en approche) |
| Détection des images répétées par taille compressée | smoovplay | 💤 (flux 60 Hz portant du 30 fps) |
| Essai 1440p/4K demandé à la PS5 | Farplay | 💤 (refus probable) |

## V2 — amendement du cahier des charges (upscalers temporels autorisés)

| Élément | Origine | Conditions | Coût estimé | Latence ajoutée |
|---|---|---|---|---|
| Nettoyeur temporel maison (images précédentes recalées par notre flux optique) | Farplay | flux optique déjà calculé par la FG | ~1 ms | aucune image d'attente |
| FSR 3.1 temporel | AMD FidelityFX (MIT) | Vulkan OK ; vecteurs = notre flux (gratuits avec la FG), profondeur constante, pas de jitter dans la source | ~1–1,5 ms | aucune image d'attente |
| FSR 4.1 temporel (ML) | AMD | à vérifier : disponibilité en Vulkan (DX12 seul de mémoire) et licence du SDK ; mêmes limites d'entrées | ~2–3 ms | aucune image d'attente |
| AMDLSS5 / DLSS 5 | Wehaveall | écarté : besoin des buffers du jeu, poids NVIDIA non redistribuables | — | — |

Les coûts sont des estimations sur RX 9070 XT, à mesurer. Comparaison prévue : nettoyeur temporel seul, FSR 3.1 et FSR 4.1, contre la chaîne actuelle (NLM + chroma + FSR 1).
