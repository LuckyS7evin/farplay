// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — carte de dialogue en jeu (verre sombre, titre, message, zone d'actions).
import QtQuick
import QtQuick.Layouts

FpGlass {
    id: root
    property string title
    property string message
    property string tone: "ivory"          // "alert" : pastille d'alerte devant le titre
    default property alias content: slot.data

    implicitWidth: 600
    implicitHeight: col.implicitHeight + 72
    radius: 28
    fillAlpha: 0.94

    ColumnLayout {
        id: col
        x: 36
        y: 36
        width: parent.width - 72
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Rectangle {
                visible: root.tone === "alert"
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: Qt.rgba(0.9, 0.28, 0.3, 0.18)
                border.width: 1
                border.color: Qt.rgba(0.9, 0.28, 0.3, 0.6)
                Text { anchors.centerIn: parent; text: "!"; font.family: Theme.ui; font.pixelSize: 18; font.weight: Font.Bold; color: Theme.alert }
            }
            Text {
                Layout.fillWidth: true
                text: root.title
                wrapMode: Text.WordWrap
                font.family: Theme.ui
                font.pixelSize: Theme.title - 4
                font.weight: Font.DemiBold
                color: Theme.ivory
            }
        }
        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.message
            wrapMode: Text.WordWrap
            font.family: Theme.ui
            font.pixelSize: Theme.body
            color: Theme.dim
        }
        Item {
            id: slot
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.preferredHeight: childrenRect.height
        }
    }
}
