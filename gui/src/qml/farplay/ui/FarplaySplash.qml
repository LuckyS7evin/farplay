// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Shapes

// Startup animation (~1.3 s): night + coral glow, chevron, chevron, triangle
// (slight overshoot), then the word "Farplay". Skippable with any key/click.
// `t` is the timeline in ms; set it by hand (and stop `timeline`) to render frames.
FocusScope {
    id: root
    anchors.fill: parent
    focus: true

    signal finished()

    readonly property int holdAt: 1050     // everything is in place
    readonly property int totalMs: 1300    // end of the 250 ms fade-out
    property real t: 0
    property bool autoStart: true
    property real skipFade: 1
    readonly property real fade: Math.min(skipFade, t > holdAt ? 1 - (t - holdAt) / (totalMs - holdAt) : 1)

    // 0..1 progress of the window [a, b] ms
    function seg(a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))) }
    function outCubic(x) { return 1 - Math.pow(1 - x, 3) }
    function outBack(x) { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2) }

    readonly property real s: Math.max(96, Math.min(width, height) * 0.2)   // logo height
    readonly property real chev1: outCubic(seg(120, 420))
    readonly property real chev2: outCubic(seg(280, 580))
    readonly property real tri: seg(470, 830)
    readonly property real word: outCubic(seg(680, 1000))

    // Freeze the timeline at `ms` (screenshots / tests)
    function seek(ms) { timeline.stop(); skipAnim.stop(); t = ms }

    function skip() {
        if (skipAnim.running || t >= holdAt) return
        timeline.stop()
        skipAnim.start()
    }

    Component.onCompleted: if (autoStart) timeline.start()

    SequentialAnimation {
        id: timeline
        NumberAnimation { target: root; property: "t"; from: 0; to: root.totalMs; duration: root.totalMs }
        onFinished: root.finished()
    }
    NumberAnimation {
        id: skipAnim
        target: root; property: "skipFade"; to: 0; duration: 150
        onFinished: root.finished()
    }

    Keys.onPressed: (e) => { root.skip(); e.accepted = true }
    MouseArea { anchors.fill: parent; onPressed: root.skip() }

    Item {
        anchors.fill: parent
        opacity: root.fade

        Rectangle { anchors.fill: parent; color: "#0A0A0C" }
        // Subtle coral glow behind the mark
        Shape {
            anchors.fill: parent
            opacity: root.outCubic(root.seg(0, 600))
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: root.width / 2; centerY: root.height / 2
                    centerRadius: Math.max(root.width, root.height) * 0.42
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0.0; color: Qt.rgba(1, 0.42, 0.29, 0.26) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 0.42, 0.29, 0.06) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 0.42, 0.29, 0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
                PathLine { x: 0; y: 0 }
            }
        }

        // Mark + word, centred as one group (final layout, so nothing shifts)
        Item {
            id: group
            readonly property real gap: root.s * 0.32
            width: root.s * 1.35 + gap + wordText.implicitWidth
            height: root.s
            anchors.centerIn: parent
            // slow, tiny push-in over the whole intro
            layer.enabled: true
            layer.samples: 4
            scale: 0.97 + 0.03 * root.outCubic(root.seg(0, 1050))

            component Chevron: Shape {
                id: chev
                property real p: 0
                property real alpha: 0.3
                width: root.s * 0.3; height: root.s
                x: root.s * 0.05 - root.s * 0.14 * (1 - p)
                opacity: alpha * p
                ShapePath {
                    strokeColor: Theme.coral
                    strokeWidth: root.s * 0.09
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    startX: 0; startY: root.s * 0.22
                    PathLine { x: root.s * 0.2; y: root.s * 0.5 }
                    PathLine { x: 0; y: root.s * 0.78 }
                }
            }
            Chevron { p: root.chev1; alpha: 0.3 }
            Chevron { p: root.chev2; alpha: 0.6; x: root.s * 0.35 - root.s * 0.14 * (1 - p) }

            Shape {
                id: tri
                // starts over the chevrons, slides to its place with an overshoot
                readonly property real k: root.outBack(root.tri)
                x: root.s * (0.05 + 0.6 * k)
                width: root.s * 0.62; height: root.s
                opacity: Math.min(1, root.tri * 3)
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Theme.coral
                    startX: 0; startY: root.s * 0.12
                    PathLine { x: root.s * 0.62; y: root.s * 0.5 }
                    PathLine { x: 0; y: root.s * 0.88 }
                    PathLine { x: 0; y: root.s * 0.12 }
                }
            }

            Text {
                id: wordText
                x: root.s * 1.35 + group.gap + (1 - root.word) * root.s * 0.18
                anchors.verticalCenter: parent.verticalCenter
                text: "Farplay"
                opacity: root.word
                font.family: Theme.ui
                font.pixelSize: root.s * 0.62
                font.weight: Font.DemiBold
                font.letterSpacing: -root.s * 0.01
                color: Theme.ivory
            }
        }
    }
}
