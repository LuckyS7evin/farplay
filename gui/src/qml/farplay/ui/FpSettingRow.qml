// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts

FocusScope {
    id: root
    property string title
    property string description
    property var costs: ({})
    property bool boxed: false      // own rounded cell (quick panel)
    property bool divider: false    // 1 px line above (stacked rows in a section card)
    default property alias control: slot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(texts.implicitHeight, slot.childrenRect.height) + (boxed ? Theme.unit * 3 : Theme.unit * 3)

    Component.onCompleted: {
        if (slot.children.length > 0)
            slot.children[0].focus = true
    }
    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(root)
    Keys.onUpPressed: { var i = nextItemInFocusChain(false); if (i) i.forceActiveFocus() }
    Keys.onDownPressed: { var i = nextItemInFocusChain(true); if (i) i.forceActiveFocus() }

    Rectangle {
        anchors.fill: parent
        radius: root.boxed ? 18 : Theme.radius
        color: root.boxed ? Qt.rgba(0.09, 0.083, 0.102, 0.8) : Theme.ivory
        opacity: root.boxed ? 1 : (root.activeFocus ? 0.05 : 0)
        border.width: root.boxed ? 1 : 0
        border.color: Theme.line
        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
    }
    Rectangle {
        visible: root.divider
        x: Theme.unit * 2
        width: parent.width - Theme.unit * 4
        height: 1
        color: Theme.line
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.boxed ? Theme.unit * 3 : Theme.unit * 2
        anchors.rightMargin: root.boxed ? Theme.unit * 3 : Theme.unit * 2
        spacing: Theme.unit * 3
        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3
            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                font.family: Theme.ui
                font.pixelSize: root.boxed ? Theme.body - 1 : Theme.body
                font.weight: Font.Medium
                color: Theme.ivory
            }
            Text {
                Layout.fillWidth: true
                text: root.description
                wrapMode: Text.WordWrap
                font.family: Theme.ui
                font.pixelSize: Theme.small - 1
                color: Theme.dim
                visible: text !== ""
            }
            FpCostBadges {
                Layout.fillWidth: true
                Layout.topMargin: 2
                costs: root.costs
                visible: Object.keys(root.costs || {}).length > 0
            }
        }
        Item {
            id: slot
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
        }
    }
}
