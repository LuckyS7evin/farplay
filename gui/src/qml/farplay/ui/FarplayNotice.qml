// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — avis en jeu avec une seule action (ex. contenu non affichable).
import QtQuick

FarplayDialogCard {
    id: root
    property string actionText: "OK"
    signal accepted()
    function focusFirst() { btn.forceActiveFocus() }

    implicitWidth: 600
    Keys.onEscapePressed: root.accepted()

    FpButton {
        id: btn
        primary: true
        text: root.actionText
        onClicked: root.accepted()
    }
}
