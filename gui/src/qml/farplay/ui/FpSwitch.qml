// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

FocusScope {
    id: root
    property bool checked: false
    // Emitted with the requested state; the owner updates its model (keeps bindings alive).
    signal toggled(bool checked)

    activeFocusOnTab: true
    implicitWidth: 64
    implicitHeight: 36

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.mint : Theme.graphite
        border.width: 1
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: Theme.duration } }
        Rectangle {
            width: parent.height - 8
            height: width
            radius: width / 2
            y: 4
            x: root.checked ? parent.width - width - 4 : 4
            color: root.checked ? Theme.night : Theme.ivory
            Behavior on x { NumberAnimation { duration: Theme.duration; easing.type: Theme.easing } }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.ivory
        visible: root.activeFocus
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { root.forceActiveFocus(); root.toggled(!root.checked) }
    }
    Keys.onReturnPressed: toggled(!checked)
    Keys.onEnterPressed: toggled(!checked)
    Keys.onSpacePressed: toggled(!checked)
    Keys.onLeftPressed: if (checked) toggled(false)
    Keys.onRightPressed: if (!checked) toggled(true)
}
