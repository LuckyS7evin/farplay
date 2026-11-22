// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

// Console login PIN. Same backend call as chiaki-ng's ConsolePinDialog:
// Chiaki.setConsolePin(consoleIndex, pin).
FpPage {
    id: page
    property var consoleIndex: 0
    title: "Code PIN de la console"
    subtitle: "Mémorisé pour les prochaines connexions à cette console."
    onBack: root.closeDialog()

    function save() {
        if (!pinField.acceptable || pinField.text.length !== 4) return
        Chiaki.setConsolePin(consoleIndex, pinField.text.trim())
        root.closeDialog()
    }

    Component.onCompleted: focusFirst()

    FpGlass {
        Layout.fillWidth: true
        implicitHeight: form.implicitHeight + Theme.unit * 6
        radius: 24
        fillAlpha: 0.7
        ColumnLayout {
            id: form
            x: Theme.unit * 3
            y: Theme.unit * 3
            width: parent.width - Theme.unit * 6
            FpTextField {
                id: pinField
                label: "Code PIN (4 chiffres)"
                hint: "Le code que la console demande à l'ouverture de session."
                placeholder: "0000"
                secret: true
                maximumLength: 4
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator { regularExpression: /[0-9]{0,4}/ }
                onAccepted: page.save()
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.unit * 2
        Item { Layout.fillWidth: true }
        FpButton { text: "Annuler"; onClicked: page.back() }
        FpButton {
            primary: true
            implicitHeight: 52
            iconName: "check"
            text: "Enregistrer"
            enabled: pinField.acceptable && pinField.text.length === 4
            onClicked: page.save()
        }
    }
}
