// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

Flow {
    id: root
    // e.g. { image: "+", fluidite: "+", latence: "−", gpu: "+" }
    property var costs: ({})
    spacing: Theme.unit

    readonly property var labels: ({ image: "Image", fluidite: "Fluidité", latence: "Latence", gpu: "GPU" })
    readonly property var order: ["image", "fluidite", "latence", "gpu"]
    // For latency and GPU a "+" is a cost; for image and fluidity it is a benefit.
    readonly property var costKeys: ["latence", "gpu"]

    function chipColor(key, v) {
        if (v !== "+" && v !== "−" && v !== "-")
            return Theme.dim
        var plus = v === "+"
        var costly = costKeys.indexOf(key) >= 0 ? plus : !plus
        return costly ? Theme.alert : Theme.mint
    }

    Repeater {
        model: root.order.filter(function(k) { return root.costs && root.costs[k] !== undefined })
        delegate: Rectangle {
            required property string modelData
            readonly property color tone: root.chipColor(modelData, root.costs[modelData])
            implicitWidth: chipText.implicitWidth + 16
            implicitHeight: chipText.implicitHeight + 6
            radius: height / 2
            color: Qt.rgba(tone.r, tone.g, tone.b, 0.15)
            border.width: 1
            border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.5)
            Text {
                id: chipText
                anchors.centerIn: parent
                text: root.labels[modelData] + " " + root.costs[modelData]
                font.family: Theme.ui
                font.pixelSize: Theme.small
                color: parent.tone
            }
        }
    }
}
