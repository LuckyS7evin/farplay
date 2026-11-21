# Cahier des charges — Client Remote Play PS5 optimisé

Nov 21, 2026 · @S7evin

## Contexte et objectifs

L'objectif : un client Remote Play PS5 pour Windows qui transforme un flux 1080p/30 fps en image 4K/60 fps fluide, avec le moins de latence ajoutée possible. Le cas d'usage de référence est GTA 6, verrouillé à 30 fps sur PS5 classique.

**Matériel cible**

| Élément | Modèle | Rôle |
| --- | --- | --- |
| Console | PS5 classique, via Denon AVR-X2200W et LG 55B1 | Source du flux |
| GPU | AMD Radeon RX 9070 XT (RDNA 4) | Décodage, upscaling, frame gen |
| CPU | AMD Ryzen 7 7600 | Réseau, audio, manette |
| Écran PC | LG 42C5 OLED, 4K 144 Hz, HDR, VRR | Affichage |
| OS | Windows 11 | Plateforme v1 |

**Objectifs mesurables**

- Image 60 fps stable à partir d'un flux 30 fps, avec un pacing régulier (pas de saccade visible).
- Latence ajoutée par le traitement (upscaling + frame gen) inférieure ou égale à 1 image source, soit environ 33 ms.
- HDR correct de bout en bout : aucune image délavée.
- Réglages compréhensibles par un non-spécialiste : chaque option dit ce qu'elle fait et ce qu'elle coûte.

## Périmètre

La v1 couvre le Remote Play local depuis sa propre PS5 sous Windows 11, avec upscaling, frame gen et HDR intégrés au rendu.

**Dans la v1**

- Remote Play PS5 (et PS4) en réseau local, hérité de chiaki-ng : appairage, réveil, flux H.265 HDR.
- Upscaling 1080p vers 4K et frame generation x2, directement dans le pipeline de rendu Vulkan.
- HDR10 de bout en bout, avec diagnostic du signal reçu.
- DualSense en USB et Bluetooth : haptique, gâchettes adaptatives, gyroscope.
- Interface de réglages et overlay de statistiques.

**Hors périmètre v1**

- Cloud Gaming PS Plus : bloqué par Sony pour les clients tiers. Pas besoin
- Linux/Fedora, macOS, Steam Deck : envisagés en v2, car chiaki-ng est déjà multiplateforme.
- Remote Play hors du réseau local (via Internet) : v2.
- Enregistrement ou streaming vers Twitch : hors sujet. Pas besoin.

## Architecture

L'app est un fork de chiaki-ng : on garde le réseau, le protocole et la manette, et on ajoute l'upscaling et la frame gen dans le rendu Vulkan, entre le décodage et l'affichage.

&#91;embedded content: pipeline du client · 6 étapes, 1 option\]

L'image décodée ne quitte jamais la mémoire du GPU. AFMF reste une alternative à l'étape de frame gen, prise en charge par le pilote.

## Exigences fonctionnelles

Chaque traitement d'image est un module interchangeable du pipeline, activable séparément et mesuré en temps GPU.

**F1 — Remote Play**

- Reprendre tel quel le cœur de chiaki-ng : découverte, appairage par PIN, connexion PSN, réveil depuis le mode repos.
- Bitrate réglable jusqu'au maximum accepté par la PS5, avec 30 fps proposé par défaut pour les jeux à 30 fps.
- Décodage matériel Vulkan Video (H.265 10 bits), sans copie CPU entre décodage et rendu (zero-copy).

**F2 — Upscaling (1080p vers 4K)**

- Niveau 1 : FSR 1 (EASU + RCAS), léger et fiable, mode par défaut.
- Niveau 2 : petit réseau de super-résolution vidéo (type FSRCNNX, ou modèle léger via ncnn-Vulkan), prévu pour du contenu réaliste compressé.
- Les upscalers temporels (FSR 4, DLSS, AMDLSS) sont exclus : ils exigent les vecteurs de mouvement, la profondeur et le jitter du jeu, absents d'un flux vidéo.
- Option de réduction des artefacts de compression (deblocking léger) avant l'upscaling.

**F3 — Frame generation (30 vers 60 fps)**

