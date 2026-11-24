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

    // ── Scrolling ──────────────────────────────────────────────────────────
    // Scrolls every enclosing Flickable so that `item` (or the row that holds it) is fully visible.
    function ensureVisible(item) {
        if (!item) return
        var target = item
        for (var q = item.parent, n = 0; q && n < 3; q = q.parent, n++) {
            if (q.fpScrollTarget === true) { target = q; break }
        }
        var f = item.parent
        var guard = 0
        while (f && guard++ < 32) {
            if (f.contentY !== undefined && f.contentItem && f.contentHeight > f.height + 1) {
                var p = target.mapToItem(f.contentItem, 0, 0)
                var m = 16
                var maxY = Math.max(0, f.contentHeight - f.height)
                var y = f.contentY
                if (target.height + 2 * m >= f.height) y = p.y - m
                else if (p.y - m < y) y = p.y - m
                else if (p.y + target.height + m > y + f.height) y = p.y + target.height + m - f.height
                f.contentY = Math.max(0, Math.min(maxY, y))
            }
            f = f.parent
        }
    }

    // ── Keyboard / controller spatial navigation ─────────────────────────────
    // chiaki-ng turns pad buttons into Key_Up/Down/Left/Right/Return/Escape events sent to the
    // window (qmlcontroller.cpp). Controls consume Left/Right when they change a value; every
    // other arrow press reaches Main.qml's root, which calls handleKey(): the next focusable
    // control (activeFocusOnTab) of the current Farplay screen is picked geometrically.
    function isFp(o) { return /^(Farplay|Fp)/.test(String(o)) }
    function navRoot(item) {
        var r = null
        for (var p = item; p; p = p.parent) {
            if (p.fpNavRoot === true) return p
            if (isFp(p)) r = p
        }
        return r
    }
    function navTargets(it, out) {
        for (var i = 0; i < it.children.length; i++) {
            var c = it.children[i]
            if (!c.visible || !c.enabled) continue
            if (c.activeFocusOnTab === true && c.width > 0 && c.height > 0) out.push(c)
            navTargets(c, out)
        }
        return out
    }
    // Up/Down never leave a "group" (an ancestor with `property bool fpNavGroup: true`, e.g. the sidebar).
    function navGroup(it, root) {
        for (var p = it; p && p !== root; p = p.parent)
            if (p.fpNavGroup === true) return p
        return null
    }
    // Rect of `it` in `root` coordinates, as if every enclosing Flickable were scrolled to its top
    // (scrolled content slides under fixed headers; the layout order must not depend on the scroll).
    function navRect(it, root) {
        var fl = it.parent
        while (fl && fl !== root && fl.contentY === undefined) fl = fl.parent
        var x, y
        if (fl && fl !== root && fl.contentItem) {
            var p = it.mapToItem(fl.contentItem, 0, 0)
            var f0 = fl.mapToItem(root, 0, 0)
            x = f0.x + p.x - fl.contentX
            y = f0.y + p.y
        } else {
            var q = it.mapToItem(root, 0, 0)
            x = q.x; y = q.y
        }
        return { x: x, y: y, w: it.width, h: it.height, cx: x + it.width / 2, cy: y + it.height / 2 }
    }
    // Next focusable item from `cur` in direction "up" | "down" | "left" | "right" (or null).
    function navNext(cur, dir, root, sameGroup) {
        var cr = navRect(cur, root)
        var list = navTargets(root, [])
        var grp = navGroup(cur, root)
        var best = null, bestScore = 1e12
        for (var i = 0; i < list.length; i++) {
            var c = list[i]
            if (c === cur) continue
            if (sameGroup && navGroup(c, root) !== grp) continue
            var r = navRect(c, root)
            var score
            if (dir === "up" || dir === "down") {
                var d = (r.cy - cr.cy) * (dir === "down" ? 1 : -1)
                var ov = Math.min(cr.y + cr.h, r.y + r.h) - Math.max(cr.y, r.y)
                if (d < 4 || ov > 0.5 * Math.min(cr.h, r.h) || navGroup(c, root) !== grp) continue
                var gap = Math.max(0, r.x - (cr.x + cr.w), cr.x - (r.x + r.w))
                score = d + gap * 3 + Math.abs(r.cx - cr.cx) * 0.05
            } else {
                var dx = (r.cx - cr.cx) * (dir === "right" ? 1 : -1)
                var ovy = Math.min(cr.y + cr.h, r.y + r.h) - Math.max(cr.y, r.y)
                if (dx < 4 || ovy <= 0) continue
                score = dx + Math.abs(r.cy - cr.cy) * 1.5
            }
            if (score < bestScore) { bestScore = score; best = c }
        }
        return best
    }
    // Moves the focus; returns true when it moved.
    function navMove(win, dir, sameGroup) {
        var cur = win ? win.activeFocusItem : null
        if (!cur) return false
        var root = navRoot(cur)
        if (!root) return false
        var n = navNext(cur, dir, root, sameGroup)
        if (!n) return false
        n.forceActiveFocus(dir === "up" || dir === "left" ? Qt.BacktabFocusReason : Qt.TabFocusReason)
        return true
    }
    // Called by Main.qml for key presses nobody handled (see FpNav.qml).
    function handleKey(event, win) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return false
        switch (event.key) {
        case Qt.Key_Up: return navMove(win, "up")
        case Qt.Key_Down: return navMove(win, "down")
        case Qt.Key_Left: return navMove(win, "left")
        case Qt.Key_Right: return navMove(win, "right")
        }
        return false
    }
}
