// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Controls.Basic

// Thin themed vertical scroll bar (attach with `ScrollBar.vertical: FpScrollBar {}`).
ScrollBar {
    id: bar
    readonly property Flickable flickable: parent instanceof Flickable ? parent : null
    policy: flickable && flickable.contentHeight > flickable.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    minimumSize: 0.08
    implicitWidth: 6
    padding: 2
    contentItem: Rectangle {
        implicitWidth: 4
        radius: width / 2
        color: Theme.ivory
        opacity: bar.pressed ? 0.5 : (bar.hovered ? 0.38 : (bar.active ? 0.28 : 0))
        Behavior on opacity { NumberAnimation { duration: Theme.duration } }
    }
    background: Item {}
}
