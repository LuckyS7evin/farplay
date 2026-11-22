// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

// Settings section « Réseau » : jeu à distance, qualité de connexion, traversée NAT.
ColumnLayout {
    id: sec
    property bool ps5: true
    spacing: Theme.unit * 2
    readonly property bool openGl: Chiaki.settings.rendererBackend === 1
    readonly property var defaultBitrate: [0, 2, 6, 10, 15]
    readonly property int resRemote: ps5 ? Chiaki.settings.resolutionRemotePS5 : Chiaki.settings.resolutionRemotePS4
    readonly property int bitrateRemote: ps5 ? Chiaki.settings.bitrateRemotePS5 : Chiaki.settings.bitrateRemotePS4

    FpSectionCard {
        iconName: "power"
        title: "Jeu à distance"
        subtitle: "Réglages utilisés quand vous jouez hors de votre réseau (via PSN)."
        FpSettingRow {
            title: "Résolution"
            FpSegmented {
                model: ["360p", "540p", "720p", "1080p"]
                currentIndex: Math.max(0, sec.resRemote - 1)
                onActivated: (i) => {
                    if (sec.ps5) { Chiaki.settings.resolutionRemotePS5 = i + 1; Chiaki.settings.bitrateRemotePS5 = 0 }
                    else { Chiaki.settings.resolutionRemotePS4 = i + 1; Chiaki.settings.bitrateRemotePS4 = 0 }
                }
            }
        }
        FpSettingRow {
            divider: true
            title: "Débit"
            description: "Réduisez-le si la connexion distante saccade."
            FpSlider {
                width: 320
                from: 2; to: 100; stepSize: 1; unit: "Mbps"
                value: sec.bitrateRemote ? sec.bitrateRemote / 1000 : sec.defaultBitrate[Math.max(1, Math.min(4, sec.resRemote))]
                onMoved: (v) => { if (sec.ps5) Chiaki.settings.bitrateRemotePS5 = v * 1000; else Chiaki.settings.bitrateRemotePS4 = v * 1000 }
            }
        }
        FpSettingRow {
            visible: sec.ps5
            divider: true
            title: "Codec vidéo"
            description: Chiaki.session ? "S'applique à la prochaine connexion." : ""
            FpSegmented {
                model: sec.openGl ? ["H.264", "H.265"] : ["H.264", "H.265", "H.265 HDR"]
                currentIndex: Math.min(Chiaki.settings.codecRemotePS5, sec.openGl ? 1 : 2)
                onActivated: (i) => Chiaki.settings.codecRemotePS5 = i
            }
        }
    }

    FpSectionCard {
        iconName: "stats"
        title: "Qualité de connexion"
        subtitle: "Alertes et récupération en cas de perte de paquets."
        FpSettingRow {
            title: "Alerte Wi-Fi faible"
            description: "Prévient quand ce taux de paquets perdus est atteint."
            FpSlider {
                width: 320
                from: 0; to: 100; stepSize: 1; unit: "%"
                value: Chiaki.settings.wifiDroppedNotif
                onMoved: (v) => Chiaki.settings.wifiDroppedNotif = v
            }
        }
        FpSettingRow {
            divider: true
            title: "Perte de paquets maximale signalée"
            FpSlider {
                width: 320
                from: 0; to: 100; stepSize: 1; unit: "%"
                value: Chiaki.settings.packetLossReportedMax
                onMoved: (v) => Chiaki.settings.packetLossReportedMax = v
            }
        }
        FpSettingRow {
            divider: true
            title: "Demander une image complète"
            description: "Redemande une image clé à la console quand la correction d'erreurs échoue."
            FpSwitch {
                checked: Chiaki.settings.iDROnFECFailureEnabled
                onToggled: (c) => Chiaki.settings.iDROnFECFailureEnabled = c
            }
        }
    }

    FpSectionCard {
        iconName: "gear"
        title: "Traversée NAT (avancé)"
        subtitle: "Pour le jeu à distance derrière un routeur strict."
        expanded: false
        FpSettingRow {
            title: "Forcer la devinette de ports STUN"
            FpSwitch {
                checked: Chiaki.settings.portGuessingEnabled
                onToggled: (c) => Chiaki.settings.portGuessingEnabled = c
            }
        }
        FpSettingRow {
            divider: true
            title: "Nombre d'essais de ports"
            FpSlider {
                width: 320
                from: 0; to: 75; stepSize: 1
                value: Chiaki.settings.portGuessCount
                onMoved: (v) => Chiaki.settings.portGuessCount = v
            }
        }
        FpSettingRow {
            divider: true
            title: "Nombre de sockets"
            FpSlider {
                width: 320
                from: 0; to: 500; stepSize: 1
                value: Chiaki.settings.portGuessSocketCount
                onMoved: (v) => Chiaki.settings.portGuessSocketCount = v
            }
        }
    }
}
