// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — overlay de statistiques en jeu (F3 : masqué / compact / détaillé).
// Aucune animation : l'overlay est affiché pendant la session de jeu.
import QtQuick
import QtQuick.Layouts

import org.streetpea.chiaking

Rectangle {
    id: overlay

    readonly property var s: Farplay.snapshot
    readonly property bool detailed: Farplay.overlayLevel >= 2

    // Palette Farplay
    readonly property color cGraphite: "#17151A"
    readonly property color cIvory: "#F5F1EE"
    readonly property color cMint: "#5DD39E"
    readonly property color cAlert: "#E5484D"
    readonly property color cDim: "#9C969A"
    readonly property string mono: Farplay.monoFont

    component Key: Text { font.family: overlay.mono; font.pixelSize: 13; color: overlay.cDim }
    component Val: Text { font.family: overlay.mono; font.pixelSize: 13; color: overlay.cIvory; Layout.alignment: Qt.AlignRight }

    function ms(v) { return (v === undefined || v <= 0) ? "—" : v.toFixed(2) + " ms" }
    function n0(v) { return v === undefined ? "—" : v.toFixed(0) }
    function n1(v) { return v === undefined ? "—" : v.toFixed(1) }

    color: Qt.rgba(0x17 / 255, 0x15 / 255, 0x1A / 255, 0.82)
    radius: 8
    border.color: s.overBudget ? cAlert : "transparent"
    border.width: s.overBudget ? 1 : 0
    implicitWidth: content.implicitWidth + 24
    implicitHeight: content.implicitHeight + 16
    width: implicitWidth
    height: implicitHeight

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        spacing: 2

        // Ligne compacte (toujours visible quand l'overlay est actif)
        Text {
            font.family: overlay.mono
            font.pixelSize: 15
            color: overlay.s.overBudget ? overlay.cAlert : overlay.cIvory
            text: "%1 → %2 fps · GPU %3 · %4 Mbps · %5"
                .arg(overlay.n0(overlay.s.fpsIn))
                .arg(overlay.n0(overlay.s.fpsOut))
                .arg(overlay.s.gpuTimingAvailable ? overlay.ms(overlay.s.gpuTotal) : "n/d")
                .arg(overlay.n1(overlay.s.bitrate))
                .arg(overlay.s.hdr || "—")
        }

        GridLayout {
            visible: overlay.detailed
            columns: 2
            columnSpacing: 16
            rowSpacing: 1
            Layout.topMargin: 6

            Key { text: "Flux" }
            Val { text: "%1 · %2 bits".arg(overlay.s.resolution || "—").arg(overlay.s.bitDepth || "—") }

            Key { text: "Décodeur" }
            Val {
                text: (overlay.s.decoder || "—") + (overlay.s.zeroCopy ? " · zero-copy" : " · copie")
                color: overlay.s.zeroCopy ? overlay.cMint : overlay.cAlert
            }

            Key { text: "HDR reçu" }
            Val {
                text: "%1 · %2".arg(overlay.s.hdr || "—").arg(overlay.s.primaries || "—")
                color: overlay.s.hdrReceived ? overlay.cMint : overlay.cIvory
            }

            Key { text: "Images reçues" }
            Val { text: "%1 fps · %2 / p99 %3".arg(overlay.n1(overlay.s.fpsIn)).arg(overlay.ms(overlay.s.srcIntervalAvg)).arg(overlay.ms(overlay.s.srcIntervalP99)) }

            Key { text: "Images affichées" }
            Val { text: "%1 fps · p99 %2 · max %3".arg(overlay.n1(overlay.s.fpsOut)).arg(overlay.ms(overlay.s.dispIntervalP99)).arg(overlay.ms(overlay.s.dispIntervalMax)) }

            Key { text: "GPU décodage" }
            Val { text: "n/d (phase 2)"; color: overlay.cDim }

            Key { text: "GPU rendu source" }
            Val { text: "%1 · p99 %2".arg(overlay.ms(overlay.s.gpuFrameAvg)).arg(overlay.ms(overlay.s.gpuFrameP99)) }

            Key { text: "GPU composition" }
            Val { text: "%1 · p99 %2".arg(overlay.ms(overlay.s.gpuBlendAvg)).arg(overlay.ms(overlay.s.gpuBlendP99)) }

            Key { text: "GPU total / image" }
            Val {
                text: "%1 / %2 ms".arg(overlay.ms(overlay.s.gpuTotal)).arg(overlay.n0(overlay.s.budgetTotal))
                color: overlay.s.overBudget ? overlay.cAlert : overlay.cMint
            }

            Key { text: "Présentation" }
            Val {
                text: (overlay.s.presentMode || "—") + (overlay.s.presentFallback ? " (repli)" : "")
                color: overlay.s.presentFallback ? overlay.cAlert : overlay.cIvory
            }

            Key { text: "Réseau" }
            Val { text: "%1 Mbps · RTT %2 ms".arg(overlay.n1(overlay.s.bitrate)).arg(overlay.n1(overlay.s.rttMs)) }

            Key { text: "Pertes" }
            Val {
                text: "%1 % paquets · %2 images".arg(overlay.n1(overlay.s.packetLoss)).arg(overlay.s.framesLost === undefined ? "—" : overlay.s.framesLost)
                color: (overlay.s.packetLoss > 1 || overlay.s.framesLost > 0) ? overlay.cAlert : overlay.cIvory
            }

            Key { text: "Journal CSV" }
            Val { text: Farplay.csvLogging ? "actif" : "coupé"; color: Farplay.csvLogging ? overlay.cMint : overlay.cDim }

            Key { text: "Build" }
            Val { text: Farplay.buildId; color: overlay.cDim }
        }
    }
}
