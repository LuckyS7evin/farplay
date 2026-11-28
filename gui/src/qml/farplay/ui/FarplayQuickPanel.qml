// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — réglages rapides en jeu (ouverts depuis la barre du flux).
// Les changements s'appliquent tout de suite, sans quitter la partie.
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

FpGlass {
    id: panel
    signal closeRequested()
    signal quitRequested()
    signal displaySettingsRequested()
    readonly property var s: Farplay.snapshot || ({})
    readonly property real fpsIn: s.fpsIn || 0
    readonly property real fpsShown: (s.fpsDistinct || 0) > 0 ? s.fpsDistinct : (s.fpsOut || 0)

    // Available height (set by the host); 0 = unbounded. The settings grid scrolls when needed.
    property real maxHeight: 0
    readonly property int cols: width < 760 ? 1 : 2
    // Video modes (ChiakiWindow.VideoMode): Normal 0, Stretch 1, Zoom 2
    readonly property int modeNormal: 0
    readonly property int modeStretch: 1
    readonly property int modeZoom: 2
    readonly property var navItems: [fgSwitch, multSeg, engineSeg, fsrMotionSeg, upSeg, sharpSlider, denoiseSeg, debandSeg, overlaySeg, pacingSwitch, volSlider, micSwitch, modeSeg, zoomSlider]

    width: 1040   // integrator may override (e.g. Math.min(1040, window.width - 48))
    implicitHeight: Math.min(col.implicitHeight, maxHeight > 0 ? maxHeight - 56 : col.implicitHeight) + 56
    clip: true
    radius: 28
    fillAlpha: 0.8

    function focusFirst() { fgSwitch.forceActiveFocus() }

    // Grid navigation (up/down by row) over the visible controls; past the end -> footer.
    function nav(item, dir) {
        var vis = navItems.filter(function(x) { return x.visible })
        var i = vis.indexOf(item)
        if (i < 0) return
        var j = i + dir * cols
        if (j < 0) return
        if (j >= vis.length) {
            if (dir > 0) displayBtn.forceActiveFocus()
            return
        }
        vis[j].forceActiveFocus()
    }
    function toFooter() { displayBtn.forceActiveFocus() }

    Keys.onEscapePressed: panel.closeRequested()

    ColumnLayout {
        id: col
        x: 28
        y: 28
        width: parent.width - 56
        spacing: Theme.unit * 2

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: 44
            spacing: 14
            FpLogo { size: 30 }
            Text {
                Layout.fillWidth: true
                text: "Réglages rapides"
                font.family: Theme.ui
                font.pixelSize: Theme.title - 4
                font.weight: Font.DemiBold
                color: Theme.ivory
            }
            // Lecture en direct
            Row {
                spacing: 26
                visible: panel.cols === 2
                Layout.alignment: Qt.AlignVCenter
                Row {
                    spacing: 7
                    Text { id: ro1; text: "%1 → %2".arg(panel.fpsIn.toFixed(0)).arg(panel.fpsShown.toFixed(0)); font.family: Theme.mono; font.pixelSize: Theme.body + 2; color: Theme.ivory }
                    Text { anchors.baseline: ro1.baseline; text: "fps"; font.family: Theme.ui; font.pixelSize: Theme.small; color: Theme.dim }
                }
                Row {
                    spacing: 7
                    Text { id: ro2; text: (panel.s.gpuTotal || 0).toFixed(1); font.family: Theme.mono; font.pixelSize: Theme.body + 2; color: Theme.ivory }
                    Text { anchors.baseline: ro2.baseline; text: "ms GPU"; font.family: Theme.ui; font.pixelSize: Theme.small; color: Theme.dim }
                }
                Row {
                    spacing: 7
                    Text { id: ro3; text: "+" + (panel.s.fgDelayMs || 0).toFixed(0); font.family: Theme.mono; font.pixelSize: Theme.body + 2; color: Theme.ivory }
                    Text { anchors.baseline: ro3.baseline; text: "ms latence"; font.family: Theme.ui; font.pixelSize: Theme.small; color: Theme.dim }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(grid.implicitHeight, panel.maxHeight > 0 ? Math.max(160, panel.maxHeight - 290) : grid.implicitHeight)
            contentWidth: width
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: grid
            width: flick.width
            columns: panel.cols
            columnSpacing: 16
            rowSpacing: 14

            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Génération d'images"
                description: FarplayFrameGen.mode === 0 ? "Coupée"
                    : FarplayFrameGen.mode === 2 ? "AFMF (pilote AMD)"
                    : "Interne · %1 → %2 fps".arg(panel.fpsIn.toFixed(0)).arg(panel.fpsShown.toFixed(0))
                FpSwitch {
                    id: fgSwitch
                    checked: FarplayFrameGen.mode !== 0
                    onToggled: (c) => FarplayFrameGen.mode = c ? 1 : 0
                    Keys.onUpPressed: panel.nav(fgSwitch, -1)
                    Keys.onDownPressed: panel.nav(fgSwitch, 1)
                    KeyNavigation.right: panel.cols === 2 ? multSeg : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Multiplicateur"
                description: "Images ajoutées"
                FpSegmented {
                    id: multSeg
                    readonly property var values: [2, 3, 4, 0]
                    enabled: FarplayFrameGen.mode === 1
                    model: ["x2", "x3", "x4", "Écran"]
                    minSegWidth: 50
                    currentIndex: Math.max(0, values.indexOf(FarplayFrameGen.multiplier))
                    onActivated: (i) => FarplayFrameGen.multiplier = values[i]
                    Keys.onUpPressed: panel.nav(multSeg, -1)
                    Keys.onDownPressed: panel.nav(multSeg, 1)
                    KeyNavigation.left: panel.cols === 2 ? fgSwitch : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Moteur FG"
                description: FarplayFrameGen.engine === 1 ? (FarplayFrameGen.fsrStatus || "AMD FSR") : "Flux optique Farplay"
                FpSegmented {
                    id: engineSeg
                    enabled: FarplayFrameGen.mode === 1
                    model: ["Farplay", "AMD FSR"]
                    minSegWidth: 64
                    currentIndex: FarplayFrameGen.engine
                    onActivated: (i) => FarplayFrameGen.engine = i
                    Keys.onUpPressed: panel.nav(engineSeg, -1)
                    Keys.onDownPressed: panel.nav(engineSeg, 1)
                    KeyNavigation.right: panel.cols === 2 ? fsrMotionSeg : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Mouvement pour FSR"
                description: FarplayFrameGen.fsrDebug === 1 ? "Diagnostic : images générées seules" : "Guide fourni à FSR"
                FpSegmented {
                    id: fsrMotionSeg
                    enabled: FarplayFrameGen.mode === 1 && FarplayFrameGen.engine === 1
                    model: ["Aucun", "Farplay"]
                    minSegWidth: 64
                    currentIndex: FarplayFrameGen.fsrMotion
                    onActivated: (i) => FarplayFrameGen.fsrMotion = i
                    Keys.onUpPressed: panel.nav(fsrMotionSeg, -1)
                    Keys.onDownPressed: panel.nav(fsrMotionSeg, 1)
                    KeyNavigation.left: panel.cols === 2 ? engineSeg : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Upscaling"
                description: "Vers l'écran"
                FpSegmented {
                    id: upSeg
                    model: ["FSR 1", "NIS"]
                    minSegWidth: 50
                    currentIndex: FarplayImage.upscaler - 1
                    onActivated: (i) => FarplayImage.upscaler = i + 1
                    Keys.onUpPressed: panel.nav(upSeg, -1)
                    Keys.onDownPressed: panel.nav(upSeg, 1)
                    KeyNavigation.right: panel.cols === 2 ? sharpSlider : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Netteté"
                description: "Contours après agrandissement"
                FpSlider {
                    id: sharpSlider
                    width: 190
                    valueWidth: 52
                    from: 0; to: 100; stepSize: 5
                    unit: "%"
                    value: FarplayImage.sharpness
                    onMoved: (v) => FarplayImage.sharpness = v
                    Keys.onUpPressed: panel.nav(sharpSlider, -1)
                    Keys.onDownPressed: panel.nav(sharpSlider, 1)
                    KeyNavigation.left: panel.cols === 2 ? upSeg : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Anti-artefacts"
                description: "Blocs et bruit du flux"
                FpSegmented {
                    id: denoiseSeg
                    model: ["Off", "Faible", "Moy.", "Fort"]
                    minSegWidth: 50
                    currentIndex: FarplayImage.denoise
                    onActivated: (i) => FarplayImage.denoise = i
                    Keys.onUpPressed: panel.nav(denoiseSeg, -1)
                    Keys.onDownPressed: panel.nav(denoiseSeg, 1)
                    KeyNavigation.right: panel.cols === 2 ? debandSeg : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Lissage des dégradés"
                description: "Marches de couleur"
                FpSegmented {
                    id: debandSeg
                    model: ["Off", "Faible", "Moyen"]
                    minSegWidth: 50
                    currentIndex: FarplayImage.deband
                    onActivated: (i) => FarplayImage.deband = i
                    Keys.onUpPressed: panel.nav(debandSeg, -1)
                    Keys.onDownPressed: panel.nav(debandSeg, 1)
                    KeyNavigation.left: panel.cols === 2 ? denoiseSeg : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Overlay de stats"
                description: "Infos affichées en jeu"
                FpSegmented {
                    id: overlaySeg
                    model: ["Off", "Min", "Détail"]
                    minSegWidth: 58
                    currentIndex: Farplay.overlayLevel
                    onActivated: (i) => Farplay.overlayLevel = i
                    Keys.onUpPressed: panel.nav(overlaySeg, -1)
                    Keys.onDownPressed: panel.nav(overlaySeg, 1)
                    KeyNavigation.right: panel.cols === 2 ? pacingSwitch : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Lissage du pacing"
                description: "Régularité, un peu de latence"
                FpSwitch {
                    id: pacingSwitch
                    checked: FarplayFrameGen.pacing
                    onToggled: (c) => FarplayFrameGen.pacing = c
                    Keys.onUpPressed: panel.nav(pacingSwitch, -1)
                    Keys.onDownPressed: panel.nav(pacingSwitch, 1)
                    KeyNavigation.left: panel.cols === 2 ? overlaySeg : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Volume"
                description: "Son de la partie"
                FpSlider {
                    id: volSlider
                    width: 190
                    valueWidth: 52
                    from: 0; to: 100; stepSize: 2
                    unit: "%"
                    value: Math.round(Chiaki.settings.audioVolume / 1.28)
                    onMoved: (v) => Chiaki.settings.audioVolume = Math.round(v * 1.28)
                    Keys.onUpPressed: panel.nav(volSlider, -1)
                    Keys.onDownPressed: panel.nav(volSlider, 1)
                    KeyNavigation.right: panel.cols === 2 ? micSwitch : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Micro"
                description: micSwitch.checked ? "Actif" : "Coupé"
                FpSwitch {
                    id: micSwitch
                    enabled: !!Chiaki.session && Chiaki.session.connected
                    checked: !!Chiaki.session && !Chiaki.session.muted
                    onToggled: (c) => { if (Chiaki.session) Chiaki.session.muted = !c }
                    Keys.onUpPressed: panel.nav(micSwitch, -1)
                    Keys.onDownPressed: panel.nav(micSwitch, 1)
                    KeyNavigation.left: panel.cols === 2 ? volSlider : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Mode vidéo"
                description: "Cadrage de l'image"
                FpSegmented {
                    id: modeSeg
                    model: ["Normal", "Zoom", "Étirer"]
                    minSegWidth: 58
                    currentIndex: Chiaki.window.videoMode === panel.modeZoom ? 1 : Chiaki.window.videoMode === panel.modeStretch ? 2 : 0
                    onActivated: (i) => Chiaki.window.videoMode = (i === 1 ? panel.modeZoom : i === 2 ? panel.modeStretch : panel.modeNormal)
                    Keys.onUpPressed: panel.nav(modeSeg, -1)
                    Keys.onDownPressed: panel.nav(modeSeg, 1)
                    KeyNavigation.right: zoomSlider.visible ? zoomSlider : null
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                visible: Chiaki.window.videoMode === panel.modeZoom
                title: "Facteur de zoom"
                description: zoomSlider.value <= -1 ? "Sans bandes noires" : "Agrandissement de l'image"
                FpSlider {
                    id: zoomSlider
                    width: 190
                    valueWidth: 60
                    from: -1; to: 4; stepSize: 0.05
                    unit: ""
                    value: Chiaki.window.ZoomFactor
                    onMoved: (v) => { Chiaki.window.ZoomFactor = v; Chiaki.settings.sZoomFactor = v }
                    Keys.onUpPressed: panel.nav(zoomSlider, -1)
                    Keys.onDownPressed: panel.nav(zoomSlider, 1)
                    KeyNavigation.left: modeSeg
                }
            }
        }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.topMargin: 2
            spacing: 14
            FpButton {
                id: displayBtn
                text: "Réglages d'affichage"
                iconName: "display"
                onClicked: panel.displaySettingsRequested()
                Keys.onUpPressed: { var v = panel.navItems.filter(function(x) { return x.visible }); v[v.length - 1].forceActiveFocus() }
                KeyNavigation.right: quitBtn
            }
            FpButton {
                id: quitBtn
                text: "Quitter la partie"
                iconName: "power"
                danger: true
                onClicked: panel.quitRequested()
                Keys.onUpPressed: { var v = panel.navItems.filter(function(x) { return x.visible }); v[v.length - 1].forceActiveFocus() }
                KeyNavigation.left: displayBtn
            }
            Item { Layout.fillWidth: true }
            FpHints {
                visible: panel.cols === 2
                model: [["✕", "Modifier"], ["○", "Fermer"]]
            }
        }
    }
}
