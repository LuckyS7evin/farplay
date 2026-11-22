// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

// Sidebar entry: icon + label. `current` marks the displayed section (coral tint + left bar).
FocusScope {
    id: root
    property string text
    property string iconName: "home"
    property bool current: false
    signal activated()

    activeFocusOnTab: true
    implicitHeight: 48
    implicitWidth: 220

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.current ? Theme.coralSoft : Qt.rgba(0.96, 0.945, 0.933, mouse.containsMouse ? 0.06 : 0)
        Behavior on color { ColorAnimation { duration: Theme.duration } }
    }
    Rectangle {
        visible: root.current
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 22
        radius: 1.5
        color: Theme.coral
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: "transparent"
        border.width: 2
        border.color: Theme.coral
        visible: root.activeFocus
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.unit * 2
        spacing: Theme.unit * 1.5
        FpIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.iconName
            tone: root.current ? "coral" : "ivory"
            size: 22
            opacity: root.current || root.activeFocus ? 1 : 0.65
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Theme.ui
            font.pixelSize: Theme.body - 1
            font.weight: root.current ? Font.DemiBold : Font.Medium
            color: root.current ? Theme.coral : (root.activeFocus ? Theme.ivory : Theme.dim)
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: { root.forceActiveFocus(); root.activated() }
    }
    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()
    Keys.onSpacePressed: root.activated()
}
