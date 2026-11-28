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
                .arg(overlay.s.fpsDistinct > 0 ? overlay.n0(overlay.s.fpsDistinct) : overlay.n0(overlay.s.fpsOut))
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
                text: "%1 · %2%3".arg(overlay.s.hdr || "—").arg(overlay.s.primaries || "—")
                    .arg(overlay.s.srcPeakNits > 0 ? " · " + overlay.n0(overlay.s.srcPeakNits) + " nits" : "")
                color: overlay.s.hdrReceived ? overlay.cMint : overlay.cIvory
            }

            Key { text: "Sortie écran" }
            Val {
                text: overlay.s.output || "—"
                color: overlay.s.outHdr ? overlay.cMint : overlay.cIvory
            }

            Key { text: "Diagnostic HDR" }
            Val {
                text: overlay.s.hdrDiag || "—"
                color: overlay.s.hdrDiagLevel === 2 ? overlay.cAlert : (overlay.s.hdrDiagLevel === 0 ? overlay.cMint : overlay.cIvory)
            }

            Key { text: "Upscaling" }
            Val {
                text: "%1 · ×%2 → %3".arg(overlay.s.upscaler || "—").arg(overlay.s.upscaleFactor ? overlay.s.upscaleFactor.toFixed(2) : "—").arg(overlay.s.outResolution || "—")
            }

            Key { text: "GPU nettoyage (artefacts, couleur)" }
            Val {
                text: overlay.s.denoiseOn ? "%1 · p99 %2".arg(overlay.ms(overlay.s.gpuDenoiseAvg)).arg(overlay.ms(overlay.s.gpuDenoiseP99)) : "coupé"
                color: overlay.s.denoiseOn ? overlay.cIvory : overlay.cDim
            }

            Key { text: "Images reçues" }
            Val { text: "%1 fps · %2 / p99 %3".arg(overlay.n1(overlay.s.fpsIn)).arg(overlay.ms(overlay.s.srcIntervalAvg)).arg(overlay.ms(overlay.s.srcIntervalP99)) }

            Key { text: "Images affichées" }
            Val { text: "%1 fps · 1% low %2 · max %3".arg(overlay.n1(overlay.s.fpsOut)).arg(overlay.n1(overlay.s.fpsOut1Low)).arg(overlay.ms(overlay.s.dispIntervalMax)) }

            Key { text: "Pacing" }
            Val {
                text: overlay.s.pacingOn
                    ? "lissé · marge %1 ms · son +%2 ms".arg(overlay.n0(overlay.s.pacingMarginMs)).arg(overlay.n0(overlay.s.audioDelayMs))
                    : "à l'arrivée (lissage coupé)"
                color: overlay.s.pacingOn ? overlay.cMint : overlay.cDim
            }

            Key { text: "GPU décodage" }
            Val { text: "n/d (phase 2)"; color: overlay.cDim }

            Key { text: "GPU rendu source" }
            Val { text: "%1 · p99 %2".arg(overlay.ms(overlay.s.gpuFrameAvg)).arg(overlay.ms(overlay.s.gpuFrameP99)) }

            Key { text: "GPU upscaling" }
            Val {
                text: overlay.s.gpuUpscaleAvg > 0 ? "%1 · p99 %2 / %3 ms".arg(overlay.ms(overlay.s.gpuUpscaleAvg)).arg(overlay.ms(overlay.s.gpuUpscaleP99)).arg(overlay.n0(overlay.s.upscaleBudget)) : "—"
                color: overlay.s.upscaleOverBudget ? overlay.cAlert : overlay.cIvory
            }

            Key { text: "Génération d'images" }
            Val {
                text: overlay.s.fgActive
                    ? "%1 · +%2 fps · latence +%3 ms · %4 rendus/s".arg(overlay.s.fgState).arg(overlay.n0(overlay.s.fpsGen)).arg(overlay.n0(overlay.s.fgDelayMs)).arg(overlay.n0(overlay.s.fgCallsPerSec))
                    : (overlay.s.fgState || "—") + (overlay.s.fgCallsPerSec > 0 ? " · %1 rendus/s".arg(overlay.n0(overlay.s.fgCallsPerSec)) : "")
                color: overlay.s.fgActive ? overlay.cMint : overlay.cIvory
            }

            Key { text: "Attente FG"; visible: !!overlay.s.fgWaitDetail && overlay.s.fgWaitPct > 0 }
            Val { text: overlay.s.fgWaitDetail || ""; color: overlay.cDim; visible: !!overlay.s.fgWaitDetail && overlay.s.fgWaitPct > 0 }

            Key { text: "Moteur FG" }
            Val {
                text: (FarplayFrameGen.engine === 1 ? "AMD " + (overlay.s.fsrStatus || FarplayFrameGen.fsrStatus || "FSR") + (FarplayFrameGen.fsrMotion === 1 ? " · guidé par le flux Farplay" : "") : "Farplay (flux optique maison)") + (overlay.s.sceneCuts > 0 ? " · " + overlay.s.sceneCuts + " changements de plan" : "") + (overlay.s.dupSeen > 0 ? " · doublons " + overlay.s.dupDropped + "/" + overlay.s.dupSeen + " écartés" : "")
                color: (overlay.s.fsrStatus || "").indexOf("erreur") >= 0 || (overlay.s.fsrStatus || "").indexOf("indisponible") >= 0 ? overlay.cAlert : overlay.cIvory
            }

            Key { text: "File FG"; visible: overlay.s.fgActive !== undefined && !!overlay.s.fgQueueDetail }
            Val { text: overlay.s.fgQueueDetail || ""; color: overlay.cDim; wrapMode: Text.WordWrap; Layout.maximumWidth: 520; visible: !!overlay.s.fgQueueDetail }

            Key { text: "GPU frame gen" }
            Val {
                text: overlay.s.fgActive
                    ? "%1 / 4 ms (flux %2 · synthèse %3)".arg(overlay.ms(overlay.s.fgCostMs)).arg(overlay.ms(overlay.s.fgFlowMs)).arg(overlay.ms(overlay.s.fgSynthMs))
                    : "—"
                color: overlay.s.fgOverBudget ? overlay.cAlert : overlay.cIvory
            }

            Key { text: "GPU composition" }
            Val { text: overlay.s.gpuBlendAvg > 0 ? "%1 · p99 %2".arg(overlay.ms(overlay.s.gpuBlendAvg)).arg(overlay.ms(overlay.s.gpuBlendP99)) : "non utilisée"; color: overlay.s.gpuBlendAvg > 0 ? overlay.cIvory : overlay.cDim }

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

            Key { text: "Débit" }
            Val {
                text: "%1 Mbps · cible PS5 %2 · demandé %3".arg(overlay.n1(overlay.s.bitrate))
                    .arg(overlay.s.targetBitrate > 0 ? overlay.n1(overlay.s.targetBitrate) : "—")
                    .arg(overlay.n0(overlay.s.requestedBitrate))
            }

            Key { text: "Réseau" }
            Val { text: "RTT %1 ms".arg(overlay.n1(overlay.s.rttMs)) }

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
