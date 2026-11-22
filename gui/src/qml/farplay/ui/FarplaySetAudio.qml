// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

// Settings section « Manette & son » : audio.
ColumnLayout {
    id: sec
    spacing: Theme.unit * 2
    readonly property bool hasSpeech: typeof Chiaki.settings.speechProcessing !== "undefined"
    onVisibleChanged: if (visible && Chiaki.settings.refreshAudioDevices) Chiaki.settings.refreshAudioDevices()

    FpSectionCard {
        iconName: "mic"
        title: "Audio"
        subtitle: "Périphériques, tampon et volume."
        FpSettingRow {
            title: "Sortie audio"
            FpSelect {
                id: outSel
                implicitWidth: 340
                model: ["Auto"].concat(Chiaki.settings.availableAudioOutDevices || [])
                currentIndex: Math.max(0, model.indexOf(Chiaki.settings.audioOutDevice))
                onActivated: (i) => Chiaki.settings.audioOutDevice = i ? model[i] : ""
            }
        }
        FpSettingRow {
            divider: true
            title: "Entrée audio (micro)"
            FpSelect {
                implicitWidth: 340
                model: ["Auto"].concat(Chiaki.settings.availableAudioInDevices || [])
                currentIndex: Math.max(0, model.indexOf(Chiaki.settings.audioInDevice))
                onActivated: (i) => Chiaki.settings.audioInDevice = i ? model[i] : ""
            }
        }
        FpSettingRow {
            divider: true
            title: "Tampon audio"
            description: "Plus grand = moins de craquements, un peu plus de latence."
            FpSlider {
                width: 320
                from: 10; to: 100; stepSize: 10; unit: "ms"
                value: (Chiaki.settings.audioBufferSize / 1920 || 5) * 10
                onMoved: (v) => Chiaki.settings.audioBufferSize = (v / 10) * 1920
            }
        }
        FpSettingRow {
            divider: true
            title: "Volume"
            FpSlider {
                width: 320
                from: 0; to: 100; stepSize: 2; unit: "%"
                value: Math.round(Chiaki.settings.audioVolume / 1.28)
                onMoved: (v) => Chiaki.settings.audioVolume = Math.round(v * 1.28)
            }
        }
    }

    FpSectionCard {
        iconName: "micoff"
        title: "Micro"
        subtitle: "Voix en jeu avec le micro de la manette ou du PC."
        FpSettingRow {
            title: "Micro actif au démarrage"
            description: "Sinon, il démarre coupé."
            FpSwitch {
                checked: Chiaki.settings.startMicUnmuted
                onToggled: (c) => Chiaki.settings.startMicUnmuted = c
            }
        }
        FpSettingRow {
            visible: sec.hasSpeech
            divider: true
            title: "Traitement de la voix"
            description: "Suppression du bruit et de l'écho."
            FpSwitch {
                checked: Chiaki.settings.speechProcessing
                onToggled: (c) => Chiaki.settings.speechProcessing = c
            }
        }
        FpSettingRow {
            visible: sec.hasSpeech && Chiaki.settings.speechProcessing
            divider: true
            title: "Bruit à supprimer"
            FpSlider {
                width: 320
                from: 0; to: 60; stepSize: 1; unit: "dB"
                value: Chiaki.settings.noiseSuppressLevel
                onMoved: (v) => Chiaki.settings.noiseSuppressLevel = v
            }
        }
        FpSettingRow {
            visible: sec.hasSpeech && Chiaki.settings.speechProcessing
            divider: true
            title: "Écho à supprimer"
            FpSlider {
                width: 320
                from: 0; to: 60; stepSize: 1; unit: "dB"
                value: Chiaki.settings.echoSuppressLevel
                onMoved: (v) => Chiaki.settings.echoSuppressLevel = v
            }
        }
    }
}
