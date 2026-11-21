# Farplay — Journal de progression

Source de vérité : `docs/cahier-des-charges.md`. Ce journal remplace la ré-exploration du dépôt.

## État
- Phase 0 : manuelle (utilisateur) — résultats AFMF / HDR en attente.
- Phase 1 : plan proposé, en attente de validation.

## Décisions
- 2026-11-21 : base = chiaki-ng 1.9.9 (streetpea/chiaki-ng, branche `main`), remote `upstream`.
- Dépôt `farplay` vide au départ : la branche de travail sera construite sur l'historique upstream (pas de racine indépendante) pour garder des fusions simples.
- Build Windows : partir du workflow MSVC/vcpkg upstream (`build-windows-x86.yml`) plutôt que MSYS2.

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
- Validation du plan de phase 1.
