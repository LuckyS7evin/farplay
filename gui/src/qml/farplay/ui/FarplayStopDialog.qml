// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — confirmation de fin de partie : mise en veille de la console ou non.
import QtQuick
import QtQuick.Layouts

FarplayDialogCard {
    id: root
    signal sleepRequested()      // quitter + console en veille
    signal keepOnRequested()     // quitter, console laissée allumée
    signal cancelRequested()     // rester dans la partie
    function focusFirst() { sleepBtn.forceActiveFocus() }

    title: "Quitter la partie ?"
    message: "Mettre la console en veille en partant ?"
    implicitWidth: 640

    Keys.onEscapePressed: root.cancelRequested()

    RowLayout {
        width: parent.width
        spacing: 14
        FpButton {
            id: sleepBtn
            primary: true
            text: "Mettre en veille"
            iconName: "moon"
            onClicked: root.sleepRequested()
        }
        FpButton {
            id: keepBtn
            text: "Laisser allumée"
            onClicked: root.keepOnRequested()
        }
        Item { Layout.fillWidth: true }
        FpButton {
            id: cancelBtn
            flat: true
            text: "Annuler"
            onClicked: root.cancelRequested()
        }
    }
}
