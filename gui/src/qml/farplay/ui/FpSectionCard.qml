// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts

// Collapsible settings card: icon tile, title, subtitle, cost badges, optional header toggle.
FpGlass {
    id: root
    property string iconName: "gear"
    property string title
    property string subtitle
    property var costs: ({})
    property bool hasToggle: false
    property bool checked: false
    property bool expanded: true
    // Emitted with the requested state of the header toggle.
    signal toggled(bool checked)
    default property alias content: bodyCol.data

    readonly property alias header: head
    readonly property alias toggle: headSwitch

    radius: 24
    fillAlpha: 0.7
    implicitHeight: col.implicitHeight
    Layout.fillWidth: true

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        FocusScope {
            id: head
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            activeFocusOnTab: true
            onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(head)
            Keys.onReturnPressed: root.expanded = !root.expanded
            Keys.onEnterPressed: root.expanded = !root.expanded
            Keys.onSpacePressed: root.expanded = !root.expanded

            MouseArea {
                anchors.fill: parent
                onClicked: { head.forceActiveFocus(); root.expanded = !root.expanded }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: root.radius - 1
                color: Theme.ivory
                opacity: head.activeFocus ? 0.05 : 0
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: root.radius + 2
                color: "transparent"
                border.width: 2
                border.color: Theme.coral
                visible: head.activeFocus
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.unit * 3
                anchors.rightMargin: Theme.unit * 3
                spacing: Theme.unit * 2
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 14
                    color: Theme.coralSoft
                    border.width: 1
                    border.color: Theme.coralLine
                    FpIcon { anchors.centerIn: parent; name: root.iconName; tone: "coral"; size: 22 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    RowLayout {
                        spacing: Theme.unit * 1.5
                        Text {
                            text: root.title
                            font.family: Theme.ui
                            font.pixelSize: Theme.body + 1
                            font.weight: Font.DemiBold
                            color: Theme.ivory
                        }
                        FpCostBadges {
                            costs: root.costs
                            visible: Object.keys(root.costs || {}).length > 0
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.subtitle
                        elide: Text.ElideRight
                        font.family: Theme.ui
                        font.pixelSize: Theme.small
                        color: Theme.dim
                        visible: text !== ""
                    }
                }
                FpSwitch {
                    id: headSwitch
                    visible: root.hasToggle
                    checked: root.checked
                    onToggled: (c) => root.toggled(c)
                }
                FpIcon {
                    name: root.expanded ? "chevron-up" : "chevron-down"
                    size: 20
                    opacity: 0.6
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.unit * 3
            Layout.rightMargin: Theme.unit * 3
            Layout.preferredHeight: 1
            color: Theme.line
            visible: body.visible
        }

        Item {
            id: body
            property real bodyH: root.expanded ? bodyCol.implicitHeight + Theme.unit * 3 : 0
            Behavior on bodyH { NumberAnimation { duration: Theme.duration; easing.type: Theme.easing } }
            Layout.fillWidth: true
            Layout.preferredHeight: bodyH
            visible: bodyH > 0.5
            clip: true
            ColumnLayout {
                id: bodyCol
                x: Theme.unit * 2
                y: Theme.unit
                width: parent.width - Theme.unit * 4
                spacing: 0
            }
        }
    }
}
