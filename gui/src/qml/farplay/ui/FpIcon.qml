// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick

// Monochrome SVG icon. `tone` picks a pre-colored variant: ivory, coral, night, alert.
Image {
    id: root
    property string name: "home"
    property string tone: "ivory"
    property real size: 24

    width: size
    height: size
    sourceSize: Qt.size(Math.ceil(size * 2), Math.ceil(size * 2))
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: false
    source: name === "" ? "" : Theme.iconBase + name + (tone === "ivory" ? "" : "-" + tone) + ".svg"
}
