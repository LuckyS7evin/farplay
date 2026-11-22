// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import org.streetpea.chiaking

FocusScope {
    id: page
    anchors.fill: parent
    property bool advancedOpen: false
    property int rev: 0

    component GroupTitle: Text {
        Layout.topMargin: Theme.unit * 3
        Layout.leftMargin: Theme.unit * 2
        font.family: Theme.ui
        font.pixelSize: Theme.small
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.5
        color: Theme.dim
    }

    function refresh() { rev++; body.active = false; body.active = true }

    Keys.onEscapePressed: root.showMainView()
    Keys.onUpPressed: { var i = nextItemInFocusChain(false); if (i) i.forceActiveFocus() }
    Keys.onDownPressed: { var i = nextItemInFocusChain(true); if (i) i.forceActiveFocus() }
    Component.onCompleted: backBtn.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Theme.night }

    RowLayout {
        id: header
        x: Theme.unit * 5
        y: Theme.unit * 3
        width: parent.width - Theme.unit * 10
        spacing: Theme.unit * 2
        FpButton { id: backBtn; text: "‹ Retour"; onClicked: root.showMainView() }
        Text {
            Layout.fillWidth: true
            text: "Réglages"
            font.family: Theme.ui
            font.pixelSize: Theme.title
            color: Theme.ivory
        }
        FpButton {
            text: "Recommandé"
            onClicked: {
                FarplayImage.resetRecommended()
                FarplayFrameGen.mode = 1
                FarplayFrameGen.multiplier = 2
                FarplayFrameGen.hudProtect = true
                page.refresh()
            }
        }
    }

    ScrollView {
        id: scroll
        anchors.top: header.bottom
        anchors.topMargin: Theme.unit * 2
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - Theme.unit * 10, 1000)
        contentWidth: availableWidth
        clip: true

        Loader {
            id: body
            width: scroll.availableWidth
            sourceComponent: sections
        }
    }

    Component {
        id: sections
        ColumnLayout {
            spacing: Theme.unit

            GroupTitle { text: "Flux" }
            FpSettingRow {
                title: "Images par seconde"
                description: "Cadence envoyée par la PS5. Régler sur la cadence du jeu évite les images dupliquées."
                costs: ({ fluidite: "+", latence: "−" })
                FpSelect {
                    model: ["30", "60"]
                    currentIndex: Chiaki.settings.fpsLocalPS5 === 60 ? 1 : 0
                    onActivated: (i) => { Chiaki.settings.fpsLocalPS5 = (i + 1) * 30; Chiaki.settings.fpsRemotePS5 = (i + 1) * 30 }
                }
            }
            FpSettingRow {
                title: "Bitrate"
                description: "Qualité du flux. Plus haut = moins de pixels flous, demande un réseau stable."
                costs: ({ image: "+" })
                FpSlider {
                    from: 2; to: 100; stepSize: 1; unit: "Mbps"
                    value: Chiaki.settings.bitrateLocalPS5 / 1000
                    onMoved: (v) => Chiaki.settings.bitrateLocalPS5 = v * 1000
                }
            }
            FpSettingRow {
                title: "HDR"
                description: "Demande un flux HDR à la PS5. Ne marche que si la console voit un écran HDR."
                costs: ({ image: "+" })
                FpSwitch {
                    checked: Chiaki.settings.codecLocalPS5 === 2
                    onToggled: (c) => Chiaki.settings.codecLocalPS5 = c ? 2 : 1
                }
            }

            GroupTitle { text: "Image" }
            FpSettingRow {
                title: "Upscaling"
                description: "Méthode pour passer de 1080p à la résolution de l'écran."
                costs: ({ image: "+", gpu: "+" })
                FpSelect {
                    model: ["Réglage chiaki-ng", "FSR 1", "FSRCNNX (réseau léger)", "libplacebo"]
                    currentIndex: FarplayImage.upscaler
                    onActivated: (i) => FarplayImage.upscaler = i
                }
            }
            FpSettingRow {
                title: "Netteté"
                description: "Renforce les contours après l'upscaling. Trop haut = halos."
                costs: ({ image: "+" })
                FpSlider {
                    from: 0; to: 100; stepSize: 5; unit: "%"
                    value: FarplayImage.sharpness
                    onMoved: (v) => FarplayImage.sharpness = v
                }
            }
            FpSettingRow {
                title: "Lissage des dégradés"
                description: "Atténue les marches de couleur dues à la compression."
                costs: ({ image: "+", gpu: "+" })
                FpSelect {
                    model: ["Coupé", "Faible", "Moyen"]
                    currentIndex: FarplayImage.deband
                    onActivated: (i) => FarplayImage.deband = i
                }
            }
            FpSettingRow {
                title: "SDR sur écran HDR"
                description: "Affiche un flux SDR avec une luminosité adaptée à l'écran HDR."
                FpSwitch {
                    checked: FarplayImage.sdrToHdr
                    onToggled: (c) => FarplayImage.sdrToHdr = c
                }
            }
            FpSettingRow {
                title: "Luminosité SDR"
                description: "Luminosité du blanc SDR sur un écran HDR."
                FpSlider {
                    from: 80; to: 400; stepSize: 10; unit: "nits"
                    value: FarplayImage.sdrWhiteNits
                    onMoved: (v) => FarplayImage.sdrWhiteNits = v
                }
            }

            GroupTitle { text: "Fluidité" }
            FpSettingRow {
                title: "Génération d'images"
                description: "Crée une image intermédiaire entre deux images reçues. Plus fluide, légèrement plus de latence."
                costs: ({ fluidite: "+", latence: "+", gpu: "+" })
                FpSelect {
                    model: ["Coupée", "Interne", "AFMF (pilote AMD)"]
                    currentIndex: FarplayFrameGen.mode
                    onActivated: (i) => FarplayFrameGen.mode = i
                }
            }
            FpSettingRow {
                id: multRow
                readonly property var values: [2, 3, 4, 0]
                title: "Multiplicateur"
                description: "Nombre d'images affichées pour chaque image reçue."
                FpSelect {
                    model: ["x2", "x3", "x4", "Fréquence de l'écran"]
                    currentIndex: Math.max(0, multRow.values.indexOf(FarplayFrameGen.multiplier))
                    onActivated: (i) => FarplayFrameGen.multiplier = multRow.values[i]
                }
            }
            FpSettingRow {
                title: "Protection du HUD"
                description: "Évite que la mini-map et les textes tremblent."
                FpSwitch {
                    checked: FarplayFrameGen.hudProtect
                    onToggled: (c) => FarplayFrameGen.hudProtect = c
                }
            }
            Text {
                Layout.leftMargin: Theme.unit * 2
                text: "F4 en jeu : couper/rétablir la frame gen"
                font.family: Theme.ui
                font.pixelSize: Theme.small
                color: Theme.dim
            }

            GroupTitle { text: "Affichage" }
            FpSettingRow {
                title: "Synchronisation"
                description: "VRR = fluide sans déchirure. Mailbox = latence minimale."
                FpSelect {
                    model: ["VSync (FIFO)", "Mailbox (latence minimale)"]
                    currentIndex: Farplay.mailbox ? 1 : 0
                    onActivated: (i) => Farplay.mailbox = (i === 1)
                }
            }
            FpSettingRow {
                title: "Overlay de stats"
                description: "F3 en jeu."
                FpSelect {
                    model: ["Masqué", "Compact", "Détaillé"]
                    currentIndex: Farplay.overlayLevel
                    onActivated: (i) => Farplay.overlayLevel = i
                }
            }
            FpSettingRow {
                title: "Journal de stats CSV"
                description: "Enregistre les statistiques de chaque partie dans un fichier."
                FpSwitch {
                    checked: Farplay.csvLogging
                    onToggled: (c) => Farplay.csvLogging = c
                }
            }

            GroupTitle { text: "Profils" }
            Repeater {
                model: FarplayProfiles.names
                delegate: RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.unit * 2
                    spacing: Theme.unit * 2
                    Text {
                        Layout.fillWidth: true
                        text: modelData
                        elide: Text.ElideRight
                        font.family: Theme.ui
                        font.pixelSize: Theme.body
                        color: modelData === FarplayProfiles.current ? Theme.mint : Theme.ivory
                    }
                    FpButton {
                        text: "Appliquer"
                        onClicked: { FarplayProfiles.apply(modelData); page.refresh() }
                    }
                    FpButton {
                        text: "Supprimer"
                        onClicked: FarplayProfiles.remove(modelData)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.unit * 2
                spacing: Theme.unit * 2
                TextField {
                    id: nameField
                    Layout.fillWidth: true
                    implicitHeight: 48
                    placeholderText: "Nom du profil"
                    placeholderTextColor: Theme.dim
                    color: Theme.ivory
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                    leftPadding: 14
                    activeFocusOnTab: true
                    onAccepted: { FarplayProfiles.saveCurrentAs(text); text = "" }
                    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(nameField)
                    background: Rectangle {
                        radius: Theme.radius
                        color: Theme.graphite
                        border.width: nameField.activeFocus ? 2 : 1
                        border.color: nameField.activeFocus ? Theme.ivory : Theme.border
                    }
                }
                FpButton {
                    text: "Enregistrer le profil actuel"
                    onClicked: { FarplayProfiles.saveCurrentAs(nameField.text); nameField.text = "" }
                }
            }

            GroupTitle { text: "Avancé" }
            FpButton {
                Layout.leftMargin: Theme.unit * 2
                text: page.advancedOpen ? "Avancé ▾" : "Avancé ▸"
                onClicked: page.advancedOpen = !page.advancedOpen
            }
            FpButton {
                Layout.leftMargin: Theme.unit * 2
                visible: page.advancedOpen
                text: "Réglages chiaki-ng complets"
                onClicked: root.showSettingsDialog()
            }
            Item { Layout.preferredHeight: Theme.unit * 6 }
        }
    }
}
