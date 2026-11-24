// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Controls.Basic
import org.streetpea.chiaking

Item {
    id: page
    anchors.fill: parent

    readonly property var hosts: Chiaki.hosts || []
    readonly property var currentHost: list.currentIndex >= 0 && list.currentIndex < hosts.length ? hosts[list.currentIndex] : null
    readonly property bool canPlay: currentHost !== null && currentHost.registered === true
    readonly property real sideMargin: Math.max(32, Math.min(96, width * 0.05))
    readonly property bool wide: width >= 1100
    readonly property Item chipTarget: chipRep.count > 0 ? chipRep.itemAt(Math.max(0, FarplayProfiles.names.indexOf(FarplayProfiles.current))) : null

    function play() {
        if (!canPlay) return
        if (currentHost.discovered) Chiaki.connectToHost(list.currentIndex, currentHost.name)
        else Chiaki.connectToHost(list.currentIndex)
    }

    Component.onCompleted: {
        list.forceActiveFocus()
        askPsn.start()
    }
    // Back from a sub-screen (register, settings...): give focus back to the page.
    onVisibleChanged: if (visible) refocus.restart()
    Timer {
        id: refocus
        interval: 0
        onTriggered: {
            const w = page.Window.window
            let p = w ? w.activeFocusItem : null
            while (p && p !== page) p = p.parent
            if (!p) list.forceActiveFocus()
        }
    }
    // First launch: offer the PSN connection (remote play), like chiaki-ng's main view did.
    Timer {
        id: askPsn
        interval: 600
        onTriggered: {
            if (root.initialAsk || !Chiaki.settings.remotePlayAsk) return
            root.initialAsk = true
            if (!Chiaki.settings.psnRefreshToken || !Chiaki.settings.psnAuthToken || !Chiaki.settings.psnAuthTokenExpiry || !Chiaki.settings.psnAccountId)
                root.showRemindDialog("Jouer à distance via PSN",
                    "Voulez-vous connecter votre compte PlayStation Network ?\n\nCela permet :\n• l'appairage automatique\n• de jouer hors de votre réseau, sans redirection de ports\n\n(Pour le faire plus tard : Réglages > Consoles.)",
                    true, () => root.showPSNTokenDialog(false))
            else
                Chiaki.settings.remotePlayAsk = false
        }
    }

    // ── Background: night + coral glow (top left) + violet-graphite vignette ──
    Rectangle { anchors.fill: parent; color: Theme.night }
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: page.width * 0.22; centerY: -40
                centerRadius: Math.max(page.width, page.height) * 0.62
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.42, 0.29, 0.24) }
                GradientStop { position: 0.55; color: Qt.rgba(1, 0.42, 0.29, 0.05) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 0.42, 0.29, 0) }
            }
            startX: 0; startY: 0
            PathLine { x: page.width; y: 0 }
            PathLine { x: page.width; y: page.height }
            PathLine { x: 0; y: page.height }
            PathLine { x: 0; y: 0 }
        }
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: page.width * 0.9; centerY: page.height * 0.95
                centerRadius: Math.max(page.width, page.height) * 0.5
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: Qt.rgba(0.235, 0.188, 0.353, 0.38) }
                GradientStop { position: 1.0; color: Qt.rgba(0.235, 0.188, 0.353, 0) }
            }
            startX: 0; startY: 0
            PathLine { x: page.width; y: 0 }
            PathLine { x: page.width; y: page.height }
            PathLine { x: 0; y: page.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // ── Top bar ────────────────────────────────────────────────────────────
    Item {
        id: topBar
        x: page.sideMargin
        y: Theme.unit * 4
        width: page.width - page.sideMargin * 2
        height: 56
        z: 2
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            FpLogo { size: 40; animateIntro: true; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Farplay"
                font.family: Theme.ui
                font.pixelSize: Theme.body + 2
                font.weight: Font.DemiBold
                color: Theme.ivory
            }
        }
        FpButton {
            id: settingsBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconName: "gear"
            text: "Réglages"
            onClicked: root.showFarplayView("qrc:/farplay/ui/FarplaySettings.qml")
            KeyNavigation.down: list
        }
    }

    // Défilement (fenêtre réduite) : la molette, le glisser et la navigation
    // au clavier/à la manette amènent l'élément sélectionné à l'écran.
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.topMargin: topBar.y + topBar.height + Theme.unit
        anchors.bottomMargin: hints.height + Theme.unit * 3
        contentWidth: width
        contentHeight: Math.max(height, content.implicitHeight + Theme.unit * 4)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: FpScrollBar {}

        ColumnLayout {
            id: content
            x: page.sideMargin
            y: Math.max(Theme.unit, (flick.height - implicitHeight) / 2)
            width: flick.width - page.sideMargin * 2
            transform: Translate { id: slideIn }
            spacing: Theme.unit * 4

            NumberAnimation { target: slideIn; property: "x"; running: true; from: -Theme.slideDistance; to: 0; duration: Theme.duration; easing.type: Theme.easing }

            // Hero
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.unit * 1.5
                Text {
                    text: page.hosts.length > 0 ? "Bon retour" : "Bienvenue"
                    font.family: Theme.ui
                    font.pixelSize: Theme.small
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.5
                    font.capitalization: Font.AllUppercase
                    color: Theme.coral
                }
                Text {
                    Layout.fillWidth: true
                    text: page.hosts.length > 0 ? "Prête à jouer ?" : "Aucune console trouvée"
                    wrapMode: Text.WordWrap
                    font.family: Theme.ui
                    font.pixelSize: page.wide ? 60 : 44
                    font.weight: Font.DemiBold
                    color: Theme.ivory
                }
                Text {
                    Layout.fillWidth: true
                    text: page.hosts.length > 0 ? "Votre PS5 en 4K HDR, sans quitter le canapé." : "Allumez la PS5 sur le même réseau, ou ajoutez-la à la main."
                    wrapMode: Text.WordWrap
                    font.family: Theme.ui
                    font.pixelSize: Theme.body + 2
                    color: Theme.dim
                }
            }

            // Console tiles
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: 292
                Layout.topMargin: Theme.unit
                orientation: ListView.Horizontal
                spacing: Theme.unit * 3
                model: page.hosts.length + 1
                clip: false
                focus: true
                keyNavigationEnabled: true
                highlightMoveDuration: Theme.duration
                KeyNavigation.up: settingsBtn
                KeyNavigation.down: page.chipTarget

                delegate: FocusScope {
                    id: tile
                    required property int index
                    readonly property bool isAdd: index >= page.hosts.length
                    readonly property var host: isAdd ? null : page.hosts[index]
                    readonly property bool selected: ListView.isCurrentItem
                    readonly property bool ready: host !== null && host.state === "ready"
                    focus: selected
                    width: isAdd ? 360 : Math.min(540, Math.max(380, list.width * 0.46))
                    height: 280

                    function activate() {
                        if (isAdd) root.showManualHostDialog()
                        else page.play()
                    }
                    Keys.onDownPressed: (e) => {
                        if (actionBtn.visible) actionBtn.forceActiveFocus()
                        else e.accepted = false
                    }
                    Keys.onReturnPressed: tile.activate()
                    Keys.onEnterPressed: tile.activate()
                    Keys.onSpacePressed: tile.activate()

                    FpGlass {
                        anchors.fill: parent
                        radius: 30
                        fillAlpha: tile.isAdd ? 0.25 : (tile.ready ? 0.82 : 0.55)
                        highlight: !tile.isAdd
                        border.width: tile.isAdd ? 2 : 1
                        border.color: tile.selected ? Qt.rgba(0.96, 0.945, 0.933, 0.35) : Theme.line
                        scale: tile.selected ? 1 : 0.985
                        Behavior on scale { NumberAnimation { duration: Theme.duration; easing.type: Theme.easing } }
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -5
                        radius: 35
                        color: "transparent"
                        border.width: 3
                        border.color: Theme.ivory
                        visible: tile.selected && list.activeFocus
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { list.currentIndex = tile.index; list.forceActiveFocus() }
                        onDoubleClicked: { list.currentIndex = tile.index; tile.activate() }
                    }

                    // Host tile
                    Item {
                        anchors.fill: parent
                        visible: !tile.isAdd
                        // Console silhouette
                        Rectangle {
                            x: 40; y: 52
                            width: 76; height: 176
                            radius: 32
                            opacity: tile.ready ? 1 : 0.45
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#FFFFFF" }
                                GradientStop { position: 1; color: "#C9C4C8" }
                            }
                            Rectangle { anchors.centerIn: parent; width: 7; height: 124; radius: 3.5; color: "#1A181D"; opacity: 0.85 }
                            Rectangle { x: parent.width - 16; y: 34; width: 3; height: 50; radius: 1.5; color: tile.ready ? Theme.mint : "#8A858A" }
                        }
                        ColumnLayout {
                            x: 148; y: 44
                            width: parent.width - 148 - 32
                            height: parent.height - 44 - 28
                            spacing: 6
                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 11; height: 11; radius: 5.5
                                    color: tile.ready ? Theme.mint : (tile.host && tile.host.state === "standby" ? Theme.dim : Theme.alert)
                                }
                                Text {
                                    readonly property string st: tile.host ? tile.host.state : ""
                                    text: st === "ready" ? (tile.host.ps5 ? "PS5 prête" : "PS4 prête")
                                        : st === "standby" ? "En veille" : "Introuvable"
                                    font.family: Theme.ui
                                    font.pixelSize: Theme.small
                                    font.weight: Font.DemiBold
                                    color: st === "ready" ? Theme.mint : st === "standby" ? Theme.dim : Theme.alert
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: tile.host ? tile.host.name : ""
                                elide: Text.ElideRight
                                font.family: Theme.ui
                                font.pixelSize: Theme.body + 8
                                font.weight: Font.DemiBold
                                color: Theme.ivory
                            }
                            Text {
                                text: tile.host ? (tile.host.address || (tile.host.ps5 ? "PS5" : "PS4")) : ""
                                font.family: Theme.mono
                                font.pixelSize: Theme.small
                                color: Theme.dim
                            }
                            Item { Layout.fillHeight: true }
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: !tile.host ? ""
                                    : !tile.host.registered ? "Appairez la console pour jouer"
                                    : tile.host.state === "standby" ? "Réveillez la console pour jouer" : ""
                                font.family: Theme.ui
                                font.pixelSize: Theme.small
                                color: Theme.dim
                            }
                            // Play pill: coral on the selected ready console (the single
                            // primary action), discreet outline on the other ready ones.
                            Rectangle {
                                id: playPill
                                visible: tile.ready && tile.host.registered === true
                                Layout.alignment: Qt.AlignLeft
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: pillRow.implicitWidth + 40
                                radius: height / 2
                                color: tile.selected ? Theme.coral : "transparent"
                                border.width: 1
                                border.color: tile.selected ? Theme.coral : Theme.line
                                Behavior on color { ColorAnimation { duration: Theme.duration } }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: tile.selected ? Theme.night : Theme.ivory
                                    opacity: pillMouse.pressed ? 0.16 : (pillMouse.containsMouse ? 0.07 : 0)
                                }
                                Row {
                                    id: pillRow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    FpIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "play"
                                        size: 16
                                        tone: tile.selected ? "night" : "ivory"
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Jouer"
                                        font.family: Theme.ui
                                        font.pixelSize: Theme.small + 2
                                        font.weight: tile.selected ? Font.DemiBold : Font.Medium
                                        color: tile.selected ? Theme.night : Theme.ivory
                                    }
                                }
                                MouseArea {
                                    id: pillMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: { list.currentIndex = tile.index; list.forceActiveFocus(); page.play() }
                                }
                            }
                            FpButton {
                                id: actionBtn
                                readonly property bool wake: tile.host !== null && tile.host.state === "standby"
                                readonly property bool pair: tile.host !== null && !tile.host.registered && tile.host.discovered
                                visible: wake || pair
                                iconName: wake ? "power" : "plus"
                                text: wake ? "Réveiller" : "Appairer"
                                fontSize: Theme.small + 1
                                implicitHeight: 44
                                onClicked: {
                                    if (wake) Chiaki.wakeUpHost(tile.index, tile.host.name)
                                    else root.showRegistDialog(tile.host.address, tile.host.ps5)
                                }
                                KeyNavigation.up: tile
                                KeyNavigation.down: page.chipTarget
                            }
                        }
                    }

                    // "Ajouter une console" tile
                    Column {
                        anchors.centerIn: parent
                        visible: tile.isAdd
                        spacing: 14
                        Rectangle {
                            width: 64; height: 64; radius: 32
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Theme.graphite
                            border.width: 1
                            border.color: Theme.line
                            FpIcon { anchors.centerIn: parent; name: "plus"; size: 28 }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Ajouter une console"
                            font.family: Theme.ui
                            font.pixelSize: Theme.body - 1
                            font.weight: Font.Medium
                            color: Theme.dim
                        }
                    }
                }
            }

            // Profiles
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.unit * 2

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.unit * 2
                    visible: FarplayProfiles.names.length > 0
                    Text {
                        text: "Profil"
                        font.family: Theme.ui
                        font.pixelSize: Theme.small
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2.5
                        font.capitalization: Font.AllUppercase
                        color: Theme.dim
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 14
                        Repeater {
                            id: chipRep
                            model: FarplayProfiles.names
                            delegate: FocusScope {
                                id: chip
                                required property string modelData
                                required property int index
                                readonly property bool on: modelData === FarplayProfiles.current
                                activeFocusOnTab: true
                                width: chipText.implicitWidth + 52
                                height: 56
                                onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(chip)
                                Keys.onReturnPressed: FarplayProfiles.apply(modelData)
                                Keys.onEnterPressed: FarplayProfiles.apply(modelData)
                                Keys.onSpacePressed: FarplayProfiles.apply(modelData)
                                Keys.onLeftPressed: (e) => { var c = chipRep.itemAt(index - 1); if (c) c.forceActiveFocus(); else e.accepted = false }
                                Keys.onRightPressed: (e) => { var c = chipRep.itemAt(index + 1); if (c) c.forceActiveFocus(); else e.accepted = false }
                                Keys.onUpPressed: list.forceActiveFocus()
                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: chip.on ? Theme.ivory : Theme.graphite
                                    border.width: 1
                                    border.color: chip.on ? Theme.ivory : Theme.line
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: chip.on ? Theme.night : Theme.ivory
                                        opacity: chipMouse.pressed ? 0.14 : (chipMouse.containsMouse ? 0.07 : 0)
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    radius: height / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.coral
                                    visible: chip.activeFocus
                                }
                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: chip.modelData
                                    font.family: Theme.ui
                                    font.pixelSize: Theme.body
                                    font.weight: Font.Medium
                                    color: chip.on ? Theme.night : Theme.ivory
                                }
                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: { chip.forceActiveFocus(); FarplayProfiles.apply(chip.modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FpHints {
        id: hints
        x: page.sideMargin
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.unit * 3
        model: [["✕", "Valider"]]
    }

    Connections {
        target: page.Window.window
        function onActiveFocusItemChanged() {
            const it = page.Window.window ? page.Window.window.activeFocusItem : null
            if (!it || flick.contentHeight <= flick.height) return
            let p = it
            while (p && p !== content) p = p.parent
            if (!p) return
            const pos = it.mapToItem(flick.contentItem, 0, 0)
            if (pos.y < flick.contentY + Theme.unit * 2)
                flick.contentY = Math.max(0, pos.y - Theme.unit * 2)
            else if (pos.y + it.height > flick.contentY + flick.height - Theme.unit * 2)
                flick.contentY = Math.min(flick.contentHeight - flick.height, pos.y + it.height - flick.height + Theme.unit * 2)
        }
    }
}
