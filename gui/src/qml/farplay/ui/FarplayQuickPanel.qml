// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — réglages rapides en jeu (ouverts depuis le menu du flux).
// Les changements s'appliquent tout de suite, sans quitter la partie.
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

FpCard {
    id: panel
    signal closeRequested()
    readonly property var s: Farplay.snapshot
    width: 620
    implicitHeight: col.implicitHeight + padding * 2

    function focusFirst() { fgSelect.forceActiveFocus() }

    Keys.onEscapePressed: panel.closeRequested()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Theme.unit * 2

        RowLayout {
            Layout.fillWidth: true
            FpLogo { size: 28 }
            Text {
                Layout.fillWidth: true
                text: "Réglages rapides"
                font.family: Theme.ui
                font.pixelSize: Theme.title * 0.75
                color: Theme.ivory
            }
            Text {
                text: "Échap pour fermer"
                font.family: Theme.ui
                font.pixelSize: Theme.small
                color: Theme.dim
            }
        }

        // Lecture en direct
        Text {
            Layout.fillWidth: true
            text: "%1 → %2 fps · GPU %3 ms · latence +%4 ms"
                .arg((panel.s.fpsIn || 0).toFixed(0))
                .arg(((panel.s.fpsDistinct || 0) > 0 ? panel.s.fpsDistinct : (panel.s.fpsOut || 0)).toFixed(0))
                .arg((panel.s.gpuTotal || 0).toFixed(1))
                .arg((panel.s.fgDelayMs || 0).toFixed(0))
            font.family: Theme.mono
            font.pixelSize: Theme.small
            color: Theme.mint
        }

        FpSettingRow {
            title: "Génération d'images"
            FpSelect {
                id: fgSelect
                model: ["Coupée", "Interne", "AFMF (pilote AMD)"]
                currentIndex: FarplayFrameGen.mode
                onActivated: (i) => FarplayFrameGen.mode = i
                KeyNavigation.down: multSelect
            }
        }
        FpSettingRow {
            title: "Multiplicateur"
            FpSelect {
                id: multSelect
                readonly property var values: [2, 3, 4, 0]
                enabled: FarplayFrameGen.mode === 1
                model: ["x2", "x3", "x4", "Écran"]
                currentIndex: Math.max(0, values.indexOf(FarplayFrameGen.multiplier))
                onActivated: (i) => FarplayFrameGen.multiplier = values[i]
                KeyNavigation.up: fgSelect
                KeyNavigation.down: upSelect
            }
        }
        FpSettingRow {
            title: "Upscaling"
            FpSelect {
                id: upSelect
                model: ["Réglage chiaki-ng", "FSR 1", "FSRCNNX", "libplacebo"]
                currentIndex: FarplayImage.upscaler
                onActivated: (i) => FarplayImage.upscaler = i
                KeyNavigation.up: multSelect
                KeyNavigation.down: sharpSlider
            }
        }
        FpSettingRow {
            title: "Netteté"
            FpSlider {
                id: sharpSlider
                from: 0; to: 100; stepSize: 5
                unit: " %"
                value: FarplayImage.sharpness
                onMoved: (v) => FarplayImage.sharpness = v
                KeyNavigation.up: upSelect
                KeyNavigation.down: pacingSwitch
            }
        }
        FpSettingRow {
            title: "Lissage du pacing"
            FpSwitch {
                id: pacingSwitch
                checked: FarplayFrameGen.pacing
                onToggled: (c) => FarplayFrameGen.pacing = c
                KeyNavigation.up: sharpSlider
                KeyNavigation.down: overlaySelect
            }
        }
        FpSettingRow {
            title: "Overlay de stats"
            FpSelect {
                id: overlaySelect
                model: ["Masqué", "Compact", "Détaillé"]
                currentIndex: Farplay.overlayLevel
                onActivated: (i) => Farplay.overlayLevel = i
                KeyNavigation.up: pacingSwitch
                KeyNavigation.down: closeBtn
            }
        }
        FpButton {
            id: closeBtn
            Layout.alignment: Qt.AlignRight
            text: "Fermer"
            onClicked: panel.closeRequested()
            KeyNavigation.up: overlaySelect
        }
    }
}
