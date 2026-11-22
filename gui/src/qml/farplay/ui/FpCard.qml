// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

Rectangle {
    id: root
    property int padding: Theme.unit * 3
    default property alias content: inner.data
    property alias contentItem: inner

    implicitWidth: inner.childrenRect.width + padding * 2
    implicitHeight: inner.childrenRect.height + padding * 2
    radius: Theme.radius
    color: Theme.panel
    border.width: 1
    border.color: Theme.border

    Item {
        id: inner
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        height: root.height - root.padding * 2
    }
}
