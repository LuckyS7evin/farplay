// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

Item {
    id: page
    anchors.fill: parent

    readonly property var hosts: Chiaki.hosts || []
    readonly property var currentHost: list.currentIndex >= 0 && list.currentIndex < hosts.length ? hosts[list.currentIndex] : null
    readonly property bool canPlay: currentHost !== null && currentHost.registered === true

    function play() {
        if (!canPlay) return
        if (currentHost.discovered) Chiaki.connectToHost(list.currentIndex, currentHost.name)
        else Chiaki.connectToHost(list.currentIndex)
    }

    Component.onCompleted: {
        if (playBtn.enabled) playBtn.forceActiveFocus()
        else if (hosts.length > 0) list.forceActiveFocus()
        else addBtn.forceActiveFocus()
    }

    Rectangle { anchors.fill: parent; color: Theme.night }

    RowLayout {
        x: Theme.unit * 5
        y: Theme.unit * 4
        spacing: Theme.unit * 2
        FpLogo { size: 44; animateIntro: true }
        Text {
            text: "Farplay"
            font.family: Theme.ui
            font.pixelSize: Theme.title
            color: Theme.ivory
        }
    }

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.unit * 10, 1100)
        spacing: Theme.unit * 4

        NumberAnimation on x { from: -Theme.slideDistance; to: 0; duration: Theme.duration; easing.type: Theme.easing }

        // Empty state
        ColumnLayout {
            visible: page.hosts.length === 0
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.unit
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Aucune console trouvée"
                font.family: Theme.ui
                font.pixelSize: Theme.title
                color: Theme.ivory
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Allumez la PS5 sur le même réseau"
                font.family: Theme.ui
                font.pixelSize: Theme.body
                color: Theme.dim
            }
        }

        ListView {
            id: list
            visible: page.hosts.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 230
            orientation: ListView.Horizontal
            spacing: Theme.unit * 3
            model: page.hosts
            clip: false
            focus: true
            keyNavigationEnabled: true
            highlightMoveDuration: Theme.duration
            KeyNavigation.down: playBtn

            delegate: FocusScope {
                id: card
                required property var modelData
                required property int index
                readonly property bool selected: ListView.isCurrentItem
                focus: selected
                width: 320
                height: 220
                Keys.onDownPressed: (e) => {
                    if (actionBtn.visible) actionBtn.forceActiveFocus()
                    else e.accepted = false
                }
                Keys.onReturnPressed: page.play()

                FpCard {
                    anchors.fill: parent
                    border.color: card.selected ? Theme.ivory : Theme.border
                    border.width: card.selected ? 2 : 1
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.unit
                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.ui
                            font.pixelSize: Theme.body
                            color: Theme.ivory
                        }
                        Text {
                            text: card.modelData.ps5 ? "PS5" : "PS4"
                            font.family: Theme.mono
                            font.pixelSize: Theme.small
                            color: Theme.dim
                        }
                        Text {
                            readonly property string st: card.modelData.state
                            text: st === "ready" ? (card.modelData.ps5 ? "PS5 prête" : "PS4 prête")
                                : st === "standby" ? "En veille" : "Introuvable"
                            font.family: Theme.ui
                            font.pixelSize: Theme.small
                            color: st === "ready" ? Theme.mint : st === "standby" ? Theme.dim : Theme.alert
                        }
                        Item { Layout.fillHeight: true }
                        FpButton {
                            id: actionBtn
                            Layout.fillWidth: true
                            readonly property bool wake: card.modelData.state === "standby"
                            readonly property bool pair: !card.modelData.registered && card.modelData.discovered
                            visible: wake || pair
                            text: wake ? "Réveiller" : "Appairer"
                            KeyNavigation.up: card
                            KeyNavigation.down: playBtn
                            onClicked: {
                                if (wake) Chiaki.wakeUpHost(card.index, card.modelData.name)
                                else root.showRegistDialog(card.modelData.address, card.modelData.ps5)
                            }
                        }
                    }
                }
            }
        }

        FpButton {
            id: playBtn
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            primary: true
            text: "Jouer"
            enabled: page.canPlay
            onClicked: page.play()
            KeyNavigation.up: list
            KeyNavigation.down: profileSelect
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.unit * 2
            Text {
                text: "Profil"
                font.family: Theme.ui
                font.pixelSize: Theme.body
                color: Theme.dim
            }
            FpSelect {
                id: profileSelect
                model: FarplayProfiles.names
                currentIndex: FarplayProfiles.names.indexOf(FarplayProfiles.current)
                onActivated: (i) => FarplayProfiles.apply(FarplayProfiles.names[i])
                KeyNavigation.up: playBtn
                KeyNavigation.down: settingsBtn
            }
        }

        Flow {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            spacing: Theme.unit * 2
            layoutDirection: Qt.LeftToRight
            FpButton {
                id: settingsBtn
                text: "Réglages"
                onClicked: root.showFarplayView("qrc:/farplay/ui/FarplaySettings.qml")
                KeyNavigation.up: profileSelect
                KeyNavigation.right: diagBtn
            }
            FpButton {
                id: diagBtn
                text: "Diagnostic"
                onClicked: root.showFarplayView("qrc:/farplay/ui/FarplayDiagnostic.qml")
                KeyNavigation.up: profileSelect
                KeyNavigation.left: settingsBtn
                KeyNavigation.right: addBtn
            }
            FpButton {
                id: addBtn
                text: "Ajouter une console"
                onClicked: root.showManualHostDialog()
                KeyNavigation.up: profileSelect
                KeyNavigation.left: diagBtn
                KeyNavigation.right: advBtn
            }
            FpButton {
                id: advBtn
                text: "Réglages avancés (chiaki-ng)"
                onClicked: root.showSettingsDialog()
                KeyNavigation.up: profileSelect
                KeyNavigation.left: addBtn
                KeyNavigation.right: classicBtn
            }
            FpButton {
                id: classicBtn
                text: "Vue chiaki-ng"
                onClicked: root.showChiakiMainView()
                KeyNavigation.up: profileSelect
                KeyNavigation.left: advBtn
            }
        }
    }
}
