// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Farplay — écran plein cadre de la partie : connexion en cours, vidéo désactivée, erreur.
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

FocusScope {
    id: root
    property bool loading: true
    property bool errorActive: false
    property string errorTitle: ""
    property string errorText: ""
    property bool videoDisabled: false
    property bool audioDisabled: false
    property string menuShortcut: "Ctrl+O"
    property string dpadShortcut: ""
    property bool dpadTouch: false
    property string host: ""
    property bool connected: false
    signal backRequested()
    function focusAction() { backBtn.forceActiveFocus() }

    readonly property bool showError: errorActive && errorTitle !== ""
    readonly property bool showDisabled: !loading && !errorActive && videoDisabled

    Rectangle { anchors.fill: parent; color: Theme.night }
    // Halo corail très discret derrière le logo
    Rectangle {
        width: Math.min(parent.width, 900); height: width
        radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.42 - height / 2
        color: "transparent"
        Canvas {
            anchors.fill: parent
            onPaint: {
                var c = getContext("2d"); c.reset()
                var g = c.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width / 2)
                g.addColorStop(0, "rgba(255,107,74,0.10)"); g.addColorStop(1, "rgba(255,107,74,0)")
                c.fillStyle = g; c.fillRect(0, 0, width, height)
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.42 - height / 2)
        width: Math.min(parent.width - 96, 720)
        spacing: 18

        FpLogo {
            Layout.alignment: Qt.AlignHCenter
            size: root.height > 600 ? 84 : 60
            visible: !root.showError
        }
        // Pastille d'erreur
        Rectangle {
            visible: root.showError
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64; Layout.preferredHeight: 64
            radius: 32
            color: Qt.rgba(0.9, 0.28, 0.3, 0.16)
            border.width: 1
            border.color: Qt.rgba(0.9, 0.28, 0.3, 0.6)
            Text { anchors.centerIn: parent; text: "!"; font.family: Theme.ui; font.pixelSize: 34; font.weight: Font.Bold; color: Theme.alert }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: Theme.ui
            font.pixelSize: Theme.title
            font.weight: Font.DemiBold
            color: Theme.ivory
            text: root.showError ? root.errorTitle
                : root.showDisabled ? (root.audioDisabled ? "Audio et vidéo désactivés" : "Vidéo désactivée")
                : root.connected ? "Démarrage de l'image…" : "Connexion à la PS5…"
        }
        Text {
            Layout.fillWidth: true
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: Theme.ui
            font.pixelSize: Theme.body
            lineHeight: 1.25
            color: Theme.dim
            text: root.showError ? root.errorText
                : root.showDisabled ? "Vous avez désactivé " + (root.audioDisabled ? "l'audio et la vidéo" : "la vidéo") + " dans les réglages.\nPour les réactiver, repassez Audio/Vidéo sur « Activés » dans l'onglet Général."
                : (root.host !== "" ? root.host : "")
        }

        // Fine barre de progression indéterminée
        Item {
            visible: root.loading && !root.showError
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            Layout.preferredWidth: 280
            Layout.preferredHeight: 4
            clip: true
            Rectangle { anchors.fill: parent; radius: 2; color: Theme.line }
            Rectangle {
                id: runner
                width: 96; height: 4; radius: 2
                color: Theme.coral
                x: -width
                SequentialAnimation on x {
                    running: root.loading && !root.showError && root.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: -96; to: 280; duration: 1300; easing.type: Easing.InOutCubic }
                    PauseAnimation { duration: 120 }
                }
            }
        }

        FpButton {
            id: backBtn
            visible: root.showError
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 18
            primary: true
            text: "Retour"
            iconName: "back"
            onClicked: root.backRequested()
            Keys.onEscapePressed: root.backRequested()
        }
    }

    // Aide en bas d'écran pendant la connexion
    Column {
        visible: root.loading && !root.showError
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.audioDisabled
            text: "Audio désactivé dans les réglages"
            font.family: Theme.ui; font.pixelSize: Theme.small + 1; color: Theme.dim
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "%1 : réglages rapides et quitter".arg(root.menuShortcut)
            font.family: Theme.ui; font.pixelSize: Theme.small + 1; color: Theme.dim
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.dpadTouch && root.dpadShortcut !== ""
            text: "%1 : basculer croix directionnelle / pavé tactile".arg(root.dpadShortcut)
            font.family: Theme.ui; font.pixelSize: Theme.small + 1; color: Theme.dim
        }
    }
}
