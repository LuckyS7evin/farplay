// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

Item {
    id: root
    property string text
    property string iconName: ""
    property bool primary: false
    property bool selected: false
    property bool danger: false
    property bool flat: false      // text-only link look
    property int fontSize: Theme.body
    property int iconSize: 20
    signal clicked()

    activeFocusOnTab: true
    implicitWidth: Math.max(primary ? 140 : 96, row.implicitWidth + (flat ? 24 : 44))
    implicitHeight: flat ? 40 : 48
    opacity: enabled ? 1 : 0.4
    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(root)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.primary ? Theme.coral : (root.flat ? "transparent" : Theme.graphite)
        border.width: root.flat ? 0 : 1
        border.color: root.selected ? Theme.mint : (root.primary ? Theme.coral : Theme.line)
        Behavior on color { ColorAnimation { duration: Theme.duration } }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.primary ? Theme.night : Theme.ivory
            opacity: mouse.pressed ? 0.16 : (mouse.containsMouse ? 0.07 : 0)
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: root.primary ? Theme.ivory : Theme.coral
        visible: root.activeFocus
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        FpIcon {
            visible: root.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.iconName
            size: root.iconSize
            tone: root.primary ? "night" : (root.danger ? "alert" : "ivory")
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Theme.ui
            font.pixelSize: root.fontSize
            font.weight: root.primary ? Font.DemiBold : Font.Medium
            color: root.primary ? Theme.night : (root.danger ? Theme.alert : (root.flat ? Theme.dim : Theme.ivory))
        }
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
