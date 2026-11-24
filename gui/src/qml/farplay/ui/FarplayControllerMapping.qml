// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.streetpea.chiaking

// Physical controller to DualSense button mapping, in the Farplay style. Same backend flow
// as chiaki-ng's Settings > Controllers + ControllerMappingDialog: beginControllerMapping,
// wait for a button press to pick the controller, then edit (updateButton / apply) or reset.
FpPage {
    id: page
    property bool reset: false
    property string phase: "choose"          // "choose" | "edit" | "steam" | "done"
    property bool captureOpen: false
    property int captureValue: 0
    property int captureIndex: 0             // 0 or 1: which of the two physical buttons
    property int captureRow: 0
    property bool quitButtonMapping: true
    property bool finalClosing: false

    columnWidth: phase === "edit" ? 1100 : 760
    title: reset ? "Réinitialiser le mapping" : "Mapping de la manette"
    subtitle: phase === "edit" ? Chiaki.currentControllerType : "Associe les boutons de votre manette à ceux d'une DualSense."
    hints: captureOpen ? [["○", "Annuler"]] : [["✕", "Valider"], ["○", "Retour"]]
    onBack: {
        if (captureOpen) closeCapture()
        else root.closeDialog()
    }

    function closeCapture() {
        captureOpen = false
        if (quitButtonMapping) Chiaki.controllerMappingButtonQuit()
        else quitButtonMapping = true
        var it = rows.itemAt(captureRow)
        if (it) (captureIndex === 0 ? it.b0 : it.b1).forceActiveFocus()
    }
    function openCapture(value, btnIndex, row) {
        captureValue = value
        captureIndex = btnIndex
        captureRow = row
        captureOpen = true
        Chiaki.controllerMappingSelectButton()
    }

    Component.onCompleted: {
        Chiaki.beginControllerMapping(reset)
        backButton.forceActiveFocus()
    }
    Component.onDestruction: {
        if (finalClosing) return
        if (Chiaki.controllerMappingInProgress) {
            finalClosing = true
            Chiaki.controllerMappingButtonQuit()
            Chiaki.controllerMappingQuit()
        } else if (phase === "choose") {
            Chiaki.controllerMappingQuit()
        }
    }

    Timer {
        id: pickTimer
        interval: 100
        onTriggered: {
            if (page.reset) {
                if (!Chiaki.controllerMappingDefaultMapping) Chiaki.controllerMappingReset()
                else Chiaki.controllerMappingQuit()
                page.phase = "done"
                doneTimer.start()
            } else {
                page.phase = "edit"
                Qt.callLater(function() { analogSwitch.forceActiveFocus() })
            }
        }
    }
    Timer { id: doneTimer; interval: 1400; onTriggered: root.closeDialog() }

    Connections {
        target: Chiaki
        function onControllerMappingInProgressChanged() {
            if (Chiaki.controllerMappingInProgress) {
                if (page.phase === "choose") pickTimer.start()
            } else if (page.phase === "edit" && !page.finalClosing) {
                root.closeDialog()
            }
        }
        function onControllerMappingSteamControllerSelected() {
            pickTimer.stop()
            page.phase = "steam"
            steamBtn.forceActiveFocus()
        }
        function onControllerMappingButtonSelected(pressedButton, chiakiButtonValue, chiakiButtonName) {
            Chiaki.updateButton(page.captureValue, pressedButton, page.captureIndex)
            page.quitButtonMapping = false
            page.closeCapture()
        }
    }

    // ── Choose controller ──────────────────────────────────────────────────
    FpGlass {
        Layout.fillWidth: true
        visible: page.phase === "choose" || page.phase === "done" || page.phase === "steam"
        implicitHeight: msgCol.implicitHeight + Theme.unit * 8
        radius: 24
        fillAlpha: 0.7
        ColumnLayout {
            id: msgCol
            anchors.centerIn: parent
            width: parent.width - Theme.unit * 8
            spacing: Theme.unit * 2
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: page.phase === "choose" ? "Choisissez la manette en appuyant sur un de ses boutons"
                    : page.phase === "done" ? "Mapping réinitialisé"
                    : "Cette manette est gérée par Steam"
                font.family: Theme.ui
                font.pixelSize: Theme.title - 4
                font.weight: Font.DemiBold
                color: page.phase === "done" ? Theme.mint : Theme.ivory
            }
            Text {
                Layout.fillWidth: true
                visible: page.phase !== "done"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: page.phase === "steam" ? "Utilisez Steam pour mapper la manette, ou désactivez Steam Input pour cette manette avant de la mapper ici."
                                             : (page.reset ? "Le mapping de cette manette reprendra ses valeurs d'origine." : "Vous pourrez ensuite choisir quel bouton physique déclenche chaque bouton de la DualSense.")
                font.family: Theme.ui
                font.pixelSize: Theme.body - 1
                color: Theme.dim
            }
            FpButton {
                id: steamBtn
                Layout.alignment: Qt.AlignHCenter
                visible: page.phase === "steam"
                text: "Fermer"
                onClicked: root.closeDialog()
            }
        }
    }

    // ── Edit mapping ───────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        visible: page.phase === "edit"
        spacing: Theme.unit * 3
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.unit * 2
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: "Sticks analogiques et L2/R2"
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                    font.weight: Font.Medium
                    color: Theme.ivory
                }
                Text {
                    text: "Autorise l'association des sticks et des gâchettes."
                    font.family: Theme.ui
                    font.pixelSize: Theme.small - 1
                    color: Theme.dim
                }
            }
            FpSwitch {
                id: analogSwitch
                checked: Chiaki.enableAnalogStickMapping
                onToggled: (c) => Chiaki.enableAnalogStickMapping = c
            }
        }

        FpGlass {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight + Theme.unit * 4
            radius: 24
            fillAlpha: 0.7
            GridLayout {
                id: grid
                x: Theme.unit * 2
                y: Theme.unit * 2
                width: parent.width - Theme.unit * 4
                columns: 2
                columnSpacing: Theme.unit * 4
                rowSpacing: Theme.unit
                Repeater {
                    id: rows
                    model: Chiaki.currentControllerMapping
                    delegate: RowLayout {
                        id: row
                        required property var modelData
                        required property int index
                        property alias b0: b0
                        property alias b1: b1
                        Layout.fillWidth: true
                        spacing: Theme.unit * 2
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.buttonName
                            elide: Text.ElideRight
                            font.family: Theme.ui
                            font.pixelSize: Theme.body - 1
                            color: Theme.ivory
                        }
                        FpButton {
                            id: b0
                            Layout.preferredWidth: 130
                            fontSize: Theme.small + 1
                            text: row.modelData.physicalButton.length > 0 ? row.modelData.physicalButton[0] : "—"
                            onClicked: page.openCapture(row.modelData.buttonValue, 0, row.index)
                        }
                        FpButton {
                            id: b1
                            Layout.preferredWidth: 130
                            fontSize: Theme.small + 1
                            text: row.modelData.physicalButton.length > 1 ? row.modelData.physicalButton[1] : "—"
                            onClicked: page.openCapture(row.modelData.buttonValue, 1, row.index)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.unit * 2
            Item { Layout.fillWidth: true }
            FpButton {
                text: "Annuler"
                onClicked: root.closeDialog()
            }
            FpButton {
                primary: true
                implicitHeight: 52
                iconName: "check"
                text: "Appliquer"
                enabled: Chiaki.controllerMappingAltered
                onClicked: { Chiaki.controllerMappingApply(); Chiaki.controllerMappingQuit() }
            }
        }
    }

    // ── Button capture ─────────────────────────────────────────────────────
    Item {
        parent: page
        anchors.fill: parent
        visible: page.captureOpen
        z: 20
        Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0.02, 0.03, 0.8); MouseArea { anchors.fill: parent } }
        FpGlass {
            anchors.centerIn: parent
            width: Math.min(parent.width - Theme.unit * 8, 620)
            height: capCol.implicitHeight + Theme.unit * 8
            radius: 28
            fillAlpha: 0.95
            ColumnLayout {
                id: capCol
                anchors.fill: parent
                anchors.margins: Theme.unit * 4
                spacing: Theme.unit * 2
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Appuyez sur un bouton de la manette"
                    font.family: Theme.ui
                    font.pixelSize: Theme.title - 4
                    font.weight: Font.DemiBold
                    color: Theme.ivory
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Le bouton choisi remplacera celui de la DualSense. Échap ou ○ pour annuler."
                    font.family: Theme.ui
                    font.pixelSize: Theme.body - 1
                    color: Theme.dim
                }
                FpButton {
                    Layout.alignment: Qt.AlignRight
                    text: "Annuler"
                    onClicked: page.closeCapture()
                }
            }
        }
    }
}
