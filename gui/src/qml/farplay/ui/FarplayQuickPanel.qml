// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — réglages rapides en jeu (ouverts depuis la barre du flux).
// Les changements s'appliquent tout de suite, sans quitter la partie.
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

FpGlass {
    id: panel
    signal closeRequested()
    readonly property var s: Farplay.snapshot || ({})
    readonly property real fpsIn: s.fpsIn || 0
    readonly property real fpsShown: (s.fpsDistinct || 0) > 0 ? s.fpsDistinct : (s.fpsOut || 0)

    width: 1040   // integrator may override (e.g. Math.min(1040, window.width - 48))
    implicitHeight: col.implicitHeight + 56
    radius: 28
    fillAlpha: 0.8

    function focusFirst() { fgSwitch.forceActiveFocus() }

    Keys.onEscapePressed: panel.closeRequested()

    ColumnLayout {
        id: col
        x: 28
        y: 28
        width: parent.width - 56
        spacing: Theme.unit * 2

        RowLayout {
            Layout.fillWidth: true
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

        GridLayout {
            Layout.fillWidth: true
            columns: 2
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
                    KeyNavigation.down: upSeg
                    KeyNavigation.right: multSeg
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
                    KeyNavigation.down: sharpSlider
                    KeyNavigation.left: fgSwitch
                }
            }
            FpSettingRow {
                boxed: true
                Layout.preferredHeight: 84
                title: "Upscaling"
                description: "Vers l'écran"
                FpSegmented {
                    id: upSeg
                    model: ["FSR 1", "FSRCNNX", "libplacebo"]
                    minSegWidth: 50
                    currentIndex: FarplayImage.upscaler - 1
                    onActivated: (i) => FarplayImage.upscaler = i + 1
                    KeyNavigation.up: fgSwitch
                    KeyNavigation.down: overlaySeg
                    KeyNavigation.right: sharpSlider
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
                    KeyNavigation.up: multSeg
                    KeyNavigation.down: pacingSwitch
                    KeyNavigation.left: upSeg
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
                    KeyNavigation.up: upSeg
                    KeyNavigation.right: pacingSwitch
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
                    KeyNavigation.up: sharpSlider
                    KeyNavigation.left: overlaySeg
                }
            }
        }

        FpHints {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            model: [["✕", "Modifier"], ["○", "Fermer"]]
        }
    }
}
