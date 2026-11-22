// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

// Row of PlayStation button hints. model: [["✕", "Valider"], ["○", "Retour"]]
Row {
    id: root
    property var model: []
    property int fontSize: Theme.small
    spacing: Theme.unit * 3

    function glyphColor(g) {
        return g === "✕" ? "#7FA6DC" : g === "○" ? "#EB6F78" : g === "△" ? "#4FC1A6" : g === "□" ? "#DB88BA" : Theme.ivory
    }

    Repeater {
        model: root.model
        delegate: Row {
            required property var modelData
            spacing: 8
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: Qt.rgba(0, 0, 0, 0.35)
                border.width: 1
                border.color: Theme.line
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: modelData[0]
                    font.pixelSize: root.fontSize + 1
                    color: root.glyphColor(modelData[0])
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData[1]
                font.family: Theme.ui
                font.pixelSize: root.fontSize
                color: Theme.dim
            }
        }
    }
}
