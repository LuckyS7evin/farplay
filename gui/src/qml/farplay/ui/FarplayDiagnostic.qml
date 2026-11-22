// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import org.streetpea.chiaking

FocusScope {
    id: page
    anchors.fill: parent

    readonly property var s: Farplay.snapshot || ({})
    readonly property bool active: !!Chiaki.session

    function num(v, digits, unit) {
        return (v === undefined || v === null) ? "—" : Number(v).toFixed(digits) + (unit ? " " + unit : "")
    }
    readonly property string hdrCause: s.hdrDiagLevel === 2 ? (s.hdrDiag || "Problème HDR") : ""
    readonly property string netCause: s.packetLoss > 1 ? "Pertes réseau : préférez l'Ethernet ou rapprochez-vous du routeur" : ""
    readonly property string imgCause: s.srcIntervalP99 > 50 ? "Images en retard depuis la PS5 ou le réseau : saccades possibles" : ""
    readonly property string gpuCause: s.gpuTotal > 8 ? "GPU au-delà du budget : baissez l'upscaling ou la frame gen" : ""

    component Group: ColumnLayout {
        id: g
        property string title
        property string cause
        default property alias rows: rowsCol.data
        Layout.fillWidth: true
        spacing: Theme.unit
        Text {
            Layout.topMargin: Theme.unit * 2
            text: g.title
            font.family: Theme.ui
            font.pixelSize: Theme.small
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.5
            color: Theme.dim
        }
        FpCard {
            Layout.fillWidth: true
            implicitHeight: rowsCol.implicitHeight + Theme.unit * 5 + causeText.implicitHeight
            ColumnLayout {
                id: rowsCol
                width: parent.width
                spacing: 6
            }
            Text {
                id: causeText
                anchors.bottom: parent.bottom
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Cause probable : " + (g.cause !== "" ? g.cause : "RAS")
                font.family: Theme.ui
                font.pixelSize: Theme.small
                color: g.cause !== "" ? Theme.alert : Theme.mint
            }
        }
    }
    component Line: RowLayout {
        property string label
        property string value
        property color tone: Theme.ivory
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: parent.label
            font.family: Theme.ui
            font.pixelSize: Theme.body
            color: Theme.dim
        }
        Text {
            text: parent.value
            font.family: Theme.mono
            font.pixelSize: Theme.body
            color: parent.tone
        }
    }

    Keys.onEscapePressed: root.showMainView()
    Component.onCompleted: backBtn.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Theme.night }

    RowLayout {
        id: header
        x: Theme.unit * 5
        y: Theme.unit * 3
        width: parent.width - Theme.unit * 10
        spacing: Theme.unit * 2
        FpButton { id: backBtn; text: "‹ Retour"; onClicked: root.showMainView() }
        Text {
            Layout.fillWidth: true
            text: "Diagnostic"
            font.family: Theme.ui
            font.pixelSize: Theme.title
            color: Theme.ivory
        }
    }

    Text {
        visible: !page.active
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.unit * 10, 700)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Aucune session en cours — lancez une partie pour voir le diagnostic."
        font.family: Theme.ui
        font.pixelSize: Theme.body
        color: Theme.dim
    }

    ScrollView {
        id: scroll
        visible: page.active
        anchors.top: header.bottom
        anchors.topMargin: Theme.unit * 2
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - Theme.unit * 10, 900)
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Theme.unit

            Group {
                title: "HDR"
                cause: page.hdrCause
                Line { label: "HDR reçu"; value: page.s.hdr ? "Oui" : "Non"; tone: page.s.hdr ? Theme.mint : Theme.ivory }
                Line { label: "Primaires"; value: String(page.s.primaries ?? "—") }
                Line { label: "Sortie"; value: String(page.s.output ?? "—") }
                Line {
                    label: "Diagnostic"
                    value: String(page.s.hdrDiag ?? "—")
                    tone: page.s.hdrDiagLevel === 2 ? Theme.alert : (page.s.hdrDiagLevel === 0 ? Theme.mint : Theme.ivory)
                }
            }
            Group {
                title: "Réseau"
                cause: page.netCause
                Line { label: "Latence réseau (RTT)"; value: page.num(page.s.rttMs, 0, "ms") }
                Line { label: "Débit"; value: page.num(page.s.bitrate, 1, "Mbps") }
                Line { label: "Débit cible"; value: page.num(page.s.targetBitrate, 1, "Mbps") }
                Line { label: "Pertes de paquets"; value: page.num(page.s.packetLoss, 2, "%"); tone: page.s.packetLoss > 1 ? Theme.alert : Theme.ivory }
                Line { label: "Images perdues"; value: page.num(page.s.framesLost, 0) }
            }
            Group {
                title: "Images"
                cause: page.imgCause
                Line { label: "Cadence reçue"; value: page.num(page.s.fpsIn, 1, "fps") }
                Line { label: "Cadence affichée"; value: page.num(page.s.fpsOut, 1, "fps") }
                Line { label: "Intervalle source (p99)"; value: page.num(page.s.srcIntervalP99, 1, "ms"); tone: page.s.srcIntervalP99 > 50 ? Theme.alert : Theme.ivory }
                Line { label: "Intervalle écran (p99)"; value: page.num(page.s.dispIntervalP99, 1, "ms") }
            }
            Group {
                title: "GPU"
                cause: page.gpuCause
                Line { label: "Upscaling"; value: String(page.s.upscaler ?? "—") }
                Line { label: "GPU total"; value: page.num(page.s.gpuTotal, 1, "ms"); tone: page.s.gpuTotal > 8 ? Theme.alert : Theme.ivory }
                Line { label: "Frame gen"; value: String(page.s.fgState ?? "—") }
                Line { label: "Images générées"; value: page.num(page.s.fpsGen, 1, "fps") }
                Line { label: "Coût frame gen"; value: page.num(page.s.fgCostMs, 2, "ms") }
                Line { label: "Délai frame gen"; value: page.num(page.s.fgDelayMs, 1, "ms") }
            }
            Item { Layout.preferredHeight: Theme.unit * 6 }
        }
    }
}
