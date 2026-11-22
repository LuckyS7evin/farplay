// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
pragma Singleton
import QtQuick
import org.streetpea.chiaking

QtObject {
    readonly property color night: "#0A0A0C"
    readonly property color side: "#0E0D11"
    readonly property color graphite: "#17151A"
    readonly property color raised: "#211E25"
    readonly property color panel: Qt.rgba(0x17 / 255, 0x15 / 255, 0x1A / 255, 0.85)
    readonly property color coral: "#FF6B4A"
    readonly property color coralSoft: Qt.rgba(1, 0.42, 0.29, 0.16)
    readonly property color coralLine: Qt.rgba(1, 0.42, 0.29, 0.55)
    readonly property color ivory: "#F5F1EE"
    readonly property color dim: "#9C969A"
    readonly property color mint: "#5DD39E"
    readonly property color alert: "#E5484D"
    readonly property color border: Qt.rgba(0xF5 / 255, 0xF1 / 255, 0xEE / 255, 0.15)
    // 1 px hairlines on glass surfaces (ivory ~10 %)
    readonly property color line: Qt.rgba(0xF5 / 255, 0xF1 / 255, 0xEE / 255, 0.10)
    readonly property color glass: Qt.rgba(23 / 255, 21 / 255, 26 / 255, 0.72)
    readonly property color glassHighlight: Qt.rgba(0xF5 / 255, 0xF1 / 255, 0xEE / 255, 0.07)

    readonly property string ui: Farplay.uiFont || "sans-serif"
    readonly property string mono: Farplay.monoFont || "monospace"
    // "qrc:/farplay/icons/ui/" in production; the screenshot harness overrides it.
    readonly property string iconBase: Farplay.iconBase || "qrc:/farplay/icons/ui/"

    readonly property int title: 32
    readonly property int body: 18
    readonly property int small: 14
    readonly property int unit: 8
    readonly property int radius: 14
    readonly property int radiusPanel: 22

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
