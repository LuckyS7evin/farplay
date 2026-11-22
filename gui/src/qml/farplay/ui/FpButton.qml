// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

Item {
    id: root
    property string text
    property bool primary: false
    property bool selected: false
    signal clicked()

    activeFocusOnTab: true
    implicitWidth: Math.max(120, label.implicitWidth + 40)
    implicitHeight: 48
    opacity: enabled ? 1 : 0.4
    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(root)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.primary ? Theme.coral : Theme.graphite
        border.width: 1
        border.color: root.selected ? Theme.mint : (root.primary ? Theme.coral : Theme.border)
        Behavior on color { ColorAnimation { duration: Theme.duration } }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.ivory
            opacity: mouse.pressed ? 0.12 : (mouse.containsMouse ? 0.06 : 0)
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Theme.radius + 4
        color: "transparent"
        border.width: 2
        border.color: Theme.ivory
        visible: root.activeFocus
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.ui
        font.pixelSize: Theme.body
        color: root.primary ? Theme.night : Theme.ivory
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: { root.forceActiveFocus(); root.clicked() }
    }
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
