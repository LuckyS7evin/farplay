// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

// Segmented "pills" control. currentIndex may be -1 (nothing selected).
// activated(index) is emitted when the user picks a segment; the owner updates its model.
FocusScope {
    id: root
    property var model: []
    property int currentIndex: 0
    property int segHeight: 34
    property int minSegWidth: 56
    property int fontSize: Theme.small + 1
    signal activated(int index)

    activeFocusOnTab: true
    implicitWidth: strip.implicitWidth + 6
    implicitHeight: segHeight + 6
    opacity: enabled ? 1 : 0.4
    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(root)

    function pick(i) {
        if (i < 0 || i >= model.length || i === currentIndex) return false
        activated(i)
        return true
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.night
        border.width: 1
        border.color: Theme.line
    }
    Row {
        id: strip
        x: 3
        y: 3
        Repeater {
            model: root.model
            delegate: Item {
                id: seg
                required property var modelData
                required property int index
                readonly property bool on: index === root.currentIndex
                width: Math.max(root.minSegWidth, segText.implicitWidth + 28)
                height: root.segHeight
                implicitWidth: width
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: seg.on ? Theme.coralSoft : (segMouse.containsMouse ? Qt.rgba(0.96, 0.945, 0.933, 0.06) : "transparent")
                    border.width: seg.on ? 1 : 0
                    border.color: Theme.coralLine
                }
                Text {
                    id: segText
                    anchors.centerIn: parent
                    text: seg.modelData
                    font.family: Theme.ui
                    font.pixelSize: root.fontSize
                    font.weight: Font.Medium
                    color: seg.on ? Theme.coral : Theme.dim
                }
                MouseArea {
                    id: segMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { root.forceActiveFocus(); root.pick(seg.index) }
                }
            }
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
    Keys.onLeftPressed: (e) => { if (!pick(currentIndex < 0 ? 0 : currentIndex - 1)) e.accepted = false }
    Keys.onRightPressed: (e) => { if (!pick(currentIndex + 1)) e.accepted = false }
}
