// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic

ComboBox {
    id: root
    // model: list of strings; currentIndex; activated(int) is inherited from ComboBox.
    implicitWidth: 260
    implicitHeight: 42
    activeFocusOnTab: true
    font.family: Theme.ui
    font.pixelSize: Theme.body - 1

    // Closed: Up/Down move to the neighbouring control (ComboBox would change its value);
    // Left/Right change the value. Open: the popup list is driven by the ComboBox itself.
    // The popup opens on key *release*: ComboBox closes an open popup on the Return release, and
    // the controller layer sends press+release back to back.
    property bool openOnRelease: false
    Keys.onReturnPressed: (e) => { if (popup.visible) e.accepted = false; else openOnRelease = true }
    Keys.onEnterPressed: (e) => { if (popup.visible) e.accepted = false; else openOnRelease = true }
    Keys.onReleased: (e) => {
        if (openOnRelease && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) {
            openOnRelease = false
            Qt.callLater(popup.open)
        } else e.accepted = false
    }
    Keys.onUpPressed: (e) => { if (popup.visible) e.accepted = false; else Theme.navMove(root.Window.window, "up") }
    Keys.onDownPressed: (e) => { if (popup.visible) e.accepted = false; else Theme.navMove(root.Window.window, "down") }
    Keys.onLeftPressed: (e) => { if (popup.visible) e.accepted = false; else if (currentIndex > 0) { currentIndex = currentIndex - 1; activated(currentIndex) } else e.accepted = false }
    Keys.onRightPressed: (e) => { if (popup.visible) e.accepted = false; else if (currentIndex < count - 1) { currentIndex = currentIndex + 1; activated(currentIndex) } else e.accepted = false }

    background: Rectangle {
        radius: height / 2
        color: Theme.graphite
        border.width: 1
        border.color: Theme.line
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.coral
            visible: root.activeFocus
        }
    }
    contentItem: Text {
        leftPadding: 18
        rightPadding: 38
        text: root.displayText
        font: root.font
        color: Theme.ivory
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: FpIcon {
        x: root.width - width - 14
        y: (root.height - height) / 2
        name: "chevron-down"
        size: 16
        opacity: 0.7
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
            leftPadding: 10
        }
        background: Rectangle {
            radius: height / 2
            color: Theme.ivory
            opacity: parent.highlighted ? 0.12 : 0
        }
    }
    popup: Popup {
        y: root.height + 6
        width: root.width
        padding: 4
        implicitHeight: contentItem.implicitHeight + 8
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }
        background: FpGlass {
            radius: 20
            fillAlpha: 0.94
        }
    }
}
