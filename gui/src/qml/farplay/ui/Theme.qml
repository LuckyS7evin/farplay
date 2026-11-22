// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
pragma Singleton
import QtQuick
import org.streetpea.chiaking

QtObject {
    readonly property color night: "#0A0A0C"
    readonly property color graphite: "#17151A"
    readonly property color panel: Qt.rgba(0x17 / 255, 0x15 / 255, 0x1A / 255, 0.85)
    readonly property color coral: "#FF6B4A"
    readonly property color ivory: "#F5F1EE"
    readonly property color dim: "#9C969A"
    readonly property color mint: "#5DD39E"
    readonly property color alert: "#E5484D"
    readonly property color border: Qt.rgba(0xF5 / 255, 0xF1 / 255, 0xEE / 255, 0.15)

    readonly property string ui: Farplay.uiFont || "sans-serif"
    readonly property string mono: Farplay.monoFont || "monospace"

    readonly property int title: 34
    readonly property int body: 20
    readonly property int small: 15
    readonly property int unit: 8
    readonly property int radius: 14

    // No animation during a game session.
    readonly property bool animations: !Chiaki.session
    readonly property int duration: animations ? 200 : 0
    readonly property int slideDistance: animations ? 16 : 0
    readonly property int easing: Easing.OutCubic

    // Scrolls the enclosing Flickable (if any) so that `item` is fully visible.
    function ensureVisible(item) {
        var f = item.parent
        while (f && f.contentY === undefined)
            f = f.parent
        if (!f || !f.contentItem)
            return
        var p = item.mapToItem(f.contentItem, 0, 0)
        if (p.y < f.contentY)
            f.contentY = Math.max(0, p.y - 16)
        else if (p.y + item.height > f.contentY + f.height)
            f.contentY = p.y + item.height - f.height + 16
    }
}
