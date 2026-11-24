// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.streetpea.chiaking

// Settings section « Manette & son » : manette, clavier et souris, raccourcis.
ColumnLayout {
    id: sec
    spacing: Theme.unit * 2
    property Item overlayParent: null
    readonly property var buttonNames: ["Inutilisé", "Croix", "Rond", "Carré", "Triangle", "Croix ←", "Croix →", "Croix ↑", "Croix ↓",
                                        "L1", "R1", "L3", "R3", "Options", "Share", "Pavé tactile", "PS"]
    readonly property var rumbleNames: ["Coupées", "Très faibles", "Faibles", "Normales", "Fortes", "Très fortes"]
    property var keyNames: ({})
    property int captureValue: 0
    property int captureIndex: -1
    property Item captureReturn: null

    function openCapture(value, idx, item) {
        captureValue = value; captureIndex = idx; captureReturn = item
        capture.visible = true
        capKeys.forceActiveFocus()
    }
    function closeCapture() {
        capture.visible = false
        if (captureReturn) captureReturn.forceActiveFocus()
    }

    // Four-slot button combo (settings named <base>1..4).
    component Combo: Flow {
        id: combo
        property string base
        spacing: Theme.unit * 1.5
        width: 600
        Repeater {
            model: 4
            delegate: FpSelect {
                required property int index
                implicitWidth: 140
                implicitHeight: 40
                model: sec.buttonNames
                currentIndex: Chiaki.settings[combo.base + (index + 1)]
                onActivated: (i) => Chiaki.settings[combo.base + (index + 1)] = i
            }
        }
    }

    FpSectionCard {
        iconName: "profiles"
        title: "Manette"
        subtitle: "Boutons, vibrations et entrées en arrière-plan."
        FpSettingRow {
            title: "Mapping de la manette"
            description: "Choisissez quel bouton physique déclenche chaque bouton de la DualSense."
            RowLayout {
                spacing: Theme.unit * 2
                FpButton {
                    id: mapBtn
                    focus: true
                    text: "Modifier"
                    onClicked: root.showControllerMappingDialog()
                }
                FpButton {
                    id: mapReset
                    text: "Réinitialiser"
                    onClicked: root.showFarplayView("qrc:/farplay/ui/FarplayControllerMapping.qml", { reset: true })
                }
            }
        }
        FpSettingRow {
            divider: true
            title: "Boutons par position"
            description: "Utilise la position des boutons plutôt que leur étiquette (Xbox / Nintendo)."
            FpSwitch {
                checked: Chiaki.settings.buttonsByPosition
                onToggled: (c) => Chiaki.settings.buttonsByPosition = c
            }
        }
        FpSettingRow {
            divider: true
            title: "Manette en arrière-plan"
            description: "Traite les entrées de la manette quand la fenêtre n'a pas le focus."
            FpSwitch {
                checked: Chiaki.settings.allowJoystickBackgroundEvents
                onToggled: (c) => Chiaki.settings.allowJoystickBackgroundEvents = c
            }
        }
        FpSettingRow {
            divider: true
            title: "Vibrations (rumble)"
            FpSelect {
                implicitWidth: 240
                model: sec.rumbleNames
                currentIndex: Chiaki.settings.rumbleHapticsIntensity
                onActivated: (i) => Chiaki.settings.rumbleHapticsIntensity = i
            }
        }
        FpSettingRow {
            divider: true
            title: "Intensité du retour haptique"
            description: "100 % = réglage de la console."
            FpSlider {
                width: 320
                from: 0; to: 200; stepSize: 10; unit: "%"
                value: Math.round(Chiaki.settings.hapticOverride * 100)
                onMoved: (v) => Chiaki.settings.hapticOverride = v / 100
            }
        }
        FpSettingRow {
            visible: typeof Chiaki.settings.steamDeckHaptics !== "undefined"
            divider: true
            title: "Haptique Steam Deck"
            description: "Vrai retour haptique, meilleure qualité mais plus bruyant."
            FpSwitch {
                checked: typeof Chiaki.settings.steamDeckHaptics !== "undefined" ? Chiaki.settings.steamDeckHaptics : false
                onToggled: (c) => Chiaki.settings.steamDeckHaptics = c
            }
        }
        FpSettingRow {
            visible: typeof Chiaki.settings.verticalDeck !== "undefined"
            divider: true
            title: "Steam Deck à la verticale"
            description: "Pour les commandes de mouvement en orientation verticale."
            FpSwitch {
                checked: typeof Chiaki.settings.verticalDeck !== "undefined" ? Chiaki.settings.verticalDeck : false
                onToggled: (c) => Chiaki.settings.verticalDeck = c
            }
        }
    }

    FpSectionCard {
        iconName: "display"
        title: "Clavier et souris"
        subtitle: "Jouer sans manette."
        FpSettingRow {
            title: "Clavier comme manette"
            FpSwitch {
                checked: Chiaki.settings.keyboardEnabled
                onToggled: (c) => Chiaki.settings.keyboardEnabled = c
            }
        }
        FpSettingRow {
            divider: true
            title: "Souris comme pavé tactile"
            FpSwitch {
                checked: Chiaki.settings.mouseTouchEnabled
                onToggled: (c) => Chiaki.settings.mouseTouchEnabled = c
            }
        }
        FpSettingRow {
            divider: true
            title: "Touches du clavier"
            description: "Cliquez sur une touche puis appuyez sur la nouvelle."
            FpButton {
                text: "Tout réinitialiser"
                onClicked: { sec.keyNames = ({}); Chiaki.settings.clearKeyMapping() }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.unit * 2
            Layout.rightMargin: Theme.unit * 2
            Layout.topMargin: Theme.unit
            columns: 3
            columnSpacing: Theme.unit * 3
            rowSpacing: Theme.unit
            Repeater {
                model: Chiaki.settings.controllerMapping
                delegate: RowLayout {
                    id: kRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Theme.unit
                    Text {
                        Layout.fillWidth: true
                        text: kRow.modelData.buttonName
                        elide: Text.ElideRight
                        font.family: Theme.ui
                        font.pixelSize: Theme.small
                        color: Theme.dim
                    }
                    FpButton {
                        id: kBtn
                        Layout.preferredWidth: 120
                        implicitHeight: 40
                        fontSize: Theme.small
                        text: sec.keyNames[kRow.index] || kRow.modelData.keyName
                        onClicked: sec.openCapture(kRow.modelData.buttonValue, kRow.index, kBtn)
                    }
                }
            }
        }
    }

    FpSectionCard {
        iconName: "gear"
        title: "Pavé tactile par la croix directionnelle"
        subtitle: "Émule le pavé tactile de la DualSense avec le D-pad."
        expanded: false
        FpSettingRow {
            title: "Activer"
            FpSwitch {
                checked: Chiaki.settings.dpadTouchEnabled
                onToggled: (c) => Chiaki.settings.dpadTouchEnabled = c
            }
        }
        FpSettingRow {
            visible: Chiaki.settings.dpadTouchEnabled
            divider: true
            title: "Pas de déplacement"
            FpSlider {
                width: 320
                valueWidth: 110
                from: 1; to: 1079; stepSize: 1; unit: "×0,01 mm"
                value: Chiaki.settings.dpadTouchIncrement
                onMoved: (v) => Chiaki.settings.dpadTouchIncrement = v
            }
        }
        FpSettingRow {
            visible: Chiaki.settings.dpadTouchEnabled
            divider: true
            title: "Combo croix / pavé tactile"
            description: "Boutons à presser ensemble pour basculer."
            Combo { base: "dpadTouchShortcut" }
        }
    }

    FpSectionCard {
        iconName: "stats"
        title: "Raccourci du menu en jeu"
        subtitle: "Combinaison de boutons qui ouvre le menu pendant la partie."
        expanded: false
        FpSettingRow {
            title: "Activer le raccourci"
            FpSwitch {
                checked: Chiaki.settings.streamMenuEnabled
                onToggled: (c) => Chiaki.settings.streamMenuEnabled = c
            }
        }
        FpSettingRow {
            visible: Chiaki.settings.streamMenuEnabled
            divider: true
            title: "Combinaison"
            description: "Par défaut L1 + R1 + L3 + R3."
            Combo { base: "streamMenuShortcut" }
        }
    }

    // Key capture overlay
    Item {
        id: capture
        parent: sec.overlayParent
        anchors.fill: parent
        visible: false
        z: 50
        Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0.02, 0.03, 0.8); MouseArea { anchors.fill: parent } }
        FpGlass {
            anchors.centerIn: parent
            width: 560
            height: 200
            radius: 28
            fillAlpha: 0.95
            Column {
                anchors.centerIn: parent
                spacing: Theme.unit * 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Appuyez sur une touche"
                    font.family: Theme.ui
                    font.pixelSize: Theme.title - 4
                    font.weight: Font.DemiBold
                    color: Theme.ivory
                }
                FpButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Annuler"
                    onClicked: sec.closeCapture()
                }
            }
            Item {
                id: capKeys
                focus: true
                Keys.onEscapePressed: sec.closeCapture()
                Keys.onReleased: (event) => {
                    var name = Chiaki.settings.changeControllerKey(sec.captureValue, event.key)
                    var n = Object.assign({}, sec.keyNames)
                    n[sec.captureIndex] = name
                    sec.keyNames = n
                    event.accepted = true
                    sec.closeCapture()
                }
            }
        }
    }
}
