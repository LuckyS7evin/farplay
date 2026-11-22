// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

Item {
    id: root
    property real size: 48
    property bool animateIntro: false
    property real progress: animateIntro ? 0 : 1

    implicitWidth: size * 1.35
    implicitHeight: size
    onProgressChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
    Component.onCompleted: if (animateIntro) introAnim.start()

    NumberAnimation {
        id: introAnim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 250
        easing.type: Easing.OutCubic
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var s = root.size, p = root.progress
            function chevron(x, alpha) {
                ctx.strokeStyle = Qt.rgba(1, 0.42, 0.29, alpha)
                ctx.lineWidth = s * 0.09
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(x, s * 0.22)
                ctx.lineTo(x + s * 0.2, s * 0.5)
                ctx.lineTo(x, s * 0.78)
                ctx.stroke()
            }
            chevron(s * 0.05, 0.3 * p)
            chevron(s * 0.35, 0.6 * p)
            var tx = s * 0.65 * p + s * 0.05 * (1 - p)
            ctx.fillStyle = "#FF6B4A"
            ctx.beginPath()
            ctx.moveTo(tx, s * 0.12)
            ctx.lineTo(tx + s * 0.62, s * 0.5)
            ctx.lineTo(tx, s * 0.88)
            ctx.closePath()
            ctx.fill()
        }
    }
}
