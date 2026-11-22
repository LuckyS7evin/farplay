# Farplay — Journal de progression

Source de vérité : `docs/cahier-des-charges.md`. Ce journal remplace la ré-exploration du dépôt.

## État
- Phase 0 : manuelle (utilisateur) — résultats AFMF / HDR en attente.
- Phase 1 : testée par l'utilisateur (build 960422d7) — OK, en attente du feu vert phase 2.
  - Vulkan Video zero-copy ✔, HDR10 PQ BT.2020 reçu ✔, GPU rendu source ~1,9 ms (p99 ~2,9) ✔, ressenti identique à chiaki-ng (latence non mesurée).
  - Immediate : affichage régulier (p99 35 ms) ; irrégularités venant du flux (p99 intervalle source 45–70 ms).
  - Mailbox : trous d'affichage 50–108 ms alors que le flux est régulier (p99 ~36 ms) → mailbox jette des images à 30 fps. Laisser FIFO/VRR par défaut ; traiter avec le pacing en phase 3.
  - Débit mesuré bas (médiane 8–19 Mbps) → vérifier le réglage de bitrate.
  - fps affichés parfois > fps reçus (+0,5–1) : rendus supplémentaires dus aux mises à jour QML de l'overlay (2 Hz).

## Décisions
- 2026-11-21 : base = chiaki-ng 1.9.9 (streetpea/chiaki-ng, branche `main`), remote `upstream`.
- Dépôt `farplay` vide au départ : la branche de travail sera construite sur l'historique upstream (pas de racine indépendante) pour garder des fusions simples.
- Build Windows : partir du workflow MSVC/vcpkg upstream (`build-windows-x86.yml`) plutôt que MSYS2.

- Fork : `git merge --allow-unrelated-histories upstream/main` (le commit docs initial reste la racine ; les fusions upstream futures marchent normalement).
- Workflows upstream supprimés sauf `farplay-windows.yml` (+ dependabot). Vulkan SDK épinglé 1.4.363.1, SPIRV-Cross `vulkan-sdk-1.4.363.0`. Qt épinglé 6.10.3 (aqtinstall ne gère pas le dépôt Qt 6.11+). shaderc pris dans le Vulkan SDK (.pc généré). Reste flottant : FFmpeg (`streetpea/FFmpeg-Builds` latest) → bumper `cache_rev` si besoin.
- Exe Windows renommé `farplay.exe` (OUTPUT_NAME) ; nom d'app Qt / dossier de réglages inchangés (« Chiaki ») pour garder les profils existants. Titre = « Farplay <hash> ».
- Temps GPU : via `pl_render_params.info_callback` (libplacebo mesure chaque passe par timestamps Vulkan, lecture asynchrone). Étapes : FRAME (traitement image source), BLEND (composition par image affichée). Décodage GPU non mesuré (FFmpeg possède la file Vulkan Video) → phase 2.
- Overlay en QML (pas le widget natif upstream, fenêtre tooltip au-dessus du plein écran = risque pour flip/AFMF). Snapshot à 2 Hz : chaque changement QML déclenche un rendu Qt Quick → mesurer la latence overlay masqué (CSV seul).
- Mailbox : option expérimentale (repli FIFO si non supporté, signalé dans l'overlay). FIFO par défaut.
- Réglages Farplay stockés à part : QSettings("Farplay","Farplay") (overlay/level, present/mailbox).
- Rouge d'alerte choisi : #E5484D.

- CI : premier build complet ~60 min (vcpkg sans cache) ; caches restore/save séparés pour les suivants. PR dependabot #1 (actions/cache v6) en échec, non traitée.

## Phase 2 (en cours)
- chiaki-ng embarque déjà FSR 1 (`gui/res/shaders/FSR.glsl`, mpv, EASU+RCAS sur LUMA) et FSRCNNX x2 8/16 → réutilisés.
- `farplay::Image` (`gui/{include,src}/farplay/farplayimage.*`, QML `FarplayImage`) : upscaler {0 chiaki, 1 FSR 1 défaut, 2 FSRCNNX, 3 libplacebo}, netteté % (stops = 2×(1−%), 30 % ⇒ 1,4 stop ; chiaki utilisait 0,2 stop), variante FSR_PQ=1 pour les flux PQ, lissage des dégradés (deband libplacebo faible/moyen ; vrai deblocking non fait : le H.265 a déjà un filtre in-loop), SDR sur écran HDR (hint swapchain PQ/BT.2020 + `hdr.max_luma` = luminosité SDR sur les images SDR).
- Copie Farplay du shader : `gui/res/farplay/shaders/FSR.glsl` (`//!PARAM farplay_sharpness`, DESC « Farplay FSR1 … » pour le classement des temps GPU).
- Stats : temps GPU upscaling (passes FSR/FSRCNNX par description de shader), sortie écran (transfert/primaires de la swapchain), pic source, diagnostic HDR en clair, débit demandé / cible PS5 (`farplay_target_bitrate` ajouté dans `ChiakiStreamConnection`, unité supposée kbps à confirmer).
- Overlay : mises à jour QML rendues avec la prochaine image vidéo pendant un flux (plus de présentation en plus).
- Non fait : temps GPU du décodage (FFmpeg possède la file Vulkan Video).
- Test 1 (build 032006e3) : FSR 1 jamais actif — un commentaire contenant « //! » dans le shader le faisait rejeter par libplacebo (repli silencieux). Corrigé, vérifié localement (libplacebo 6.338 + GPU factice : scratchpad/pltest). Règle : jamais « //! » hors directives dans un shader mpv.
- Mesures : rendu source libplacebo ≈ 1,7–1,9 ms ; FSRCNNX ≈ 3,5 ms dont 1,5 ms d'upscaling (budget réseau 4 ms). Cible PS5 en bit/s : 97 Mbps pour 100 demandés, débit réel 9–11 Mbps médian (pics 45) → l'encodeur VBR de la PS5 n'a pas besoin de plus, le réglage n'est pas le facteur limitant. Pics d'affichage 130–177 ms = arrêts du flux (rafale d'images juste après).

