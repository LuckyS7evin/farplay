// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — calque « menu de partie » : voile léger + panneau de réglages rapides, centré en bas.
// Remplace le menu du bas de chiaki-ng. Hébergé en ligne dans StreamView, ou dans une fenêtre
// séparée quand le rendu vidéo passe par une fenêtre native (backend Vulkan).
import QtQuick

Item {
    id: root
    signal closeRequested()
    signal quitRequested()
    signal displaySettingsRequested()
    function focusFirst() { panel.focusFirst() }

    // Clic hors du panneau : retour au flux
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.28
    }

    FarplayQuickPanel {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32
        width: Math.min(1040, root.width - 48)
        maxHeight: root.height - 32 - 96
        onCloseRequested: root.closeRequested()
        onQuitRequested: root.quitRequested()
        onDisplaySettingsRequested: root.displaySettingsRequested()
        MouseArea { anchors.fill: parent; z: -1 }   // absorbe les clics sur le fond du panneau
    }
}
