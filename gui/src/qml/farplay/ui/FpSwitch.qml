// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

FocusScope {
    id: root
    property bool checked: false
    // Emitted with the requested state; the owner updates its model (keeps bindings alive).
    signal toggled(bool checked)

    activeFocusOnTab: true
    implicitWidth: 50
    implicitHeight: 28
    opacity: enabled ? 1 : 0.4
    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(root)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.coral : Theme.raised
        border.width: 1
        border.color: root.checked ? Theme.coral : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.duration } }
        Rectangle {
            width: parent.height - 8
            height: width
            radius: width / 2
            y: 4
            x: root.checked ? parent.width - width - 4 : 4
            color: root.checked ? Theme.night : Theme.dim
            Behavior on x { NumberAnimation { duration: Theme.duration; easing.type: Theme.easing } }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.coral
        visible: root.activeFocus
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { root.forceActiveFocus(); root.toggled(!root.checked) }
    }
    Keys.onReturnPressed: toggled(!checked)
    Keys.onEnterPressed: toggled(!checked)
    Keys.onSpacePressed: toggled(!checked)
    Keys.onLeftPressed: (e) => { if (checked) toggled(false); else e.accepted = false }
    Keys.onRightPressed: (e) => { if (!checked) toggled(true); else e.accepted = false }
}
