// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

// Thin slider: 3 px track, 14 px knob.
FocusScope {
    id: root
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string unit: ""
    property bool showValue: true
    property int valueWidth: 84
    // Emitted with the requested value; the owner updates its model (keeps bindings alive).
    signal moved(real newValue)

    activeFocusOnTab: true
    implicitWidth: 340
    implicitHeight: 32
    opacity: enabled ? 1 : 0.4
    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(root)

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    function snap(v) {
        var s = Math.round((v - from) / stepSize) * stepSize + from
        return Math.max(from, Math.min(to, s))
    }
    function step(d) {
        var v = snap(value + d * stepSize)
        if (v !== value) moved(v)
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: label.visible ? label.left : parent.right
        anchors.rightMargin: label.visible ? Theme.unit * 2 : 0
        anchors.verticalCenter: parent.verticalCenter
        height: 14
        Rectangle {
            id: rail
            width: parent.width
            height: 3
            radius: 1.5
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(0.96, 0.945, 0.933, 0.14)
            Rectangle {
                width: handle.x + handle.width / 2
                height: parent.height
                radius: 1.5
                color: Theme.coral
            }
        }
        Rectangle {
            id: handle
            x: (parent.width - width) * root.ratio
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: Theme.ivory
            Rectangle {
                anchors.fill: parent
                anchors.margins: -5
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Theme.coral
                visible: root.activeFocus
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -12
            anchors.bottomMargin: -12
            function set(mx) {
                root.forceActiveFocus()
                var w = Math.max(1, width - handle.width)
                var v = root.snap(root.from + (root.to - root.from) * Math.max(0, Math.min(1, (mx - handle.width / 2) / w)))
                if (v !== root.value) root.moved(v)
            }
            onPressed: (m) => set(m.x)
            onPositionChanged: (m) => { if (pressed) set(m.x) }
        }
    }
    Text {
        id: label
        visible: root.showValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.valueWidth
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) / 100 + (root.unit ? " " + root.unit : "")
        font.family: Theme.mono
        font.pixelSize: Theme.small + 1
        color: Theme.ivory
    }
    Keys.onLeftPressed: (e) => { if (value > from) step(-1); else e.accepted = false }
    Keys.onRightPressed: (e) => { if (value < to) step(1); else e.accepted = false }
}
