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