- Piste A : FidelityFX Optical Flow + interpolation, natif AMD, à évaluer en premier.
- Piste B : RIFE (version légère) via ncnn-Vulkan, plus propre sur les mouvements complexes mais plus coûteuse.
- Piste C : utiliser les vecteurs de mouvement du flux H.265 comme indice pour l'optical flow (R&D, à valider).
- Une seule image source retenue au maximum ; protection du HUD (masque fixe ou détection des zones statiques) pour limiter les artefacts sur la mini-map et les textes.

**F4 — Piste AFMF (pilote AMD)**

- Mode « Frame gen : AFMF » qui désactive la frame gen interne et laisse le pilote AMD générer les images.
- L'app doit être compatible AFMF : rendu Vulkan en plein écran, présentation adaptée, détection de la carte AMD.
- Assistant intégré qui explique comment activer AFMF dans Adrenalin et vérifie le résultat via le compteur d'images.
- À vérifier dès la phase 0 : si AFMF s'active déjà sur chiaki-ng, la piste A devient secondaire.

**F5 — HDR**

- Sortie HDR10 (PQ, BT.2020) native via Vulkan, avec bascule automatique SDR/HDR selon le flux reçu.
- Diagnostic du signal : indiquer clairement si la PS5 envoie du HDR ou du SDR (cause de l'image délavée observée).
- Tone mapping SDR vers HDR propre quand la console envoie du SDR, avec luminosité de référence réglable.

**F6 — Manette**

- DualSense : haptique, gâchettes adaptatives, gyroscope, pavé tactile, en USB et Bluetooth.
- Mappage clavier/souris en secours.

**F7 — Post-traitement (à la place de ReShade)**

- Étape de shaders intégrée au pipeline, entre l'upscaling et la frame gen : chaque effet n'est appliqué qu'aux images reçues, pas aux images générées.
- ReShade injecté de l'extérieur est écarté : il passerait après la frame gen (coût doublé) et risque d'entrer en conflit avec AFMF et l'overlay.
- Base technique : shaders au format mpv, déjà acceptés par libplacebo dans chiaki-ng.
- Effets fournis : debanding (dégradés du ciel), CAS (netteté AMD), LUT 3D .cube par jeu (compatibles avec les LUT de ReShade ou de DaVinci), saturation et vibrance en HDR.

## Performances et latence

Le traitement complet d'une image source doit tenir en moins de 8 ms de GPU sur la RX 9070 XT, pour que la latence vienne du flux et pas de l'app.

| Étape | Budget cible | Mesure |
| --- | --- | --- |
| Décodage H.265 1080p | ≤ 3 ms | Horodatage Vulkan Video |
| Upscaling FSR 1 vers 4K | ≤ 1 ms | Requêtes de timestamp GPU |
| Upscaling réseau léger vers 4K | ≤ 4 ms | Requêtes de timestamp GPU |
| Frame gen (une image interpolée) | ≤ 4 ms | Requêtes de timestamp GPU |
| Latence ajoutée totale par la frame gen | ≤ 1 image source (33 ms) | Test photo / capteur, comparaison avec et sans |

**Règles d'optimisation**

- Tout reste sur le GPU : aucune copie vers la RAM entre décodage, traitement et affichage.
- Présentation en mode mailbox ou en VRR (FreeSync) pour éviter la file d'attente d'images.
- Pacing piloté par l'horloge des images reçues, pas par l'écran, pour répartir les images générées à intervalle régulier.
- Thread réseau et audio prioritaires, séparés du rendu ; aucune allocation mémoire dans la boucle de rendu.
- Empreinte au repos : < 1 % CPU, aucune activité GPU quand aucune session n'est ouverte.

## Réglages

Chaque réglage affiche en une ligne ce qu'il fait, et un indicateur de coût : image, fluidité, latence, charge GPU. Un bouton « Recommandé » remet la valeur conseillée pour la config détectée.

| Groupe | Réglage | Ce qu'il fait (texte affiché) | Valeur conseillée |
| --- | --- | --- | --- |
| Flux | Images par seconde | Cadence envoyée par la PS5. Régler sur la cadence du jeu évite les images dupliquées. | 30 pour GTA 6 |
| Flux | Bitrate | Qualité du flux. Plus haut = moins de pixels flous, demande un réseau stable. | Maximum en Ethernet |
| Flux | HDR | Demande un flux HDR à la PS5. Ne marche que si la console voit un écran HDR. | Activé |
| Image | Upscaling | Méthode pour passer de 1080p à la résolution de l'écran. | FSR 1 |
| Image | Netteté | Renforce les contours après l'upscaling. Trop haut = halos. | 30 % |
| Image | Lissage des artefacts | Atténue les blocs de compression avant l'upscaling. | Faible |
| Fluidité | Génération d'images | Crée une image intermédiaire entre deux images reçues. Plus fluide, légèrement plus de latence. | Interne x2 |
| Fluidité | Moteur | Interne (optical flow), IA (RIFE, plus propre et plus lourd) ou AFMF (pilote AMD). | Interne |
| Fluidité | Protection du HUD | Évite que la mini-map et les textes tremblent. | Activée |
| Affichage | Synchronisation | VRR = fluide sans déchirure. Mailbox = latence minimale. | VRR |
| Affichage | Mode fenêtre | Plein écran conseillé pour le HDR et AFMF. | Plein écran |
| Affichage | Luminosité SDR | Luminosité d'un flux SDR affiché sur un écran en HDR. | 200 nits |
| Manette | Haptique et gâchettes | Retours de la DualSense comme sur la console. | Activé en USB |

Les réglages techniques (taille de la file d'images, modèle d'IA, décodeur) sont regroupés dans un panneau « Avancé » replié par défaut.

## Interface

Direction : sombre, épurée, pensée pour un écran OLED et une utilisation à la manette, dans l'esprit d'un menu de console plutôt que d'un logiciel de bureau.

**Principes visuels**

- Fond noir profond (adapté OLED), surfaces en verre dépoli légèrement translúcide, une seule couleur d'accent.
- Typographie sans serif moderne (Inter ou équivalent), trois tailles maximum par écran.
- Animations courtes (150 à 250 ms), jamais pendant une session de jeu.
- Navigation complète à la manette, au clavier et à la souris ; mise à l'échelle propre de 1080p à 4K.
- Technologie : Qt Quick (QML), déjà utilisé par chiaki-ng, avec une bibliothèque de composants maison.

**Écrans**

1. **Accueil** : carte de la console (état allumé / repos, bouton réveiller), bouton « Jouer », profil actif.
2. **Réglages** : les groupes du tableau ci-dessus, chaque option avec sa ligne d'explication et son indicateur de coût.
3. **Aperçu avant/après** : image figée coupée en deux, pour comparer l'effet de l'upscaling et de la netteté avant de lancer.
4. **Overlay en jeu** : menu rapide ouvert par une combinaison de touches (activer/désactiver la frame gen, changer de profil, voir les stats).
5. **Diagnostic** : état du HDR reçu, latence réseau, débit, images perdues, avec la cause probable en clair.
6. **Premier lancement** : assistant en 3 étapes (appairage, test réseau, choix d'un profil recommandé).

## Identité visuelle

L'app s'appelle **Farplay** (« jouer loin »). Son motif signature est le triangle Play suivi de deux traînées, qui représentent les images générées par la frame gen.

| Rôle | Couleur | Usage |
| --- | --- | --- |
| Nuit | #0A0A0C | Fond, pensé pour l'OLED |
| Graphite | #17151A | Cartes et panneaux |
| Corail | #FF6B4A | Action principale uniquement, une seule par écran |
| Ivoire | #F5F1EE | Texte |
| Menthe | #5DD39E | États positifs : connecté, HDR reçu |
| Rouge discret | à définir | Alertes |

- **Logo** : triangle plein corail précédé de deux chevrons en opacité décroissante (60 %, 30 %). Icône d'app : le symbole sur un carré arrondi noir.
- **Typographie** : Sora pour l'interface ; JetBrains Mono pour tous les chiffres techniques (latence, débit, fps), pour qu'ils ne bougent pas quand ils changent.
- **Animations** : 150 à 250 ms, léger glissement vers la droite. Au lancement, le triangle avance en laissant ses traînées. Aucune animation pendant une session de jeu.
- **Ton** : textes courts et directs (« PS5 prête », « HDR reçu »), chaque réglage expliqué en une phrase.

## Fonctions en plus

Ces ajouts sont proposés parce qu'ils répondent à des problèmes déjà rencontrés pendant les tests (HDR délavé, bitrate trop bas, réglages flous).

- **Profils par jeu** : GTA 6 à 30 fps avec frame gen x2, un jeu à 60 fps sans frame gen, etc. Bascule automatique selon le jeu lancé si la PS5 l'indique.
- **Overlay de stats** : fps reçus / affichés, temps GPU par étape, débit, latence réseau, images perdues, état HDR. Trois niveaux : masqué, compact, détaillé.
- **Frame gen x3 / x4** : de 30 vers 90 ou 120 fps pour exploiter les 144 Hz du 42C5, avec avertissement sur les artefacts.
- **Éditeur de masque HUD par jeu** : dessiner une fois la zone de la mini-map ou des textes, que la frame gen ne touche plus.
- **Mode A/B** : une touche pour basculer entre l'image brute et l'image traitée, pour régler les effets.
- **Bitrate adaptatif** : baisse automatique si le réseau sature, puis remontée, au lieu d'une image figée.
- **Test réseau intégré** : mesure du débit et de la gigue vers la PS5, puis recommandation du bitrate.
- **Raccourci frame gen** : activer/désactiver en jeu pour comparer instantanément.
- **Gestion de la PS5** : réveil au lancement, mise en repos en fin de session, choix entre plusieurs consoles.
- **Capture d'écran et replay** : capture HDR et replay des 30 dernières secondes, sans impact sur la latence.
- **Lancement direct et Steam** : raccourci qui réveille la PS5 et ouvre la session, entrée dans Big Picture, prise en charge de Steam Input.
- **Mise à jour automatique** via GitHub Releases, avec journal des changements lisible.

## Plan de livraison

Cinq phases, chacune livrable et testable seule ; une phase ne démarre que si la précédente passe son critère d'acceptation.

1. **Phase 0 — Tests préalables**
   - Tester AFMF sur chiaki-ng en plein écran ; valider la chaîne HDR PS5 → Denon → B1.
   - Acceptation : on sait si AFMF fonctionne, et la PS5 envoie bien du HDR.
2. **Phase 1 — Fork et base**
   - Fork de chiaki-ng, build Windows reproductible, overlay de stats, mesure des temps GPU.
   - Acceptation : même qualité et même latence que chiaki-ng d'origine, stats visibles.
3. **Phase 2 — Upscaling et HDR**
   - FSR 1 intégré, diagnostic HDR, tone mapping SDR.
   - Acceptation : 4K net sans artefact ajouté, couleurs correctes en HDR et SDR, ≤ 1 ms GPU.
4. **Phase 3 — Frame generation**
   - Piste A (FidelityFX Optical Flow), puis B (RIFE) si la qualité ne suffit pas ; protection du HUD ; mode AFMF.
   - Acceptation : 60 fps stables sur GTA 6, latence ajoutée ≤ 33 ms, HUD lisible.
5. **Phase 4 — Interface et finitions**
   - Nouvelle interface QML, profils, assistant de premier lancement, réseau de super-résolution, post-traitement (F7), éditeur de masque HUD.
   - Acceptation : toutes les options expliquées, navigation complète à la manette.

## Risques et points ouverts

Le risque principal est la qualité de la frame gen sur une vidéo compressée ; c'est pour ça que AFMF est testé dès la phase 0.

| Risque | Impact | Parade |
| --- | --- | --- |
| Interpolation peu propre (HUD, mouvements rapides) | Image moins bonne que Lossless Scaling | Deux pistes (A et B), protection du HUD, comparaison avec LSFG 3.1 |
| Latence ajoutée trop haute | Visée molle en jeu | Budget de 33 ms mesuré à chaque phase, raccourci pour couper la frame gen |
| La PS5 n'envoie pas de HDR (chaîne Denon) | Image délavée | Diagnostic intégré + réglages Denon/B1 de la phase 0 |
| Sony modifie le protocole Remote Play | Connexion impossible | Suivre les mises à jour de chiaki-ng en amont |
| Charge de maintenance du fork | Retard sur les correctifs | Modules de traitement isolés, fusion régulière avec chiaki-ng |

**Licences**

- chiaki-ng est sous AGPL-3.0 : le fork doit rester open source sous la même licence. Aucun problème pour un usage perso ou un dépôt GitHub public.
- FidelityFX SDK (licence MIT) et ncnn (BSD) sont compatibles. Lossless Scaling est propriétaire et ne peut pas être réutilisé.

**Points ouverts**

- AFMF s'active-t-il sur une app Vulkan comme chiaki-ng ? À vérifier en phase 0.
- Les vecteurs de mouvement H.265 sont-ils accessibles avec le décodage matériel ? Sinon, la piste C est abandonnée.
- Disponibilité du nom Farplay à vérifier (GitHub, marques déposées).
