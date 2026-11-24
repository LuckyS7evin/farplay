// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — code PIN de connexion à la console (4 chiffres).
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

FarplayDialogCard {
    id: root
    signal pinEntered(string pin)
    signal cancelled()
    readonly property bool valid: pinInput.acceptableInput
    function reset() { pinInput.text = "" }
    function focusFirst() { pinInput.forceActiveFocus() }

    title: "Code PIN de la console"
    message: "Saisissez le code à 4 chiffres affiché par la PS5."
    implicitWidth: 560

    Keys.onEscapePressed: root.cancelled()

    ColumnLayout {
        width: parent.width
        spacing: 22

        // Quatre cases ; la saisie réelle est un TextInput invisible
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 4 * 64 + 3 * 12
            Layout.preferredHeight: 72
            Row {
                spacing: 12
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 64; height: 72
                        radius: 16
                        color: Theme.night
                        border.width: pinInput.activeFocus && index === Math.min(pinInput.text.length, 3) ? 2 : 1
                        border.color: pinInput.activeFocus && index === Math.min(pinInput.text.length, 3) ? Theme.coral : Theme.line
                        Text {
                            anchors.centerIn: parent
                            text: index < pinInput.text.length ? (Chiaki.settings.streamerMode ? "•" : pinInput.text.charAt(index)) : ""
                            font.family: Theme.mono
                            font.pixelSize: 34
                            color: Theme.ivory
                        }
                    }
                }
            }
            TextInput {
                id: pinInput
                activeFocusOnTab: true
                anchors.fill: parent
                opacity: 0
                maximumLength: 4
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator { regularExpression: /[0-9]{4}/ }
                Keys.onReturnPressed: if (acceptableInput) root.pinEntered(text)
                Keys.onEnterPressed: if (acceptableInput) root.pinEntered(text)
            }
            MouseArea { anchors.fill: parent; onClicked: pinInput.forceActiveFocus() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Item { Layout.fillWidth: true }
            FpButton {
                id: cancelBtn
                text: "Annuler"
                onClicked: root.cancelled()
            }
            FpButton {
                id: okBtn
                primary: true
                text: "Valider"
                enabled: root.valid
                onClicked: root.pinEntered(pinInput.text)
            }
        }
    }
}
