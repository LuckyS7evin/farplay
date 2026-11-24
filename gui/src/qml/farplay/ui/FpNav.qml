// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Window

// Loaded once by Main.qml: spatial arrow/D-pad navigation for Farplay screens and automatic
// scrolling to the focused control (also for Tab / Shift+Tab).
Item {
    id: nav
    visible: false
    function handleKey(event) { return Theme.handleKey(event, nav.Window.window) }
    Connections {
        target: nav.Window.window
        function onActiveFocusItemChanged() {
            const it = nav.Window.window.activeFocusItem
            if (it && Theme.navRoot(it)) Theme.ensureVisible(it)
        }
    }
}
