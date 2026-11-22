// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — barre flottante en haut de l'écran pendant une partie (comme la barre
// d'un lecteur vidéo). Glisse depuis le haut quand `shown` passe à true.
import QtQuick
import org.streetpea.chiaking

Item {
    id: root
    // The root is a plain Item so that a Loader can size it to the full width without
    // stretching the floating pill (Loader resizes its item when it has an explicit size).
    property bool shown: false
    property bool muted: false
    signal quickSettingsRequested()
    signal muteToggled()
    signal fullscreenToggled()
    signal quitRequested()

    readonly property var s: Farplay.snapshot || ({})
    readonly property bool live: !!Chiaki.session
    readonly property real fpsIn: s.fpsIn || 0
    readonly property real fpsShown: (s.fpsDistinct || 0) > 0 ? s.fpsDistinct : (s.fpsOut || 0)
    readonly property string hdrLabel: {
        var h = String(s.hdr === undefined || s.hdr === null || s.hdr === false ? "" : (s.hdr === true ? "HDR" : s.hdr))
        if (h === "" || /sdr/i.test(h)) return "SDR"
        return /hdr10/i.test(h) ? "HDR10" : "HDR"
    }
    readonly property string statusText: live && fpsIn > 0
        ? "PS5 · %1 → %2 fps · %3".arg(fpsIn.toFixed(0)).arg(fpsShown.toFixed(0)).arg(hdrLabel)
        : "PS5 · —"

    visible: pill.y > -pill.height
    implicitWidth: 400
    implicitHeight: 96

  FpGlass {
    id: pill
    height: 56
    radius: height / 2
    fillAlpha: 0.78
    width: row.implicitWidth + 28
    x: Math.round((root.width - width) / 2)
    y: root.shown ? 16 : -height - 24
    visible: y > -height
    z: 100
    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    component BarButton: FocusScope {
        id: btn
        property string iconName
        property string tip
        property bool active: false
        property bool danger: false
        property bool tipShown: false
        signal clicked()
        readonly property bool hovered: mouse.containsMouse
        width: 40
        height: 40
        activeFocusOnTab: true
        Keys.onReturnPressed: btn.clicked()
        Keys.onEnterPressed: btn.clicked()
        Keys.onSpacePressed: btn.clicked()
        onHoveredChanged: { if (hovered) tipTimer.restart(); else { tipTimer.stop(); tipShown = false } }
        Timer { id: tipTimer; interval: 350; onTriggered: btn.tipShown = true }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            scale: mouse.pressed ? 0.92 : 1
            Behavior on scale { NumberAnimation { duration: 80 } }
            color: btn.danger && btn.hovered ? Qt.rgba(0.9, 0.28, 0.3, mouse.pressed ? 0.30 : 0.20)
                 : btn.active ? Theme.coralSoft
                 : Qt.rgba(0.96, 0.945, 0.933, mouse.pressed ? 0.14 : (btn.hovered ? 0.08 : 0))
            border.width: btn.active ? 1 : 0
            border.color: Theme.coralLine
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.ivory
            visible: btn.activeFocus
        }
        FpIcon {
            anchors.centerIn: parent
            name: btn.iconName
            size: 22
            tone: btn.danger && btn.hovered ? "alert" : (btn.active ? "coral" : "ivory")
            opacity: btn.active || btn.hovered || btn.activeFocus ? 1 : 0.85
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { btn.clicked() }
        }
        FpGlass {
            visible: btn.tipShown
            z: 10
            x: (btn.width - width) / 2
            y: btn.height + 16
            width: tipText.implicitWidth + 28
            height: 32
            radius: 16
            fillAlpha: 0.92
            Text {
                id: tipText
                anchors.centerIn: parent
                text: btn.tip
                font.family: Theme.ui
                font.pixelSize: Theme.small
                color: Theme.ivory
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        FpLogo {
            size: 24
            anchors.verticalCenter: parent.verticalCenter
            // keep a little air around the mark
        }
        Item { width: 6; height: 1 }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: chipRow.implicitWidth + 28
            height: 36
            radius: 18
            color: Qt.rgba(0, 0, 0, 0.28)
            border.width: 1
            border.color: Theme.line
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 10
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9
                    height: 9
                    radius: 4.5
                    color: root.live ? Theme.mint : Theme.dim
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.statusText
                    font.family: Theme.mono
                    font.pixelSize: Theme.small
                    color: Theme.ivory
                }
            }
        }
        Item { width: 8; height: 1 }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: Theme.line
        }
        Item { width: 4; height: 1 }

        BarButton {
            iconName: "gear"
            tip: "Réglages rapides"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.quickSettingsRequested()
        }
        BarButton {
            iconName: "stats"
            tip: "Statistiques"
            active: Farplay.overlayLevel > 0
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Farplay.cycleOverlayLevel()
        }
        BarButton {
            iconName: "framegen"
            tip: "Génération d'images"
            active: FarplayFrameGen.mode === 1 && !FarplayFrameGen.suspended
            anchors.verticalCenter: parent.verticalCenter
            onClicked: FarplayFrameGen.toggleSuspended()
        }
        BarButton {
            iconName: root.muted ? "micoff" : "mic"
            tip: root.muted ? "Réactiver le micro" : "Couper le micro"
            active: root.muted
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.muteToggled()
        }
        BarButton {
            iconName: "fullscreen"
            tip: "Plein écran"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.fullscreenToggled()
        }
        Item { width: 4; height: 1 }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: Theme.line
        }
        Item { width: 4; height: 1 }
        BarButton {
            iconName: "power"
            tip: "Quitter la session"
            danger: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.quitRequested()
        }
    }
}
  }
