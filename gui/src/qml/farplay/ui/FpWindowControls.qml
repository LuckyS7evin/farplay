// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — fenêtre sans barre de titre Windows : zone de déplacement en haut,
// boutons réduire / agrandir / fermer intégrés, bords de redimensionnement.
// Masqué en plein écran. Pendant une partie en fenêtre, n'apparaît qu'au survol.
import QtQuick
import org.streetpea.chiaking

Item {
    id: wc
    anchors.fill: parent

    readonly property var win: Chiaki.window
    readonly property bool fullscreen: win.visibility === Window.FullScreen
    readonly property bool maximized: win.visibility === Window.Maximized
    readonly property bool inGame: !!Chiaki.session
    readonly property int barH: 32
    readonly property int grip: 6

    visible: !fullscreen

    function toggleMax() {
        if (maximized) win.showNormal(); else win.showMaximized();
    }

    component WinButton: Rectangle {
        id: b
        property bool danger: false
        property alias hovered: ma.containsMouse
        signal clicked()
        width: 46
        height: wc.barH
        color: ma.containsMouse ? (danger ? Theme.alert : Theme.glassHighlight) : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: b.clicked()
        }
    }

    // ── Zone de déplacement ───────────────────────────────────────────────
    MouseArea {
        id: dragArea
        x: 0; y: 0
        width: parent.width - buttons.width
        height: wc.barH
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: wc.win.startSystemMove()
        onDoubleClicked: wc.toggleMax()
    }

    // ── Boutons ───────────────────────────────────────────────────────────
    Row {
        id: buttons
        anchors.top: parent.top
        anchors.right: parent.right
        opacity: !wc.inGame || dragArea.containsMouse || minBtn.hovered || maxBtn.hovered || closeBtn.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        WinButton {
            id: minBtn
            onClicked: wc.win.showMinimized()
            Rectangle {
                anchors.centerIn: parent
                width: 10; height: 1
                color: Theme.ivory
            }
        }
        WinButton {
            id: maxBtn
            onClicked: wc.toggleMax()
            // Agrandir : un carré ; restaurer : deux carrés décalés
            Rectangle {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: wc.maximized ? -1 : 0
                anchors.verticalCenterOffset: wc.maximized ? 1 : 0
                width: wc.maximized ? 8 : 10; height: width
                color: "transparent"
                border.color: Theme.ivory
                border.width: 1
            }
            Rectangle {
                visible: wc.maximized
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                anchors.verticalCenterOffset: -1
                width: 8; height: 8
                color: "transparent"
                border.color: Theme.ivory
                border.width: 1
                z: -1
            }
        }
        WinButton {
            id: closeBtn
            danger: true
            onClicked: wc.win.close()
            Repeater {
                model: [45, -45]
                Rectangle {
                    required property int modelData
                    anchors.centerIn: parent
                    width: 13; height: 1
                    antialiasing: true
                    rotation: modelData
                    color: Theme.ivory
                }
            }
        }
    }

    // ── Bords de redimensionnement (fenêtre normale seulement) ────────────
    component Grip: MouseArea {
        property int edges: 0
        enabled: !wc.maximized && !wc.fullscreen
        onPressed: wc.win.startSystemResize(edges)
    }
    Grip { edges: Qt.LeftEdge; x: 0; y: wc.grip; width: wc.grip; height: parent.height - 2 * wc.grip; cursorShape: Qt.SizeHorCursor }
    Grip { edges: Qt.RightEdge; x: parent.width - wc.grip; y: wc.grip; width: wc.grip; height: parent.height - 2 * wc.grip; cursorShape: Qt.SizeHorCursor }
    Grip { edges: Qt.BottomEdge; x: wc.grip; y: parent.height - wc.grip; width: parent.width - 2 * wc.grip; height: wc.grip; cursorShape: Qt.SizeVerCursor }
    Grip { edges: Qt.TopEdge; x: wc.grip; y: 0; width: parent.width - buttons.width - wc.grip; height: 3; cursorShape: Qt.SizeVerCursor }
    Grip { edges: Qt.TopEdge | Qt.LeftEdge; x: 0; y: 0; width: wc.grip; height: wc.grip; cursorShape: Qt.SizeFDiagCursor }
    Grip { edges: Qt.TopEdge | Qt.RightEdge; x: parent.width - wc.grip; y: 0; width: wc.grip; height: wc.grip; cursorShape: Qt.SizeBDiagCursor }
    Grip { edges: Qt.BottomEdge | Qt.LeftEdge; x: 0; y: parent.height - wc.grip; width: wc.grip; height: wc.grip; cursorShape: Qt.SizeBDiagCursor }
    Grip { edges: Qt.BottomEdge | Qt.RightEdge; x: parent.width - wc.grip; y: parent.height - wc.grip; width: wc.grip; height: wc.grip; cursorShape: Qt.SizeFDiagCursor }
}
