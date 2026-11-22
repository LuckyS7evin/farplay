// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

// Add a console by IP address. Same backend call as chiaki-ng's ManualHostDialog:
// Chiaki.addManualHost(registeredHostIndex, address).
FpPage {
    id: page
    title: "Ajouter une console"
    subtitle: "Saisissez l'adresse IP d'une console qui n'est pas détectée automatiquement."
    onBack: root.closeDialog()

    // Entries of the select: the (optional) placeholder, one per registered console,
    // and "register on first connection". `ids` maps the select row to the registered
    // host index expected by addManualHost (-1 = nothing chosen yet).
    readonly property var registered: Chiaki.settings.registeredHosts || []
    readonly property var entries: {
        var names = [], ids = []
        if (registered.length > 0) { names.push("Choisir…"); ids.push(-1) }
        for (var i = 0; i < registered.length; i++) {
            var h = registered[i]
            names.push((Chiaki.settings.streamerMode ? "masqué" : h.mac) + " (" + h.name + ")")
            ids.push(i)
        }
        names.push("Appairer à la première connexion"); ids.push(registered.length)
        return { names: names, ids: ids }
    }
    readonly property int chosen: entries.ids[consoleSel.currentIndex] === undefined ? -1 : entries.ids[consoleSel.currentIndex]
    readonly property bool canAdd: hostField.hasText && chosen !== -1

    function add() {
        if (!canAdd) return
        Chiaki.addManualHost(chosen, hostField.text.trim())
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
            spacing: Theme.unit * 3
            FpTextField {
                id: hostField
                label: "Adresse de la console"
                placeholder: "192.168.1.42"
                secret: true
                onAccepted: consoleSel.forceActiveFocus()
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "Console déjà appairée"
                    font.family: Theme.ui
                    font.pixelSize: Theme.small
                    font.weight: Font.Medium
                    color: Theme.dim
                }
                FpSelect {
                    id: consoleSel
                    Layout.preferredWidth: 520
                    model: page.entries.names
                    currentIndex: 0
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Reprend l'appairage d'une console connue, ou appaire la console à la première connexion."
                    font.family: Theme.ui
                    font.pixelSize: Theme.small - 1
                    color: Theme.dim
                }
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
            iconName: "plus"
            text: "Ajouter"
            enabled: page.canAdd
            onClicked: page.add()
        }
    }
}
