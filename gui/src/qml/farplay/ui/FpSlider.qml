// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

FocusScope {
    id: root
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string unit: ""
    // Emitted with the requested value; the owner updates its model (keeps bindings alive).
    signal moved(real newValue)

    activeFocusOnTab: true
    implicitWidth: 340
    implicitHeight: 36

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    function snap(v) {
        var s = Math.round((v - from) / stepSize) * stepSize + from
        return Math.max(from, Math.min(to, s))
    }
    function step(d) {
        var v = snap(value + d * stepSize)
        if (v !== value) moved(v)
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: label.left
        anchors.rightMargin: Theme.unit * 2
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Theme.graphite
        border.width: 1
        border.color: Theme.border
        Rectangle {
            width: parent.width * root.ratio
            height: parent.height
            radius: 3
            color: Theme.ivory
            opacity: 0.55
        }
        Rectangle {
            x: (parent.width - width) * root.ratio
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 10
            color: Theme.ivory
            border.width: root.activeFocus ? 4 : 0
            border.color: Theme.night
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Theme.ivory
                visible: root.activeFocus
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -12
            anchors.bottomMargin: -12
            function set(mx) {
                root.forceActiveFocus()
                var v = root.snap(root.from + (root.to - root.from) * Math.max(0, Math.min(1, mx / width)))
                if (v !== root.value) root.moved(v)
            }
            onPressed: (m) => set(m.x)
            onPositionChanged: (m) => { if (pressed) set(m.x) }
        }
    }
    Text {
        id: label
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 96
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) / 100 + (root.unit ? " " + root.unit : "")
        font.family: Theme.mono
        font.pixelSize: Theme.body
        color: Theme.ivory
    }
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
}
