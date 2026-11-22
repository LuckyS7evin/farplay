// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — pastille discrète « réseau instable » (haut droite, pendant la partie).
import QtQuick

FpGlass {
    width: row.implicitWidth + 32
    height: 44
    radius: 22
    fillAlpha: 0.82
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: Theme.coral }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Réseau instable"
            font.family: Theme.ui
            font.pixelSize: Theme.small + 1
            color: Theme.ivory
        }
    }
}
