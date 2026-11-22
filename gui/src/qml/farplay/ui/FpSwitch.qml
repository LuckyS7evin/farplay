// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

FocusScope {
    id: root
    property bool checked: false
    // Emitted with the requested state; the owner updates its model (keeps bindings alive).
    signal toggled(bool checked)

    // Fine "glass" toggle: 36x18 track, 12 px knob, 1 px border.
    activeFocusOnTab: true
    implicitWidth: 36
    implicitHeight: 18
    opacity: enabled ? 1 : 0.4
    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(root)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Qt.rgba(1, 0.42, 0.29, 0.22) : Qt.rgba(0.96, 0.945, 0.933, 0.06)
        border.width: 1
        border.color: root.checked ? Theme.coralLine : Qt.rgba(0.96, 0.945, 0.933, 0.22)
        Behavior on color { ColorAnimation { duration: Theme.duration } }
        Behavior on border.color { ColorAnimation { duration: Theme.duration } }
        // glass highlight
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassHighlight }
                GradientStop { position: 0.6; color: "transparent" }
            }
        }
        Rectangle {
            width: 12
            height: 12
            radius: 6
            y: (parent.height - height) / 2
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.coral : Theme.ivory
            opacity: root.checked ? 1 : 0.7
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
        anchors.margins: -6
        onClicked: { root.forceActiveFocus(); root.toggled(!root.checked) }
    }
    Keys.onReturnPressed: toggled(!checked)
    Keys.onEnterPressed: toggled(!checked)
    Keys.onSpacePressed: toggled(!checked)
    Keys.onLeftPressed: (e) => { if (checked) toggled(false); else e.accepted = false }
    Keys.onRightPressed: (e) => { if (!checked) toggled(true); else e.accepted = false }
}
