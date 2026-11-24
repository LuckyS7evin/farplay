// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls.Basic
import org.streetpea.chiaking

// Farplay replacement for chiaki-ng's confirm / info / "remind me" dialogs.
// Same contract as the old Main.qml dialogs: title, text, callback, rejectCallback,
// restoreFocusItem and open().
FocusScope {
    id: dlg
    property string title
    property string text
    property string mode: "confirm"          // "confirm" | "info" | "remind"
    property bool remotePlay: false          // remind mode: PSN reminder vs. other
    property var callback: null
    property var rejectCallback: null
    property Item restoreFocusItem: null
    property bool newDialogOpen: false
    readonly property bool opened: visible

    visible: false
    anchors.fill: parent
    z: 1000

    function show(m, t, body, cb, rejectCb, remote) {
        mode = m
        title = t
        text = body
        callback = cb
        rejectCallback = rejectCb || null
        remotePlay = !!remote
        newDialogOpen = false
        restoreFocusItem = Window.window ? Window.window.activeFocusItem : null
        open()
    }
    function open() {
        visible = true
        scrim.opacity = 0
        card.scale = 0.96
        appear.restart()
        dlg.forceActiveFocus()
        firstBtn.forceActiveFocus()
    }
    function restoreFocus() {
        if (restoreFocusItem) restoreFocusItem.forceActiveFocus(Qt.TabFocusReason)
    }
    function finish() {
        visible = false
    }
    function accept() {
        finish()
        newDialogOpen = true
        restoreFocus()
        if (callback) callback()
    }
    function reject() {
        finish()
        if (mode === "remind") {
            if (remotePlay) Chiaki.settings.remotePlayAsk = false
            else Chiaki.settings.addSteamShortcutAsk = false
            restoreFocus()
        } else if (mode === "confirm" && rejectCallback) {
            newDialogOpen = true
            restoreFocus()
            rejectCallback()
        } else {
            restoreFocus()
        }
    }
    // "Plus tard": close without remembering the answer.
    function later() {
        finish()
        restoreFocus()
    }
    function close() { if (mode === "remind") later(); else if (mode === "info") accept(); else reject() }

    ParallelAnimation {
        id: appear
        NumberAnimation { target: scrim; property: "opacity"; to: 1; duration: Theme.duration }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: Theme.duration; easing.type: Theme.easing }
    }

    Keys.onEscapePressed: dlg.close()

    // Scrim, swallows every pointer event while the dialog is open.
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.03, 0.72)
        MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }
    }

    FpGlass {
        id: card
        anchors.centerIn: parent
        width: Math.min(dlg.width - Theme.unit * 8, 640)
        height: Math.min(col.implicitHeight + Theme.unit * 8, dlg.height - Theme.unit * 6)
        radius: 28
        fillAlpha: 0.94

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.unit * 4
            spacing: Theme.unit * 2
            Text {
                Layout.fillWidth: true
                text: dlg.title
                wrapMode: Text.WordWrap
                font.family: Theme.ui
                font.pixelSize: Theme.title - 4
                font.weight: Font.DemiBold
                color: Theme.ivory
            }
            // Long messages scroll (wheel, touchpad, Up/Down on keyboard / D-pad) in small windows.
            Flickable {
                id: msgFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: msgText.implicitHeight
                Layout.minimumHeight: Math.min(msgText.implicitHeight, 60)
                contentWidth: width
                contentHeight: msgText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: FpScrollBar {}
                Text {
                    id: msgText
                    width: msgFlick.width - Theme.unit
                    text: dlg.text
                    wrapMode: Text.WordWrap
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                    lineHeight: 1.15
                    color: Theme.dim
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.unit * 2
                spacing: Theme.unit * 2
                Item { Layout.fillWidth: true }
                // confirm: Non / Oui ; remind: Plus tard / Non / Oui ; info: OK
                FpButton {
                    id: laterBtn
                    visible: dlg.mode === "remind"
                    text: "Plus tard"
                    flat: true
                    onClicked: dlg.later()
                    KeyNavigation.right: noBtn
                }
                FpButton {
                    id: noBtn
                    visible: dlg.mode !== "info"
                    text: "Non"
                    onClicked: dlg.reject()
                    KeyNavigation.left: laterBtn
                    KeyNavigation.right: yesBtn
                }
                FpButton {
                    id: yesBtn
                    primary: true
                    text: dlg.mode === "info" ? "OK" : "Oui"
                    onClicked: dlg.accept()
                    KeyNavigation.left: noBtn
                }
            }
        }
    }

    // Default focus on the affirmative action.
    readonly property Item firstBtn: yesBtn
    Keys.onLeftPressed: { if (dlg.mode !== "info") noBtn.forceActiveFocus() }
    Keys.onRightPressed: yesBtn.forceActiveFocus()
    Keys.onUpPressed: msgFlick.contentY = Math.max(0, msgFlick.contentY - 60)
    Keys.onDownPressed: msgFlick.contentY = Math.max(0, Math.min(msgFlick.contentHeight - msgFlick.height, msgFlick.contentY + 60))
}