- Test 2 (build 884627af) : FSR 1 actif, upscaling 0,42–0,56 ms (p99 0,78) ✔ budget 1 ms ; rendu source total 2,3–3,8 ms ✔ 8 ms ; HDR de bout en bout ✔ ; cible PS5 confirmée 92–97 Mbps pour 100 demandés (réel 3–8 Mbps sur scène calme). Test SDR→HDR abandonné à la demande de l'utilisateur (non validé).
- Phase 2 close : netteté par défaut 70 % (choix utilisateur, le cahier des charges disait 30 %).
- Phase 0 (utilisateur) : AFMF fonctionne sur chiaki-ng mais qualité jugée moyenne, Lossless Scaling préféré → frame gen interne prioritaire, AFMF = option de dernier recours.
- Saccades signalées dans les 3 modes : 30 fps sur écran 144 Hz en FIFO = cadence 4/5 rafraîchissements (27,8/34,7 ms, cf. p99 affichage ≈ 35 ms) + retards ponctuels du flux (p99 source 45–67 ms). Pistes : 120 Hz ou VRR, pacing phase 3.

## Phase 3 (en cours) — frame generation
- Décision : piste A implémentée avec un optical flow maison (même principe que FidelityFX OF : pyramide de luminance + appariement de blocs multi-échelle) plutôt que le SDK FidelityFX : l'API ffx du SDK n'expose pas l'optical flow seul (seulement la frame gen FSR3 qui exige vecteurs de mouvement et profondeur du jeu), et porter ses shaders HLSL serait lourd. Tout est en shaders libplacebo (pl_dispatch), sans dépendance nouvelle, testable sur Vulkan logiciel.
- `farplay::FgEngine` (`fgengine.*`, sans Qt) : 3 slots RGBA16F (images reçues déjà rendues : FSR, deband, HDR), pyramide luma (L0 = 1/4, 5 niveaux), flux A→B grossier→fin (SAD 5×5, rayon 4 puis 2, prédicteurs voisins + flux de la paire précédente, biais immobile, sous-pixel parabolique), médiane vectorielle, synthèse à la phase t (sélection du vecteur par pixel parmi 6 candidats, repli occlusion vers l'image la plus proche, pixels fixes recopiés = protection HUD).
- `farplay::FrameGen` (`farplayframegen.*`, QML `FarplayFrameGen`) : mode {coupée, interne (défaut), AFMF}, multiplicateur {x2 défaut, x3, x4, écran}, protection HUD, F4 = suspendre. Force le frame mixer (rendu à la cadence écran), retarde l'horloge pl_queue d'une image source + 3 ms (latence ajoutée affichée), file ≥ 3 images. Incompatible avec « Direct Frame Mapping » (signalé).
- Banc de test : `gui/src/farplay/tests/fg_test.cpp` + workflow `farplay-fgtest.yml` (lavapipe). Résultats 1280×720 : gain +8 à +11 dB sur le fondu (4 à 120 px/image), HUD intact (73 dB). Limite connue : fine bande autour d'un HUD fixe sur fond mobile (zones découvertes).

## Phase 4 (partie interface, avant le test de la phase 3)
- Accord utilisateur : interface/profils/assistant/diagnostic d'abord ; F7, éditeur de masque HUD, réseau SR après le test de la phase 3.
- QML écrit par un sous-agent (Sonnet) puis relu : `gui/src/qml/farplay/ui/` (qmldir, Theme, FarplayProfiles, composants Fp*, écrans FarplayHome/Settings/Diagnostic/Wizard), enregistré dans `farplay.qrc` (préfixe /farplay/ui). Correctif de relecture : fps PS5 = valeurs 30/60 (pas 0/1).
- Main.qml : vue principale = accueil Farplay (assistant au premier lancement, drapeau QSettings ui/wizard_done), vue chiaki-ng d'origine accessible (`root.showChiakiMainView()`), `root.showFarplayView(url)`.
- Identité : police Sora (OFL) + JetBrains Mono, icône `res/farplay/icons/farplay.{svg,ico}`, métadonnées exe Farplay, icône de fenêtre.
- Test réseau intégré non fait (aucune base dans chiaki-ng) : l'assistant renvoie à la mesure pendant la première partie (overlay/diagnostic).

## Après PushFPS (en attente de build, quota Actions)
- Analyse de PushFPS (GPL-3.0, chiaki-ng + RIFE 4.25/4.26 via ONNX DirectML, FSR 4.1 FG avec mouvement estimé → ghosting reconnu). Idées reprises (réimplémentées, pas de code copié) :
  1. Lissage du pacing (`FrameGen::pacing`, défaut activé) : horloge des images ajustée sur les arrivées (indice arrondi + régression linéaire, absorbe dérive et pertes), marge = 95e centile du retard + 2 ms, plafonnée à 12 ms avec frame gen / 25 ms seul ; sans frame gen, présentation de l'image courante à l'heure prévue via le même chemin (slot A, sans interpolation).
  2. Son retardé du même délai que l'image : `StreamSession::DrainAudioOutRingBuffer` retient `audioDelayMs` dans l'anneau (agrandi à ≥ 250 ms) et jette l'excédent quand le retard baisse.
  3. 1 % low des images affichées dans l'overlay et le CSV.
- CI Windows en lancement manuel (quota de minutes : ~150 min par build sans cache, Windows ×2). Cache vcpkg : clé bin4, chemin relatif, à vérifier au prochain build.

## Test frame gen (build 00fbb4df, 22/11)
- Frame gen indisponible : chiaki-ng a « Frame Delivery = Direct Mapping » par défaut (settings/direct_frame_mapping = true) → corrigé (mode direct ignoré quand frame gen/lissage actifs). Contournement utilisateur : « Frame Queue ».
- Avec Frame Queue : fluide, FG ≈ 2,4 ms GPU (flux 1,5, synthèse 0,5), 120 Hz. Décrochage après ~60 s (« attente de l'image suivante » permanent) : horloge d'affichage calée sur ts_start de chiaki → la dérive PS5/PC finit par dépasser la marge de 3 ms. Corrigé : horloge d'affichage = pts + décalage d'arrivée minimal sur 8 s (`FrameGen::displayPts`), marge = 95e centile.
- « 120 fps » en x2 à 120 Hz = chaque image présentée deux fois : compteur d'images distinctes ajouté (`fpsDistinct`), et plus de synthèse redondante pour une image répétée.
- Comparaison PushFPS (réglages utilisateur) : SMAA + NIS + « NR » IA 9,4 ms + FSR 4 FG via pilote + flux optique FidelityFX ; son retardé de 92 ms (latence nettement plus haute que Farplay ≈ 36 ms). Image jugée « pas très propre » sur Farplay : à préciser (FG vs upscaling/compression).

## Fichiers Farplay
- `gui/src/farplay/farplay.cmake` : sources, qrc, FARPLAY_GIT_HASH, OUTPUT_NAME.
- `gui/{include,src}/farplay/farplaystats.*` : `farplay::Stats` (singleton QML `Farplay`, compteurs, timings GPU, CSV `Documents/Farplay/stats-*.csv`).
- `gui/src/qml/farplay/StatsOverlay.qml` (+ `gui/res/farplay/farplay.qrc`, police JetBrains Mono OFL).
- Points d'appel upstream (marqués `FARPLAY:`) : qmlmainwindow.cpp (presentFrame, logSwapInterval, info_callback, present mode, F3), qmlbackend.cpp (registerQml), streamsession.h (GetRttUs), main.cpp (titre), StreamView.qml (Loader + bouton Stats), SettingsDialog.qml (Mailbox, CSV), gui/CMakeLists.txt (include).

## Cartographie chiaki-ng (chemins relatifs à la racine upstream)
**Décodage**
- `lib/src/ffmpegdecoder.c` L29-101 : décodeur FFmpeg, choix hwaccel (`av_hwdevice_find_type_by_name`, `hw_device_ctx`), repli logiciel.
- Choix du décodeur : `gui/src/qmlsettings.cpp` (~L40, ~L1700). Device Vulkan partagé avec FFmpeg : `gui/src/qmlmainwindow.cpp` ~L4719 (`AV_HWDEVICE_TYPE_VULKAN`).
- Remise au rendu : `QmlMainWindow::presentFrame` (qmlmainwindow.cpp L3006) → `pl_queue_push` → `pl_map_avframe_ex` (L2212).

**Rendu (tout dans `gui/src/qmlmainwindow.cpp`, ~7 600 lignes)**
- Init Vulkan L4835, `pl_vulkan_create` L5036 (repli OpenGL), `pl_renderer_create` L5113, `pl_queue_create` L5118.
- `render()` L6453 ; `pl_render_image(_mix)` L7481 / L7618 ; HDR : `pl_swapchain_colorspace_hint` L7339.
- Réglages libplacebo : `gui/include/settings.h` (enums Placebo L62-190), QML `PlaceboSettingsDialog.qml`, `PlaceboColorMappingDialog.qml`.

**Présentation / pacing**
- `createSwapchain()` L5913 ; present mode L6027 : FIFO (VSync) ou IMMEDIATE — MAILBOX jamais choisi.
- `pl_swapchain_start_frame` L6994, submit L7151, `swap_buffers` L7216.
- Threads : `DeferredPresentPacerThread` L295, `BufferedPlaybackPacerThread` L388, `DeferredSwapThread` L497 ; `setStreamMaxFPS` L3439.
- Stats latence/présentation existantes : logs seulement (L745-1129).

**Interface QML** — `gui/src/qml/` (Main, MainView, SettingsDialog, StreamView, StreamMenuWindow, controls/).
- Stats à l'écran actuelles : `StreamView.qml` L20, L307-442 (perte paquets, images perdues) ; données dans `gui/src/streamsession.cpp`, `qmlbackend.cpp`.
- Branding : `gui/chiaking.*`, `gui/chiaki4deck.*`, `gui/res/chiaking.svg`, `assets/`, nom d'app `gui/src/main.cpp` L76-77.

**Réglages** — `gui/include/settings.h` L196 (`Settings`, QSettings, profils), `gui/src/settings.cpp`.

**Build Windows** — `vcpkg.json` ; `.github/workflows/build-windows-x86.yml` (windows-latest, lukka/run-vcpkg, Vulkan SDK, FFmpeg partagé, libplacebo v7.387.0 compilé) ; scripts `scripts/build-*-windows.sh`, installeur `scripts/chiaki-ng.iss`.

## Points à vérifier
- Vulkan Video : aucun `get_format`/D3D11VA dans le code ; confirmer que le hwdec « vulkan » de FFmpeg est bien utilisé et zero-copy via `pl_map_avframe_ex`.

## Reste à faire
- Phase 1 : build CI vert, retours de test utilisateur (CSV, capture overlay, latence vs chiaki-ng).
- Phase 2 : timestamps décodage Vulkan Video, FSR 1, diagnostic HDR, tone mapping SDR.
- Raccourci manette dédié pour l'overlay (aujourd'hui : bouton dans le menu de flux).

### Nouvelle interface (mix A/B validé)
- Accueil « Console » (A), Réglages en barre latérale + réglages rapides en verre (B), sliders fins, pastilles segmentées, 80 icônes SVG.
- Barre du haut en jeu (`FarplayStreamBar`) : apparaît quand la souris approche du haut (capture dans `QmlMainWindow::event`) ; réglages rapides, son, plein écran (`fullscreenTime`/`normalTime` rendus `Q_INVOKABLE`), quitter.
- Panneau de réglages rapides centré, largeur `min(1040, fenêtre − 48)`.
- Popup de fin de session supprimée (migration `disconnectAction 2→0`), défilement corrigé en fenêtré.
- À tester sur le build suivant (un seul build manuel).

### Réduction d'artefacts + plus aucun écran chiaki (non buildé)
- `Deartifact.glsl` : NLM luma (recherche 5x5, patch 3x3, tuile partagée) avant FSR 1 ; niveaux Off/Faible/Moyen(défaut)/Fort ; test lavapipe `deartifact_test` (+3 à +6 dB, bords HUD intacts) dans le workflow Linux ; temps GPU dans l'overlay et le CSV (`gpu_denoise_avg_ms`).
- Tous les écrans chiaki remplacés : enregistrement, ajout de console, PIN, PSN, dialogues, mapping manette, réglages complets (sections Consoles, Manette & son, Réseau…), menu en jeu (bouton PS → réglages rapides Farplay + barre), chargement/erreur, fin de session, PIN de session.
- Accueil : « Jouer » sous les profils ; interrupteurs 36×18 et sliders 2 px.

### Test du build c3cdd637 → corrections
- FG quasi inactive (« attente de l'image suivante » 97 % du temps) depuis l'ajout du lissage : avec la présentation retardée, la file dépassait la limite de profondeur (3) et chiaki mettait l'image suivante B de côté. Limite portée à 5 (FG) / 3 (lissage). Base de l'horloge d'affichage : 5e centile des décalages arrivée−pts au lieu du minimum (une image en avance faisait viser des images non arrivées ; marge 44–60 ms observée).
- Overlay : cadence affichée = images distinctes (jamais la fréquence écran), % de vsyncs en attente (`fg_wait_pct` dans le CSV).
- Netteté recommandée 50 % (avec l'anti-artefacts). Anti-artefacts mesuré à 0,17 ms sur 9070 XT.
- Nouveau : `ChromaFromLuma.glsl` (chroma 4:2:0 reconstruite par régression locale sur la luminance, bornée) : +2 à +3 dB sur bords colorés (test `chroma_test`, sites centre/gauche). Réglage « Couleurs nettes », actif par défaut.
- HDR : le flux H.265 HDR est en PQ même console en SDR ; le diagnostic décrit le signal, pas le contenu.
