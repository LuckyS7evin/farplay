// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

// "Glass" surface: dark translucent fill, 1 px ivory hairline, rounded corners and a
// subtle top highlight. No real blur (the game video is not part of the QML scene).
Rectangle {
    id: root
    property real fillAlpha: 0.72
    property bool highlight: true
    radius: Theme.radiusPanel
    color: Qt.rgba(23 / 255, 21 / 255, 26 / 255, fillAlpha)
    border.width: 1
    border.color: Theme.line

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        visible: root.highlight
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassHighlight }
            GradientStop { position: 0.5; color: "transparent" }
        }
    }
}
