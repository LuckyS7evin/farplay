// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

// Settings section « Consoles » : consoles appairées, consoles du réseau, masquées, compte PSN.
ColumnLayout {
    id: sec
    spacing: Theme.unit * 2
    readonly property bool psnConnected: !!(Chiaki.settings.psnRefreshToken && Chiaki.settings.psnAuthToken
                                           && Chiaki.settings.psnAuthTokenExpiry && Chiaki.settings.psnAccountId)

    FpSectionCard {
        iconName: "display"
        title: "Consoles appairées"
        subtitle: "Les PS5 et PS4 que Farplay peut lancer."
        FpSettingRow {
            title: "Ajouter une console"
            description: "Appairez une console avec son code, ou ajoutez-la par son adresse IP."
            RowLayout {
                spacing: Theme.unit * 2
                FpButton {
                    id: pairBtn
                    focus: true
                    iconName: "plus"
                    text: "Appairer"
                    onClicked: root.showRegistDialog("255.255.255.255", true)
                    KeyNavigation.right: ipBtn
                }
                FpButton {
                    id: ipBtn
                    text: "Par adresse IP"
                    onClicked: root.showManualHostDialog()
                    KeyNavigation.left: pairBtn
                }
            }
        }
        Repeater {
            model: Chiaki.settings.registeredHosts
            delegate: FpSettingRow {
                id: reg
                required property var modelData
                required property int index
                divider: true
                title: modelData.name + "  ·  " + (modelData.ps5 ? "PS5" : "PS4")
                description: Chiaki.settings.streamerMode ? "Adresse MAC masquée" : modelData.mac
                RowLayout {
                    spacing: Theme.unit * 2
                    Text {
                        text: "Connexion auto"
                        font.family: Theme.ui
                        font.pixelSize: Theme.small
                        color: Theme.dim
                    }
                    FpSwitch {
                        focus: true
                        checked: Chiaki.settings.autoConnectMac === reg.modelData.mac
                        onToggled: (c) => Chiaki.settings.autoConnectMac = c ? reg.modelData.mac : ""
                        KeyNavigation.right: delBtn
                    }
                    FpButton {
                        id: delBtn
                        text: "Supprimer"
                        danger: true
                        onClicked: root.showConfirmDialog("Supprimer la console", "Voulez-vous vraiment supprimer cette console ? Il faudra l'appairer à nouveau.", () => Chiaki.settings.deleteRegisteredHost(reg.index))
                    }
                }
            }
        }
        Text {
            visible: (Chiaki.settings.registeredHosts || []).length === 0
            Layout.leftMargin: Theme.unit * 2
            Layout.topMargin: Theme.unit
            text: "Aucune console appairée."
            font.family: Theme.ui
            font.pixelSize: Theme.small
            color: Theme.dim
        }
    }

    FpSectionCard {
        visible: (Chiaki.hosts || []).length > 0
        iconName: "play"
        title: "Consoles du réseau"
        subtitle: "Consoles détectées ou ajoutées à la main."
        Repeater {
            model: Chiaki.hosts
            delegate: FpSettingRow {
                id: hostRow
                required property var modelData
                required property int index
                divider: index > 0
                title: modelData.name
                description: (modelData.address || "") + (modelData.manual ? "  ·  ajoutée à la main" : "")
                RowLayout {
                    spacing: Theme.unit * 2
                    FpButton {
                        focus: true
                        text: "Code PIN"
                        onClicked: root.showConsolePinDialog(hostRow.index)
                        KeyNavigation.right: rmBtn
                    }
                    FpButton {
                        id: rmBtn
                        visible: hostRow.modelData.manual || (hostRow.modelData.discovered && !hostRow.modelData.registered)
                        text: hostRow.modelData.manual ? "Supprimer" : "Masquer"
                        danger: hostRow.modelData.manual
                        onClicked: {
                            if (hostRow.modelData.manual)
                                root.showConfirmDialog("Supprimer la console", "Voulez-vous vraiment supprimer cette console ?", () => Chiaki.deleteHost(hostRow.index))
                            else
                                root.showConfirmDialog("Masquer la console", "Voulez-vous vraiment masquer cette console ? Vous pourrez l'afficher à nouveau ici.", () => Chiaki.hideHost(hostRow.modelData.mac, hostRow.modelData.name))
                        }
                    }
                }
            }
        }
    }

    FpSectionCard {
        visible: (Chiaki.hiddenHosts || []).length > 0
        iconName: "moon"
        title: "Consoles masquées"
        subtitle: "Consoles que vous avez cachées de l'accueil."
        Repeater {
            model: Chiaki.hiddenHosts
            delegate: FpSettingRow {
                id: hid
                required property var modelData
                required property int index
                divider: index > 0
                title: modelData.name
                description: Chiaki.settings.streamerMode ? "Adresse MAC masquée" : modelData.mac
                FpButton {
                    text: "Afficher"
                    onClicked: root.showConfirmDialog("Afficher la console", "Voulez-vous afficher à nouveau cette console ?", () => Chiaki.unhideHost(hid.modelData.mac))
                }
            }
        }
    }

    FpSectionCard {
        iconName: "power"
        title: "Compte PlayStation Network"
        subtitle: "Pour l'appairage automatique et le jeu à distance, hors de votre réseau."
        FpSettingRow {
            title: sec.psnConnected ? "Connecté" : "Non connecté"
            description: sec.psnConnected ? (Chiaki.settings.streamerMode ? "Identifiant de compte masqué" : "Identifiant : " + Chiaki.settings.psnAccountId)
                                          : "Connectez-vous pour jouer à distance."
            RowLayout {
                spacing: Theme.unit * 2
                FpButton {
                    focus: true
                    visible: !sec.psnConnected
                    text: "Se connecter à PSN"
                    onClicked: root.showPSNTokenDialog(false)
                }
                FpButton {
                    focus: true
                    visible: sec.psnConnected
                    text: "Se déconnecter"
                    danger: true
                    onClicked: {
                        Chiaki.settings.psnRefreshToken = ""
                        Chiaki.settings.psnAuthToken = ""
                        Chiaki.settings.psnAuthTokenExpiry = ""
                        Chiaki.settings.psnAccountId = ""
                    }
                }
            }
        }
    }
}
