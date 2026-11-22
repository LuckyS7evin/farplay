// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

FpGlass {
    id: root
    property int padding: Theme.unit * 3
    default property alias content: inner.data
    property alias contentItem: inner

    implicitWidth: inner.childrenRect.width + padding * 2
    implicitHeight: inner.childrenRect.height + padding * 2
    radius: 20
    fillAlpha: 0.8

    Item {
        id: inner
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        height: root.height - root.padding * 2
    }
}
