// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: root
    // model: list of strings; currentIndex; activated(int) is inherited from ComboBox.
    implicitWidth: 280
    implicitHeight: 44
    activeFocusOnTab: true
    font.family: Theme.ui
    font.pixelSize: Theme.body

    Keys.onReturnPressed: popup.open()
    Keys.onEnterPressed: popup.open()
    Keys.onLeftPressed: if (currentIndex > 0) { currentIndex = currentIndex - 1; activated(currentIndex) }
    Keys.onRightPressed: if (currentIndex < count - 1) { currentIndex = currentIndex + 1; activated(currentIndex) }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.graphite
        border.width: 1
        border.color: Theme.border
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: Theme.radius + 4
            color: "transparent"
            border.width: 2
            border.color: Theme.ivory
            visible: root.activeFocus
        }
    }
    contentItem: Text {
        leftPadding: 14
        rightPadding: 36
        text: root.displayText
        font: root.font
        color: Theme.ivory
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: root.width - width - 14
        y: (root.height - height) / 2
        text: "▾"
        font.pixelSize: Theme.small
        color: Theme.dim
    }
    delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: root.width - 8
        height: 40
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: modelData
            font: root.font
            color: Theme.ivory
            verticalAlignment: Text.AlignVCenter
            leftPadding: 6
        }
        background: Rectangle {
            radius: Theme.radius - 4
            color: Theme.ivory
            opacity: parent.highlighted ? 0.14 : 0
        }
    }
    popup: Popup {
        y: root.height + 4
        width: root.width
        padding: 4
        implicitHeight: contentItem.implicitHeight + 8
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }
        background: Rectangle {
            radius: Theme.radius
            color: Theme.graphite
            border.width: 1
            border.color: Theme.border
        }
    }
}
