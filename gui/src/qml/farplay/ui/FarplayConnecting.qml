// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import org.streetpea.chiaking

// "Connecting" screen. Replaces chiaki-ng's AutoConnectView (mode "auto": waiting for the
// console to wake up) and PsnView (mode "psn": remote connection / automatic registration
// over PSN), including the console login PIN prompt.
FocusScope {
    id: view
    property string mode: "auto"             // "auto" | "psn"
    property bool allowClose: false
    property bool cancelling: false
    property bool textVisible: mode === "psn"
    property bool registOnly: false
    property string info: mode === "psn" ? "Connexion à la console via PSN…" : "En attente de la console…"
    property string errorTitle: ""
    property string errorText: ""
    property bool pinOpen: false
    property var restoreFocusItem: null

    anchors.fill: parent
    Component.onCompleted: forceActiveFocus()

    function stop() {
        if (!allowClose) return
        if (mode === "psn") {
            allowClose = false
            cancelling = true
            info = "Annulation de la connexion PSN…"
            Chiaki.psnCancel(false)
        } else {
            Chiaki.stopAutoConnect()
            root.showMainView()
        }
    }
    function cancel() {
        if (mode === "psn") { stop(); return }
        if (!allowClose) return
        textVisible = false
        info = "Annulation de la connexion…"
        failTimer.start()
    }
    function cancelHint() {
        const what = mode === "psn" ? (registOnly ? "l'appairage automatique" : "la connexion PSN") : "la connexion"
        return "Appuyez sur " + (Chiaki.controllers.length ? "○" : "Échap ou clic droit") + " pour annuler " + what
    }
    function openPin() {
        if (pinOpen) return
        textVisible = false
        restoreFocusItem = Window.window ? Window.window.activeFocusItem : null
        Chiaki.window.grabInput()
        pinOpen = true
        pinField.text = ""
        pinField.forceActiveFocus()
    }
    function closePin() {
        pinOpen = false
        textVisible = true
        Chiaki.window.releaseInput()
        view.forceActiveFocus()
    }

    Keys.onEscapePressed: {
        if (errorTitle !== "") root.showMainView()
        else view.cancel()
    }
    Keys.onReturnPressed: { if (errorTitle !== "") root.showMainView() }
    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: view.cancel()
    }
    MouseArea {
        anchors.fill: parent
        enabled: view.allowClose
        acceptedButtons: Qt.RightButton
        onClicked: view.cancel()
    }

    Rectangle { anchors.fill: parent; color: Theme.night }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 0.42, 0.29, 0.10) }
            GradientStop { position: 0.55; color: "transparent" }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.unit * 8, 720)
        spacing: Theme.unit * 3

        FpLogo { Layout.alignment: Qt.AlignHCenter; size: 56 }

        // Spinner
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            visible: view.errorTitle === ""
            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: Qt.rgba(0.96, 0.945, 0.933, 0.12)
                    strokeWidth: 3
                    fillColor: "transparent"
                    PathAngleArc { centerX: 32; centerY: 32; radiusX: 28; radiusY: 28; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: Theme.coral
                    strokeWidth: 3
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc { centerX: 32; centerY: 32; radiusX: 28; radiusY: 28; startAngle: -90; sweepAngle: 100 }
                }
                RotationAnimator on rotation { from: 0; to: 360; duration: 1100; loops: Animation.Infinite; running: view.visible && view.errorTitle === "" }
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: view.errorTitle === ""
            text: view.info
            wrapMode: Text.WordWrap
            font.family: Theme.ui
            font.pixelSize: Theme.title - 2
            font.weight: Font.DemiBold
            color: Theme.ivory
        }

        // Error
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: view.errorTitle !== ""
            text: view.errorTitle
            wrapMode: Text.WordWrap
            font.family: Theme.ui
            font.pixelSize: Theme.title - 2
            font.weight: Font.DemiBold
            color: Theme.alert
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: view.errorTitle !== ""
            text: view.errorText
            wrapMode: Text.WordWrap
            font.family: Theme.ui
            font.pixelSize: Theme.body
            color: Theme.dim
        }

        FpButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.unit * 2
            visible: view.errorTitle !== ""
            primary: true
            text: "Retour à l'accueil"
            onClicked: root.showMainView()
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.unit * 6
        opacity: view.textVisible && !view.cancelling && view.errorTitle === "" ? 1 : 0
        visible: opacity > 0
        text: view.cancelHint()
        font.family: Theme.ui
        font.pixelSize: Theme.small + 1
        color: Theme.dim
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    // ── Console login PIN ──────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: view.pinOpen
        z: 10
        Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0.02, 0.03, 0.8); MouseArea { anchors.fill: parent } }
        FpGlass {
            anchors.centerIn: parent
            width: Math.min(parent.width - Theme.unit * 8, 520)
            height: pinCol.implicitHeight + Theme.unit * 8
            radius: 28
            fillAlpha: 0.95
            ColumnLayout {
                id: pinCol
                anchors.fill: parent
                anchors.margins: Theme.unit * 4
                spacing: Theme.unit * 2.5
                Text {
                    text: "Code PIN de la console"
                    font.family: Theme.ui
                    font.pixelSize: Theme.title - 4
                    font.weight: Font.DemiBold
                    color: Theme.ivory
                }
                FpTextField {
                    id: pinField
                    label: "4 chiffres"
                    placeholder: "0000"
                    secret: true
                    maximumLength: 4
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: RegularExpressionValidator { regularExpression: /[0-9]{0,4}/ }
                    onAccepted: pinOk.clicked()
                    KeyNavigation.down: pinOk
                    Keys.onEscapePressed: pinCancel.clicked()
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.unit * 2
                    Item { Layout.fillWidth: true }
                    FpButton {
                        id: pinCancel
                        text: "Annuler"
                        onClicked: { view.closePin(); Chiaki.stopSession(false) }
                        KeyNavigation.right: pinOk
                        KeyNavigation.up: pinField
                    }
                    FpButton {
                        id: pinOk
                        primary: true
                        text: "Valider"
                        enabled: pinField.text.length === 4 && pinField.acceptable
                        onClicked: { if (!enabled) return; Chiaki.enterPin(pinField.text); view.closePin() }
                        KeyNavigation.left: pinCancel
                        KeyNavigation.up: pinField
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: { view.allowClose = true; view.textVisible = true }
    }
    Timer {
        id: failTimer
        interval: 2000
        onTriggered: { if (view.mode === "auto") Chiaki.stopAutoConnect(); root.showMainView() }
    }

    Connections {
        target: Chiaki

        // auto mode
        function onWakeupStartFailed() {
            if (view.mode !== "auto") return
            view.textVisible = false
            view.info = "Délai dépassé en attendant la console. Retour à l'accueil…"
            failTimer.start()
        }

        // psn mode
        function onConnectStateChanged() {
            if (view.mode !== "psn") return
            switch (Chiaki.connectState) {
            case Chiaki.PsnConnectState.LinkingConsole:
                view.info = view.registOnly ? "Appairage de la console avec Farplay…" : "Association de Farplay à la console…"
                view.allowClose = false
                break
            case Chiaki.PsnConnectState.RegisteringConsole:
                view.registOnly = true
                break
            case Chiaki.PsnConnectState.RegistrationFinished:
                view.info = "Console appairée"
                failTimer.restart()
                break
            case Chiaki.PsnConnectState.DataConnectionStart:
                view.info = "Console associée… établissement de la connexion de données via PSN"
                view.allowClose = true
                break
            case Chiaki.PsnConnectState.DataConnectionFinished:
                view.allowClose = false
                break
            case Chiaki.PsnConnectState.ConnectFailed:
                if (!view.cancelling) view.info = "La connexion via PSN a échoué, fermeture…"
                failTimer.running = true
                break
            case Chiaki.PsnConnectState.ConnectFailedStart:
                if (!view.cancelling) view.info = "PSN n'a pas pu joindre la PlayStation. Réessayez…"
                failTimer.running = true
                break
            case Chiaki.PsnConnectState.ConnectFailedConsoleUnreachable:
                if (!view.cancelling) view.info = "La PlayStation est injoignable, type de réseau probablement non pris en charge"
                failTimer.running = true
                break
            case Chiaki.PsnConnectState.WaitingForInternet:
                view.info = "Connexion à Internet pour joindre PSN…"
                break
            }
        }
        function onSessionChanged() {
            if (view.mode !== "psn") return
            if (!Chiaki.session) {
                if (view.errorTitle !== "") failTimer.start()
                else if (!failTimer.running) root.showMainView()
            }
        }
        function onSessionError(title, text) {
            if (view.mode !== "psn") return
            view.errorTitle = title
            view.errorText = text
            view.textVisible = false
            view.allowClose = false
            view.forceActiveFocus()
        }
        function onSessionPinDialogRequested() {
            if (view.mode !== "psn") return
            view.openPin()
        }
    }
}
