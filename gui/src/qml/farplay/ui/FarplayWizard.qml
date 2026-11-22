// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

FocusScope {
    id: page
    anchors.fill: parent
    signal finished()

    property int step: 0
    readonly property var hosts: Chiaki.hosts || []
    readonly property bool anyRegistered: hosts.some(function(h) { return h.registered })
    readonly property var titles: ["Appairage", "Réseau", "Profil"]

    function done() { finished(); root.farplayWizardDone() }
    function next() { if (step < 2) step++; else done() }
    onStepChanged: nextBtn.forceActiveFocus()

    Keys.onEscapePressed: done()
    Keys.onUpPressed: { var i = nextItemInFocusChain(false); if (i) i.forceActiveFocus() }
    Keys.onLeftPressed: { var i = nextItemInFocusChain(false); if (i) i.forceActiveFocus() }
    Keys.onDownPressed: { var i = nextItemInFocusChain(true); if (i) i.forceActiveFocus() }
    Keys.onRightPressed: { var i = nextItemInFocusChain(true); if (i) i.forceActiveFocus() }
    Component.onCompleted: nextBtn.forceActiveFocus()

    component Body: Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.family: Theme.ui
        font.pixelSize: Theme.body
        color: Theme.ivory
    }

    Rectangle { anchors.fill: parent; color: Theme.night }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.unit * 10, 800)
        spacing: Theme.unit * 3

        RowLayout {
            spacing: Theme.unit * 2
            FpLogo { size: 40 }
            Text {
                Layout.fillWidth: true
                text: page.titles[page.step]
                font.family: Theme.ui
                font.pixelSize: Theme.title
                color: Theme.ivory
            }
            Row {
                spacing: Theme.unit
                Repeater {
                    model: 3
                    delegate: Text {
                        required property int index
                        text: index + 1
                        font.family: Theme.mono
                        font.pixelSize: Theme.body
                        color: index === page.step ? Theme.ivory : Theme.dim
                        font.bold: index === page.step
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: page.step

            // 1. Pairing
            ColumnLayout {
                spacing: Theme.unit * 2
                Body { text: "Sur la PS5 : Réglages > Système > Lecture à distance > Associer l'appareil. Un code PIN à 8 chiffres s'affiche ; saisissez-le ici." }
                Repeater {
                    model: page.hosts
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.unit * 2
                        Body { text: modelData.name }
                        Text {
                            visible: modelData.registered
                            text: "Console appairée"
                            font.family: Theme.ui
                            font.pixelSize: Theme.small
                            color: Theme.mint
                        }
                        FpButton {
                            visible: !modelData.registered && modelData.discovered
                            text: "Appairer"
                            onClicked: root.showRegistDialog(modelData.address, modelData.ps5)
                        }
                    }
                }
                Body {
                    visible: page.hosts.length === 0
                    color: Theme.dim
                    text: "Aucune console trouvée. Allumez la PS5 sur le même réseau."
                }
                Text {
                    visible: page.anyRegistered
                    text: "Console appairée"
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                    color: Theme.mint
                }
            }

            // 2. Network
            ColumnLayout {
                spacing: Theme.unit * 2
                Body { text: "• Ethernet recommandé pour le PC" }
                Body { text: "• PS5 en Ethernet" }
                Body { text: "• Sinon Wi-Fi 5 GHz" }
                Body {
                    color: Theme.dim
                    font.pixelSize: Theme.small
                    text: "Le débit et la gigue sont mesurés pendant la première partie (overlay F3, écran Diagnostic)."
                }
            }

            // 3. Profile
            ColumnLayout {
                spacing: Theme.unit * 2
                Repeater {
                    model: FarplayProfiles.defaults
                    delegate: FpCard {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 96
                        activeFocusOnTab: true
                        readonly property bool chosen: FarplayProfiles.current === modelData.name
                        border.color: chosen ? Theme.mint : (activeFocus ? Theme.ivory : Theme.border)
                        border.width: chosen || activeFocus ? 2 : 1
                        function choose() { FarplayProfiles.apply(modelData.name) }
                        Keys.onReturnPressed: choose()
                        Keys.onSpacePressed: choose()
                        MouseArea { anchors.fill: parent; onClicked: { parent.forceActiveFocus(); parent.choose() } }
                        Column {
                            spacing: 4
                            Text {
                                text: modelData.name
                                font.family: Theme.ui
                                font.pixelSize: Theme.body
                                color: Theme.ivory
                            }
                            Text {
                                text: modelData.fps + " fps · " + (modelData.frameGen === 0 ? "sans frame gen" : "frame gen x" + modelData.multiplier)
                                font.family: Theme.mono
                                font.pixelSize: Theme.small
                                color: Theme.dim
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.unit * 2
            FpButton { text: "Passer"; onClicked: page.done() }
            Item { Layout.fillWidth: true }
            FpButton { text: "Retour"; visible: page.step > 0; onClicked: page.step-- }
            FpButton {
                id: nextBtn
                primary: true
                text: page.step < 2 ? "Suivant" : "Terminer"
                onClicked: page.next()
            }
        }
    }
}
