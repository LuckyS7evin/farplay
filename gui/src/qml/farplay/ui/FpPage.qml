// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls.Basic
import org.streetpea.chiaking

// Full-screen Farplay page frame used by every secondary screen (registration, PSN,
// console form...): night background, back button + title, centred scrolling column, hints.
FocusScope {
    id: page
    property string title
    property string subtitle
    property string backText: "Retour"
    property bool showBack: true
    property real columnWidth: 760
    property var hints: [["✕", "Valider"], ["○", "Retour"]]
    property alias flick: flick
    property alias backButton: backBtn
    property bool scrollable: true
    default property alias content: body.data
    signal back()

    anchors.fill: parent

    function firstFocusable(it) {
        for (var i = 0; i < it.children.length; i++) {
            var c = it.children[i]
            if (!c.visible || !c.enabled) continue
            if (c.activeFocusOnTab === true) return c
            var r = firstFocusable(c)
            if (r) return r
        }
        return null
    }
    function focusFirst() {
        var f = firstFocusable(body)
        if (f) f.forceActiveFocus(); else backBtn.forceActiveFocus()
    }

    Keys.onEscapePressed: page.back()

    Rectangle { anchors.fill: parent; color: Theme.night }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 0.42, 0.29, 0.10) }
            GradientStop { position: 0.45; color: "transparent" }
        }
    }

    // Header
    Item {
        id: header
        x: Math.max(Theme.unit * 4, (page.width - page.columnWidth) / 2 - Theme.unit * 4)
        y: Theme.unit * 4
        width: Math.min(page.width - x * 2, page.columnWidth + Theme.unit * 8)
        height: 72
        z: 2
        FpButton {
            id: backBtn
            visible: page.showBack
            anchors.verticalCenter: parent.verticalCenter
            iconName: "back"
            text: page.backText
            onClicked: page.back()
            Keys.onDownPressed: page.focusFirst()
        }
        Column {
            anchors.left: page.showBack ? backBtn.right : parent.left
            anchors.leftMargin: Theme.unit * 3
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                width: parent.width
                text: page.title
                elide: Text.ElideRight
                font.family: Theme.ui
                font.pixelSize: Theme.title
                font.weight: Font.DemiBold
                color: Theme.ivory
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: page.subtitle
                elide: Text.ElideRight
                font.family: Theme.ui
                font.pixelSize: Theme.body - 2
                color: Theme.dim
            }
        }
    }

    Flickable {
        id: flick
        anchors.top: header.bottom
        anchors.topMargin: Theme.unit * 2
        anchors.bottom: hintBar.top
        anchors.bottomMargin: Theme.unit * 2
        anchors.left: parent.left
        anchors.right: parent.right
        contentWidth: width
        contentHeight: body.implicitHeight + Theme.unit * 4
        interactive: page.scrollable
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: FpScrollBar {}

        ColumnLayout {
            id: body
            x: (flick.width - width) / 2
            y: Theme.unit
            width: Math.min(page.columnWidth, flick.width - Theme.unit * 8)
            spacing: Theme.unit * 3
        }
    }

    Item {
        id: hintBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.unit * 3
        x: header.x
        width: header.width
        height: 32
        FpHints { model: page.hints }
    }
}
