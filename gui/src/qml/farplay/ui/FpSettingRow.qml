// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts

FocusScope {
    id: root
    property string title
    property string description
    property var costs: ({})
    default property alias control: slot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(texts.implicitHeight, slot.childrenRect.height) + Theme.unit * 3

    Component.onCompleted: {
        if (slot.children.length > 0)
            slot.children[0].focus = true
    }
    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(root)
    Keys.onUpPressed: { var i = nextItemInFocusChain(false); if (i) i.forceActiveFocus() }
    Keys.onDownPressed: { var i = nextItemInFocusChain(true); if (i) i.forceActiveFocus() }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.ivory
        opacity: root.activeFocus ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
    }
    Rectangle {
        width: 3
        height: parent.height - Theme.unit * 2
        anchors.verticalCenter: parent.verticalCenter
        radius: 1
        color: Theme.ivory
        visible: root.activeFocus
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.unit * 2
        anchors.rightMargin: Theme.unit * 2
        spacing: Theme.unit * 3
        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4
            Text {
                text: root.title
                font.family: Theme.ui
                font.pixelSize: Theme.body
                color: Theme.ivory
            }
            Text {
                Layout.fillWidth: true
                text: root.description
                wrapMode: Text.WordWrap
                font.family: Theme.ui
                font.pixelSize: Theme.small
                color: Theme.dim
                visible: text !== ""
            }
            FpCostBadges {
                Layout.fillWidth: true
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
