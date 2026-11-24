// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import org.streetpea.chiaking

// Console registration (pairing). Same backend call as chiaki-ng's RegistDialog:
// Chiaki.registerHost(host, psnId, pin, cpin, broadcast, target, callback).
FpPage {
    id: page
    property bool ps5: true
    property string host: ""
    // Console target: index into targets (PS5, PS4 >= 8, PS4 7.x, PS4 < 7).
    readonly property var targets: [1000100, 1000, 900, 800]
    property int targetIndex: ps5 ? 0 : 1
    readonly property bool needsOnlineId: targetIndex === 3
    property bool registering: false
    property bool finished: false
    property bool success: false
    property string logText: ""

    title: "Appairer une console"
    subtitle: "Associez la PS5 ou la PS4 à Farplay pour pouvoir jouer."
    hints: registering ? [["✕", finished ? "Fermer" : ""]] : [["✕", "Valider"], ["○", "Retour"]]
    onBack: { if (!registering) root.closeDialog() }

    readonly property bool canSubmit: hostField.hasText && pinField.acceptable && pinField.text.length === 8
        && cpinField.acceptable
        && (needsOnlineId ? onlineIdField.hasText : accountIdField.hasText)

    function submit() {
        if (!canSubmit || registering) return
        const psnId = needsOnlineId ? onlineIdField.text.trim() : accountIdField.text.trim()
        const h = hostField.text.trim()
        logText = ""
        finished = false
        success = false
        const ok = Chiaki.registerHost(h, psnId, pinField.text.trim(), cpinField.text.trim(),
                                       h === "255.255.255.255", targets[targetIndex],
                                       function(msg, okFlag, done) {
            if (!done) {
                page.logText += msg + "\n"
            } else {
                page.finished = true
                page.success = !!okFlag
                closeBtn.forceActiveFocus()
            }
        })
        if (ok) {
            registering = true
            logFlick.contentY = 0
        }
    }

    Component.onCompleted: {
        hostField.text = host
        if (Chiaki.settings.psnAccountId)
            accountIdField.text = Chiaki.settings.psnAccountId
        focusFirst()
    }

    // ── Form ───────────────────────────────────────────────────────────────
    FpGlass {
        Layout.fillWidth: true
        implicitHeight: form.implicitHeight + Theme.unit * 6
        radius: 24
        fillAlpha: 0.7
        enabled: !page.registering

        ColumnLayout {
            id: form
            x: Theme.unit * 3
            y: Theme.unit * 3
            width: parent.width - Theme.unit * 6
            spacing: Theme.unit * 2.5

            FpTextField {
                id: hostField
                label: "Adresse de la console"
                hint: "255.255.255.255 pour la chercher automatiquement sur le réseau."
                placeholder: "192.168.1.42"
                secret: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "Console"
                    font.family: Theme.ui
                    font.pixelSize: Theme.small
                    font.weight: Font.Medium
                    color: Theme.dim
                }
                FpSegmented {
                    id: typeSeg
                    model: ["PS5", "PS4 ≥ 8.0", "PS4 7.x", "PS4 < 7.0"]
                    currentIndex: page.targetIndex
                    onActivated: (i) => page.targetIndex = i
                }
            }

            FpTextField {
                id: onlineIdField
                visible: page.needsOnlineId
                label: "Identifiant PSN (Online-ID)"
                hint: "Votre pseudo PSN, majuscules et minuscules comptent."
                placeholder: "pseudo"
                secret: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: !page.needsOnlineId
                spacing: Theme.unit
                FpTextField {
                    id: accountIdField
                    label: "Identifiant de compte PSN (Account-ID)"
                    hint: "Chaîne en base64, propre à votre compte."
                    placeholder: "base64"
                    secret: true
                }
                RowLayout {
                    visible: !Chiaki.settings.psnAccountId
                    spacing: Theme.unit * 2
                    FpButton {
                        id: psnLoginBtn
                        text: "Connexion PSN"
                        fontSize: Theme.small + 1
                        onClicked: root.showFarplayView("qrc:/farplay/ui/FarplayPsn.qml", { mode: "login", callback: (id) => accountIdField.text = id })
                    }
                    FpButton {
                        id: lookupBtn
                        text: "Recherche publique"
                        fontSize: Theme.small + 1
                        onClicked: root.showFarplayView("qrc:/farplay/ui/FarplayPsn.qml", { mode: "lookup", callback: (id) => accountIdField.text = id })
                    }
                }
            }

            FpTextField {
                id: pinField
                label: "Code d'association (8 chiffres)"
                hint: "Sur la console : Réglages > Système > Lecture à distance > Associer l'appareil."
                placeholder: "12345678"
                secret: true
                maximumLength: 8
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator { regularExpression: /[0-9]{0,8}/ }
            }

            FpTextField {
                id: cpinField
                label: "Code PIN de la console (facultatif)"
                hint: "4 chiffres, si la console demande un code à la connexion."
                placeholder: "0000"
                secret: true
                maximumLength: 4
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator { regularExpression: /^$|[0-9]{4}/ }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        enabled: !page.registering
        spacing: Theme.unit * 2
        Item { Layout.fillWidth: true }
        FpButton {
            text: "Annuler"
            onClicked: page.back()
        }
        FpButton {
            id: submitBtn
            primary: true
            implicitHeight: 52
            iconName: "check"
            text: "Appairer"
            enabled: page.canSubmit
            onClicked: page.submit()
        }
    }

    // ── Progress / result overlay ──────────────────────────────────────────
    Item {
        parent: page
        anchors.fill: parent
        visible: page.registering
        z: 20
        Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0.02, 0.03, 0.8); MouseArea { anchors.fill: parent } }
        FpGlass {
            anchors.centerIn: parent
            width: Math.min(parent.width - Theme.unit * 8, 720)
            height: Math.min(parent.height - Theme.unit * 8, 520)
            radius: 28
            fillAlpha: 0.95
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.unit * 4
                spacing: Theme.unit * 2
                RowLayout {
                    spacing: Theme.unit * 2
                    Rectangle {
                        Layout.preferredWidth: 12; Layout.preferredHeight: 12; radius: 6
                        color: !page.finished ? Theme.coral : (page.success ? Theme.mint : Theme.alert)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: !page.finished ? "Appairage en cours…" : (page.success ? "Console appairée" : "L'appairage a échoué")
                        font.family: Theme.ui
                        font.pixelSize: Theme.title - 4
                        font.weight: Font.DemiBold
                        color: !page.finished ? Theme.ivory : (page.success ? Theme.mint : Theme.alert)
                    }
                }
                Flickable {
                    id: logFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: logArea.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                    ScrollBar.vertical: FpScrollBar {}
                    Text {
                        id: logArea
                        width: parent.width - 12
                        text: page.logText
                        wrapMode: Text.Wrap
                        font.family: Theme.mono
                        font.pixelSize: Theme.small
                        color: Theme.dim
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    FpButton {
                        id: closeBtn
                        primary: page.finished
                        enabled: page.finished
                        text: page.finished ? "Fermer" : "Patientez…"
                        onClicked: root.closeDialog()
                    }
                }
            }
        }
    }
}
