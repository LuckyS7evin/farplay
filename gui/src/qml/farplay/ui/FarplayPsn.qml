// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls.Basic
import org.streetpea.chiaking

// PlayStation Network screens, hosted in a Farplay frame. Replaces chiaki-ng's
// PSNTokenDialog (mode "token": remote-play token), PSNLoginDialog (mode "login":
// account id for registration) and the public lookup (mode "lookup").
//
// The Sony login page itself is a web page: it is shown in a QtWebEngine view when the
// module is available, otherwise (and on Linux/macOS by default, like chiaki-ng) the
// user opens it in an external browser and pastes the redirect URL back.
FpPage {
    id: page
    property string mode: "token"           // "token" | "login" | "lookup"
    property bool expired: false
    property var callback: null              // login / lookup: callback(accountId)
    property var psnurl: ""

    property bool external: false            // external browser form instead of the web view
    property bool webAvailable: false
    property bool closing: false
    property bool submitting: false
    property string errorText: ""
    property bool logOpen: false
    property bool logDone: false
    property string logText: ""
    property string lookupMessage: ""
    property bool lookupBusy: false

    title: mode === "token" ? (expired ? "Reconnecter PlayStation Network" : "Connexion PlayStation Network")
         : mode === "login" ? "Connexion PSN"
         : "Recherche publique"
    subtitle: mode === "token" ? (expired ? "Vos identifiants ont expiré : reconnectez-vous pour jouer à distance."
                                          : "Appairage automatique et jeu hors de votre réseau.")
            : mode === "login" ? "Récupère l'identifiant de votre compte pour l'appairage."
            : "Retrouve un identifiant de compte à partir du pseudo PSN."
    scrollable: !(webAvailable && !external && mode !== "lookup")
    hints: logOpen ? [["✕", logDone ? "Fermer" : ""]] : [["✕", "Valider"], ["○", "Retour"]]
    onBack: { if (!logOpen) page.closePage() }

    function closePage() {
        if (webHost.web) {
            closing = true
            if (Chiaki.settings.remotePlayAsk) reloadTimer.start()
            else cacheClearTimer.start()
        } else {
            root.closeDialog()
        }
    }
    function useExternal() {
        external = true
        psnurl = Chiaki.openPsnLink()
        if (psnurl) { openUrl.selectAll(); openUrl.copyText() }
        redirectField.forceActiveFocus()
    }
    function handleRedirect(url) {
        if (mode === "token") {
            logText = ""; logDone = false; logOpen = true
            Chiaki.initPsnAuth(url, function(msg, ok, done) {
                if (ok) Chiaki.settings.remotePlayAsk = false
                page.logText += msg + "\n"
                if (done) { page.logDone = true; logClose.forceActiveFocus() }
            })
        } else if (mode === "login") {
            submitting = true
            Chiaki.handlePsnLoginRedirect(url)
        }
    }
    function submitRedirect() {
        if (!redirectField.hasText || submitting) return
        handleRedirect(redirectField.text.trim())
    }
    function cacheCleared() {
        if (closing) root.closeDialog()
        else if (webHost.web) webHost.web.reload()
    }
    function lookup() {
        const username = usernameField.text.trim()
        if (!username.length || lookupBusy) return
        lookupBusy = true
        lookupMessage = ""
        const request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState === XMLHttpRequest.DONE) {
                lookupBusy = false
                let response = {}
                try { response = JSON.parse(request.response) } catch (e) { response = { error: "réponse invalide" } }
                const accountId = response["encoded_id"]
                if (accountId) {
                    if (page.callback) page.callback(accountId)
                    root.closeDialog()
                } else {
                    page.lookupMessage = "Erreur : " + response["error"]
                }
            }
        }
        request.open("GET", "https://psn.flipscreen.games/search.php?username=%1".arg(encodeURIComponent(username)))
        request.send()
    }

    Component.onCompleted: {
        if (mode === "token") Chiaki.settings.remotePlayAsk = true
        if (mode === "lookup") {
            usernameField.forceActiveFocus()
            return
        }
        createWebView()
        if (!webAvailable || Qt.platform.os === "linux" || Qt.platform.os === "osx")
            useExternal()
        else
            reloadBtn.forceActiveFocus()
    }

    function createWebView() {
        try {
            const web = Qt.createQmlObject("
                import QtWebEngine
                import org.streetpea.chiaking
                WebEngineView {
                    profile {
                        offTheRecord: false
                        storageName: 'psn-token'
                        onClearHttpCacheCompleted: page.cacheCleared()
                    }
                    settings {
                        touchIconsEnabled: true
                        localContentCanAccessRemoteUrls: true
                    }
                    onContextMenuRequested: (request) => request.accepted = true
                    onNavigationRequested: (request) => {
                        if (Chiaki.checkPsnRedirectURL(request.url)) {
                            page.handleRedirect(request.url)
                            request.reject()
                        } else {
                            request.accept()
                        }
                    }
                    onCertificateError: console.error(error.description)
                }", webHost, "webView")
            Chiaki.setWebEngineHints(web.profile)
            web.url = Chiaki.psnLoginUrl()
            web.anchors.fill = webHost
            webHost.web = web
            webAvailable = true
        } catch (error) {
            console.error("Create webengine view failed with error:" + error)
            webAvailable = false
        }
    }

    Timer {
        id: reloadTimer
        interval: 0
        onTriggered: {
            Chiaki.clearCookies(webHost.web.profile)
            webHost.web.profile.clearHttpCache()
        }
    }
    Timer {
        id: cacheClearTimer
        interval: 0
        onTriggered: webHost.web.profile.clearHttpCache()
    }

    Connections {
        target: Chiaki
        function onPsnLoginAccountIdDone(accountId) {
            if (page.mode !== "login") return
            if (page.callback) page.callback(accountId)
            page.submitting = false
            page.closePage()
        }
        function onPsnLoginAccountIdError(error) {
            if (page.mode !== "login") return
            page.errorText = error
            page.submitting = false
        }
    }

    // Keyboard shortcuts of the web view (the controller shoulder buttons).
    Keys.onPressed: (event) => {
        if (event.modifiers || mode === "lookup") return
        if (event.key === Qt.Key_PageUp && webAvailable) { reloadTimer.start(); event.accepted = true }
        else if (event.key === Qt.Key_PageDown) { useExternal(); event.accepted = true }
    }

    // ── Web view mode ──────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        visible: page.mode !== "lookup" && page.webAvailable && !page.external
        spacing: Theme.unit * 2
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.unit * 2
            FpButton {
                id: reloadBtn
                text: "Recharger et effacer les cookies"
                fontSize: Theme.small + 1
                onClicked: reloadTimer.start()
            }
            FpButton {
                id: extBtn
                text: "Navigateur externe"
                fontSize: Theme.small + 1
                onClicked: page.useExternal()
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 4
                radius: 2
                color: Qt.rgba(0.96, 0.945, 0.933, 0.12)
                visible: webHost.web !== null
                Rectangle {
                    width: parent.width * (webHost.web ? webHost.web.loadProgress / 100 : 0)
                    height: parent.height
                    radius: 2
                    color: Theme.coral
                }
            }
        }
        FpGlass {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(360, page.flick.height - 120)
            radius: 24
            fillAlpha: 0.9
            clip: true
            Item {
                id: webHost
                property Item web: null
                anchors.fill: parent
                anchors.margins: 2
            }
        }
    }

    // ── External browser mode ──────────────────────────────────────────────
    FpGlass {
        Layout.fillWidth: true
        visible: page.mode !== "lookup" && page.external
        implicitHeight: extCol.implicitHeight + Theme.unit * 6
        radius: 24
        fillAlpha: 0.7
        ColumnLayout {
            id: extCol
            x: Theme.unit * 3
            y: Theme.unit * 3
            width: parent.width - Theme.unit * 6
            spacing: Theme.unit * 2.5
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: page.psnurl ? "1. Le lien de connexion PlayStation s'est ouvert dans votre navigateur (il est aussi copié dans le presse-papiers).\n2. Connectez-vous, puis copiez l'adresse de la page vers laquelle Sony vous redirige et collez-la ci-dessous."
                                  : "Connectez-vous à PlayStation Network dans votre navigateur, puis copiez l'adresse de la page vers laquelle Sony vous redirige et collez-la ci-dessous."
                font.family: Theme.ui
                font.pixelSize: Theme.body - 1
                lineHeight: 1.15
                color: Theme.ivory
            }
            // Hidden carrier used to put the link on the clipboard.
            TextInput {
                id: openUrl
                visible: false
                text: page.psnurl
                function copyText() { selectAll(); copy() }
            }
            RowLayout {
                spacing: Theme.unit * 2
                visible: page.psnurl !== ""
                FpButton {
                    id: copyBtn
                    text: "Copier à nouveau le lien"
                    fontSize: Theme.small + 1
                    onClicked: openUrl.copyText()
                }
                FpButton {
                    id: webBtn
                    visible: page.webAvailable
                    text: "Utiliser la fenêtre intégrée"
                    fontSize: Theme.small + 1
                    onClicked: { page.external = false; reloadBtn.forceActiveFocus() }
                }
            }
            FpTextField {
                id: redirectField
                label: "Adresse de redirection"
                placeholder: "https://remoteplay.dl.playstation.net/…"
                secret: true
                onAccepted: page.submitRedirect()
            }
            Text {
                Layout.fillWidth: true
                visible: page.errorText !== ""
                wrapMode: Text.WordWrap
                text: "Échec de la récupération de l'identifiant : " + page.errorText
                font.family: Theme.ui
                font.pixelSize: Theme.small
                color: Theme.alert
            }
            RowLayout {
                spacing: Theme.unit * 2
                FpButton {
                    id: pasteBtn
                    text: "Coller"
                    onClicked: redirectField.paste()
                }
                Item { Layout.fillWidth: true }
                FpButton {
                    id: submitBtn
                    primary: true
                    implicitHeight: 52
                    iconName: "check"
                    text: page.mode === "token" ? "Connecter" : "Récupérer l'identifiant"
                    enabled: redirectField.hasText && !page.submitting
                    onClicked: page.submitRedirect()
                }
            }
        }
    }

    // ── Public lookup ──────────────────────────────────────────────────────
    FpGlass {
        Layout.fillWidth: true
        visible: page.mode === "lookup"
        implicitHeight: lookCol.implicitHeight + Theme.unit * 6
        radius: 24
        fillAlpha: 0.7
        ColumnLayout {
            id: lookCol
            x: Theme.unit * 3
            y: Theme.unit * 3
            width: parent.width - Theme.unit * 6
            spacing: Theme.unit * 2.5
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Nécessite que vos réglages de confidentialité PSN autorisent tout le monde à vous trouver dans une recherche."
                font.family: Theme.ui
                font.pixelSize: Theme.body - 1
                color: Theme.dim
            }
            FpTextField {
                id: usernameField
                label: "Pseudo PSN"
                placeholder: "pseudo"
                secret: true
                onAccepted: page.lookup()
            }
            Text {
                Layout.fillWidth: true
                visible: page.lookupMessage !== ""
                wrapMode: Text.WordWrap
                text: page.lookupMessage
                font.family: Theme.ui
                font.pixelSize: Theme.small
                color: Theme.alert
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                FpButton {
                    id: lookupGo
                    primary: true
                    implicitHeight: 52
                    text: page.lookupBusy ? "Recherche…" : "Rechercher"
                    enabled: usernameField.hasText && !page.lookupBusy
                    onClicked: page.lookup()
                }
            }
        }
    }

    // ── Token creation log ─────────────────────────────────────────────────
    Item {
        parent: page
        anchors.fill: parent
        visible: page.logOpen
        z: 20
        Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0.02, 0.03, 0.8); MouseArea { anchors.fill: parent } }
        FpGlass {
            anchors.centerIn: parent
            width: Math.min(parent.width - Theme.unit * 8, 720)
            height: Math.min(parent.height - Theme.unit * 8, 480)
            radius: 28
            fillAlpha: 0.95
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.unit * 4
                spacing: Theme.unit * 2
                Text {
                    Layout.fillWidth: true
                    text: page.logDone ? "Connexion PSN terminée" : "Connexion à PSN…"
                    font.family: Theme.ui
                    font.pixelSize: Theme.title - 4
                    font.weight: Font.DemiBold
                    color: Theme.ivory
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
                        id: logClose
                        primary: page.logDone
                        enabled: page.logDone
                        text: page.logDone ? "Fermer" : "Patientez…"
                        // chiaki-ng returns to the main view once the token flow is over.
                        onClicked: { page.logOpen = false; root.showMainView() }
                    }
                }
            }
        }
    }
}
