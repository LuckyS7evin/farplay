// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import org.streetpea.chiaking

FocusScope {
    id: page
    anchors.fill: parent

    // Displayed section (index in `cats`). Action entries (Accueil, Diagnostic) never become current.
    property int cat: 2
    // Opens directly on a section (id of `cats`); "overlay" = shown over a running game.
    property string section: ""
    property bool overlay: false
    readonly property string catId: cats[cat].id
    property bool ps5Sel: true
    readonly property bool live: !!Chiaki.session
    readonly property var snap: Farplay.snapshot || ({})
    readonly property var cats: [
        { id: "home", text: "Accueil", icon: "home", action: true },
        { id: "consoles", text: "Consoles", icon: "display", sub: "Consoles appairées, compte PlayStation Network." },
        { id: "image", text: "Image", icon: "image", sub: "Qualité du flux et de l'agrandissement." },
        { id: "fluid", text: "Fluidité", icon: "framegen", sub: "Plus d'images par seconde, sans changer le jeu." },
        { id: "color", text: "Couleur & HDR", icon: "color", sub: "Rendu des couleurs et de la luminosité." },
        { id: "display", text: "Affichage", icon: "fullscreen", sub: "Fenêtre, synchronisation, statistiques et fin de session." },
        { id: "pad", text: "Manette & son", icon: "mic", sub: "Audio, manette, clavier et raccourcis." },
        { id: "network", text: "Réseau", icon: "stats", sub: "Jeu à distance, qualité de connexion." },
        { id: "profiles", text: "Profils", icon: "profiles", sub: "Enregistrez et rappelez vos combinaisons de réglages." },
        { id: "diag", text: "Diagnostic", icon: "diagnostic", action: true }
    ]
    readonly property real budgetMs: 8

    function fmt(v, d, unit) {
        return (!live || v === undefined || v === null) ? "—" : Number(v).toFixed(d) + (unit ? " " + unit : "")
    }
    function activateCat(i) {
        if (i === 0) leave()
        else if (cats[i].id === "diag") { if (!overlay) root.showFarplayView("qrc:/farplay/ui/FarplayDiagnostic.qml") }
        else focusContent()
    }
    function leave() {
        if (overlay) root.closeSettingsOverlay()
        else root.showMainView()
    }
    function firstFocusable(it) {
        for (var i = 0; i < it.children.length; i++) {
            var c = it.children[i]
            if (!c.visible || !c.enabled) continue
            if (c.activeFocusOnTab === true) return c
            var r = firstFocusable(c)
            if (r) return r
        }
        return null
    }
    function focusContent() {
        var f = firstFocusable(contentCol)
        if (f) f.forceActiveFocus()
    }
    function focusSidebar() {
        var it = sideRepeater.itemAt(page.cat)
        if (it) it.forceActiveFocus()
    }
    function recommended() {
        FarplayImage.resetRecommended()
        FarplayFrameGen.mode = 1
        FarplayFrameGen.multiplier = 2
        FarplayFrameGen.hudProtect = true
        FarplayFrameGen.pacing = true
    }

    Keys.onEscapePressed: { if (sidebar.activeFocus) leave(); else focusSidebar() }
    Component.onCompleted: {
        for (var i = 0; i < cats.length; i++)
            if (cats[i].id === section) cat = i
        focusSidebar()
    }
    // Back from a pushed sub-screen (register, PSN...): restore focus.
    StackView.onActivated: if (!activeFocus) focusSidebar()

    Rectangle { anchors.fill: parent; color: Theme.night }

    // ── Sidebar ────────────────────────────────────────────────────────────
    FocusScope {
        id: sidebar
        readonly property bool fpNavGroup: true
        width: 280
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.left: parent.left

        Rectangle { anchors.fill: parent; color: Theme.side }
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

        RowLayout {
            x: Theme.unit * 3
            y: Theme.unit * 3
            spacing: Theme.unit * 1.5
            FpLogo { size: 30 }
            Text {
                text: "Farplay"
                font.family: Theme.ui
                font.pixelSize: Theme.body + 2
                font.weight: Font.DemiBold
                color: Theme.ivory
            }
        }

        Flickable {
            id: sideFlick
            anchors.top: parent.top
            anchors.topMargin: 88
            anchors.left: parent.left
            anchors.leftMargin: Theme.unit * 2
            anchors.right: parent.right
            anchors.rightMargin: Theme.unit * 2
            anchors.bottom: hostCard.visible ? hostCard.top : parent.bottom
            anchors.bottomMargin: Theme.unit
            contentWidth: width
            contentHeight: sideCol.implicitHeight + Theme.unit
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: FpScrollBar {}
            Column {
                id: sideCol
                width: parent.width
                spacing: 4
                Repeater {
                    id: sideRepeater
                    model: page.cats
                    delegate: FpSidebarItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        text: modelData.text
                        iconName: modelData.icon
                        current: !modelData.action && page.cat === index
                        onActiveFocusChanged: if (activeFocus && !modelData.action) page.cat = index
                        onActivated: page.activateCat(index)
                        Keys.onUpPressed: { var it = sideRepeater.itemAt(index - 1); if (it) it.forceActiveFocus() }
                        Keys.onDownPressed: { var it = sideRepeater.itemAt(index + 1); if (it) it.forceActiveFocus() }
                        Keys.onRightPressed: { if (!modelData.action) page.focusContent() }
                    }
                }
            }
        }

        // Current console
        Rectangle {
            id: hostCard
            readonly property var h: (Chiaki.hosts && Chiaki.hosts.length > 0) ? Chiaki.hosts[0] : null
            visible: h !== null
            x: Theme.unit * 2
            width: parent.width - Theme.unit * 4
            height: 62
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.unit * 2
            radius: Theme.radius
            color: Theme.graphite
            border.width: 1
            border.color: Theme.line
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                spacing: 12
                Rectangle {
                    width: 10; height: 10; radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.parent.h && parent.parent.h.state === "ready" ? Theme.mint : Theme.dim
                }
                Column {
                    spacing: 2
                    Text {
                        text: parent.parent.parent.h ? parent.parent.parent.h.name : ""
                        font.family: Theme.ui
                        font.pixelSize: Theme.body - 2
                        font.weight: Font.Medium
                        color: Theme.ivory
                    }
                    Text {
                        readonly property var hh: parent.parent.parent.h
                        text: hh ? (hh.state === "ready" ? "Prête" : hh.state === "standby" ? "En veille" : "Introuvable") + (hh.address ? " · " + hh.address : "") : ""
                        font.family: Theme.mono
                        font.pixelSize: Theme.small - 2
                        color: Theme.dim
                    }
                }
            }
        }
    }

    // ── Content ────────────────────────────────────────────────────────────
    FocusScope {
        id: contentScope
        readonly property bool fpNavGroup: true
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: pipeline.visible ? pipeline.top : footer.top
        anchors.bottomMargin: pipeline.visible ? Theme.unit * 2 : 0

        Keys.onLeftPressed: { if (!Theme.navMove(page.Window.window, "left", true)) page.focusSidebar() }

        readonly property real colWidth: Math.min(width - Theme.unit * 10, 1040)
        readonly property real colX: Math.max(Theme.unit * 5, (width - colWidth) / 2)

        // Page header
        Item {
            id: header
            x: contentScope.colX
            y: Theme.unit * 3
            width: contentScope.colWidth
            height: 64
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: page.cats[page.cat].text
                    font.family: Theme.ui
                    font.pixelSize: Theme.title
                    font.weight: Font.DemiBold
                    color: Theme.ivory
                }
                Text {
                    text: page.cats[page.cat].sub || ""
                    font.family: Theme.ui
                    font.pixelSize: Theme.body - 2
                    color: Theme.dim
                }
            }
            FpButton {
                id: recoBtn
                visible: ["image", "fluid", "color", "display"].indexOf(page.catId) >= 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "check"
                text: "Recommandé"
                onClicked: page.recommended()
                Keys.onUpPressed: {}
            }
        }

        Flickable {
            id: flick
            anchors.top: header.bottom
            anchors.topMargin: Theme.unit * 2
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            contentWidth: width
            contentHeight: contentCol.implicitHeight + Theme.unit * 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: FpScrollBar {}

            Item {
                id: contentCol
                x: contentScope.colX
                y: 4
                width: contentScope.colWidth
                implicitHeight: Math.max(consolesPage.visible ? consolesPage.implicitHeight : 0,
                                         padWrap.visible ? padWrap.implicitHeight : 0,
                                         networkPage.visible ? networkPage.implicitHeight : 0,
                                         imagePage.visible ? imagePage.implicitHeight : 0,
                                         fluidPage.visible ? fluidPage.implicitHeight : 0,
                                         colorPage.visible ? colorPage.implicitHeight : 0,
                                         displayPage.visible ? displayPage.implicitHeight : 0,
                                         profilesPage.visible ? profilesPage.implicitHeight : 0)
                height: implicitHeight

                // ── Consoles ────────────────────────────────────────────
                FarplaySetConsoles {
                    id: consolesPage
                    visible: page.catId === "consoles"
                    width: parent.width
                }

                // ── Manette & son ───────────────────────────────────────
                ColumnLayout {
                    id: padWrap
                    visible: page.catId === "pad"
                    width: parent.width
                    spacing: Theme.unit * 2
                    FarplaySetAudio { id: audioPage; Layout.fillWidth: true }
                    FarplaySetPad { id: padPage; Layout.fillWidth: true; overlayParent: page }
                }

                // ── Réseau ──────────────────────────────────────────────
                FarplaySetNetwork {
                    id: networkPage
                    visible: page.catId === "network"
                    width: parent.width
                    ps5: page.ps5Sel
                }

                // ── Image ───────────────────────────────────────────────
                ColumnLayout {
                    id: imagePage
                    visible: page.catId === "image"
                    width: parent.width
                    spacing: Theme.unit * 2

                    FpSectionCard {
                        iconName: "stats"
                        title: "Flux"
                        subtitle: "Résolution, cadence et qualité de l'image envoyée par la console."
                        FpSettingRow {
                            title: "Console"
                            description: "Les réglages ci-dessous s'appliquent à ce modèle."
                            FpSegmented {
                                model: ["PS5", "PS4"]
                                currentIndex: page.ps5Sel ? 0 : 1
                                onActivated: (i) => page.ps5Sel = (i === 0)
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Résolution"
                            description: "Sur le réseau local. Changer la résolution rétablit le débit conseillé."
                            costs: ({ image: "+", latence: "−" })
                            FpSegmented {
                                readonly property int res: page.ps5Sel ? Chiaki.settings.resolutionLocalPS5 : Chiaki.settings.resolutionLocalPS4
                                model: ["360p", "540p", "720p", "1080p"]
                                currentIndex: Math.max(0, res - 1)
                                onActivated: (i) => {
                                    if (page.ps5Sel) { Chiaki.settings.resolutionLocalPS5 = i + 1; Chiaki.settings.bitrateLocalPS5 = 0 }
                                    else { Chiaki.settings.resolutionLocalPS4 = i + 1; Chiaki.settings.bitrateLocalPS4 = 0 }
                                }
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Images par seconde"
                            description: "Régler sur la cadence du jeu évite les images dupliquées."
                            costs: ({ fluidite: "+", latence: "−" })
                            FpSegmented {
                                model: ["30", "60"]
                                currentIndex: (page.ps5Sel ? Chiaki.settings.fpsLocalPS5 : Chiaki.settings.fpsLocalPS4) === 60 ? 1 : 0
                                onActivated: (i) => {
                                    if (page.ps5Sel) { Chiaki.settings.fpsLocalPS5 = (i + 1) * 30; Chiaki.settings.fpsRemotePS5 = (i + 1) * 30 }
                                    else { Chiaki.settings.fpsLocalPS4 = (i + 1) * 30; Chiaki.settings.fpsRemotePS4 = (i + 1) * 30 }
                                }
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Bitrate"
                            description: "Plus haut = image plus nette, demande un réseau stable."
                            costs: ({ image: "+" })
                            FpSlider {
                                readonly property int res: page.ps5Sel ? Chiaki.settings.resolutionLocalPS5 : Chiaki.settings.resolutionLocalPS4
                                readonly property int raw: page.ps5Sel ? Chiaki.settings.bitrateLocalPS5 : Chiaki.settings.bitrateLocalPS4
                                width: 320
                                from: 2; to: 100; stepSize: 1; unit: "Mbps"
                                value: raw ? raw / 1000 : [0, 2, 6, 10, 15][Math.max(1, Math.min(4, res))]
                                onMoved: (v) => { if (page.ps5Sel) Chiaki.settings.bitrateLocalPS5 = v * 1000; else Chiaki.settings.bitrateLocalPS4 = v * 1000 }
                            }
                        }
                        FpSettingRow {
                            visible: page.ps5Sel
                            divider: true
                            title: "Codec vidéo"
                            description: "H.265 est plus efficace. H.265 HDR demande un écran HDR." + (Chiaki.session ? " S'applique à la prochaine connexion." : "")
                            FpSegmented {
                                readonly property bool gl: Chiaki.settings.rendererBackend === 1
                                model: gl ? ["H.264", "H.265"] : ["H.264", "H.265", "H.265 HDR"]
                                currentIndex: Math.min(Chiaki.settings.codecLocalPS5, gl ? 1 : 2)
                                onActivated: (i) => Chiaki.settings.codecLocalPS5 = i
                            }
                        }
                    }
                    FpSectionCard {
                        iconName: "image"
                        title: "Upscaling"
                        subtitle: "Agrandit l'image reçue vers la résolution de l'écran."
                        costs: ({ image: "+", gpu: "+" })
                        FpSettingRow {
                            title: "Méthode"
                            description: "FSR 1 est léger. FSRCNNX et libplacebo sont plus fins mais plus lourds."
                            FpSegmented {
                                model: ["chiaki-ng", "FSR 1", "FSRCNNX", "libplacebo"]
                                currentIndex: FarplayImage.upscaler
                                onActivated: (i) => FarplayImage.upscaler = i
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Netteté"
                            description: "Renforce les contours après l'agrandissement. Trop haut = halos."
                            costs: ({ image: "+" })
                            FpSlider {
                                width: 320
                                from: 0; to: 100; stepSize: 5; unit: "%"
                                value: FarplayImage.sharpness
                                onMoved: (v) => FarplayImage.sharpness = v
                            }
                        }
                    }
                    FpSectionCard {
                        iconName: "image"
                        title: "Réduction des artefacts"
                        subtitle: "Nettoie le flux avant l'agrandissement."
                        costs: ({ image: "+", gpu: "+" })
                        FpSettingRow {
                            title: "Réduction des artefacts"
                            description: "Atténue les blocs et le bruit de compression du flux avant l'agrandissement"
                            costs: ({ image: "+", gpu: "+" })
                            FpSegmented {
                                model: ["Coupée", "Faible", "Moyenne", "Forte"]
                                currentIndex: FarplayImage.denoise
                                onActivated: (i) => FarplayImage.denoise = i
                            }
                        }
                        FpSettingRow {
                            title: "Couleurs nettes"
                            description: "Reconstruit la couleur, transmise en demi-résolution, à l'aide de la luminance (bords colorés, HUD, textes)"
                            costs: ({ image: "+", gpu: "+" })
                            FpSwitch {
                                checked: FarplayImage.chromaFromLuma
                                onToggled: (c) => FarplayImage.chromaFromLuma = c
                            }
                        }
                    }
                    FpSectionCard {
                        iconName: "color"
                        title: "Lissage des dégradés"
                        subtitle: "Atténue les marches de couleur dues à la compression."
                        costs: ({ image: "+", gpu: "+" })
                        FpSettingRow {
                            title: "Intensité"
                            FpSegmented {
                                model: ["Coupé", "Faible", "Moyen"]
                                currentIndex: FarplayImage.deband
                                onActivated: (i) => FarplayImage.deband = i
                            }
                        }
                    }
                }

                // ── Fluidité ────────────────────────────────────────────
                ColumnLayout {
                    id: fluidPage
                    visible: page.catId === "fluid"
                    width: parent.width
                    spacing: Theme.unit * 2

                    FpSectionCard {
                        iconName: "framegen"
                        title: "Génération d'images"
                        subtitle: "Crée une image intermédiaire entre deux images reçues."
                        costs: ({ fluidite: "+", latence: "+", gpu: "+" })
                        hasToggle: true
                        checked: FarplayFrameGen.mode !== 0
                        onToggled: (c) => FarplayFrameGen.mode = c ? 1 : 0
                        FpSettingRow {
                            title: "Mode"
                            description: "Interne : calcul sur votre GPU. AFMF : pilote AMD."
                            FpSegmented {
                                model: ["Coupée", "Interne", "AFMF"]
                                currentIndex: FarplayFrameGen.mode
                                onActivated: (i) => FarplayFrameGen.mode = i
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Multiplicateur"
                            description: "Images affichées pour chaque image reçue. « Écran » suit la fréquence du moniteur."
                            FpSegmented {
                                readonly property var values: [2, 3, 4, 0]
                                enabled: FarplayFrameGen.mode === 1
                                model: ["x2", "x3", "x4", "Écran"]
                                currentIndex: Math.max(0, values.indexOf(FarplayFrameGen.multiplier))
                                onActivated: (i) => FarplayFrameGen.multiplier = values[i]
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Protection du HUD"
                            description: "Évite que la mini-map et les textes tremblent."
                            FpSwitch {
                                checked: FarplayFrameGen.hudProtect
                                onToggled: (c) => FarplayFrameGen.hudProtect = c
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Lissage du pacing"
                            description: "Affiche les images à intervalle régulier. Ajoute la marge mesurée (quelques ms) ; le son est décalé d'autant."
                            costs: ({ fluidite: "+", latence: "+" })
                            FpSwitch {
                                checked: FarplayFrameGen.pacing
                                onToggled: (c) => FarplayFrameGen.pacing = c
                            }
                        }
                        Text {
                            Layout.leftMargin: Theme.unit * 2
                            Layout.topMargin: Theme.unit
                            text: "F4 en jeu : couper/rétablir la frame gen"
                            font.family: Theme.ui
                            font.pixelSize: Theme.small - 1
                            color: Theme.dim
                        }
                    }
                }

                // ── Couleur & HDR ───────────────────────────────────────
                ColumnLayout {
                    id: colorPage
                    visible: page.catId === "color"
                    width: parent.width
                    spacing: Theme.unit * 2

                    FpSectionCard {
                        iconName: "display"
                        title: "HDR"
                        subtitle: "Demande un flux HDR à la PS5. Il faut que la console voie un écran HDR." + (Chiaki.session ? " S'applique à la prochaine connexion." : "")
                        costs: ({ image: "+" })
                        hasToggle: true
                        checked: Chiaki.settings.codecLocalPS5 === 2
                        onToggled: (c) => Chiaki.settings.codecLocalPS5 = c ? 2 : 1
                        FpSettingRow {
                            title: "Sortie actuelle"
                            description: page.live ? String(page.snap.output || page.snap.hdr || "—") : "Aucune session en cours"
                        }
                    }
                    FpSectionCard {
                        iconName: "color"
                        title: "SDR sur écran HDR"
                        subtitle: "Affiche un flux SDR avec une luminosité adaptée à l'écran HDR."
                        hasToggle: true
                        checked: FarplayImage.sdrToHdr
                        onToggled: (c) => FarplayImage.sdrToHdr = c
                        FpSettingRow {
                            title: "Luminosité SDR"
                            description: "Luminosité du blanc SDR sur un écran HDR."
                            FpSlider {
                                width: 320
                                enabled: FarplayImage.sdrToHdr
                                from: 80; to: 400; stepSize: 10; unit: "nits"
                                value: FarplayImage.sdrWhiteNits
                                onMoved: (v) => FarplayImage.sdrWhiteNits = v
                            }
                        }
                    }
                }

                // ── Affichage ───────────────────────────────────────────
                ColumnLayout {
                    id: displayPage
                    visible: page.catId === "display"
                    width: parent.width
                    spacing: Theme.unit * 2

                    FpSectionCard {
                        iconName: "display"
                        title: "Affichage"
                        subtitle: "Synchronisation de l'image et statistiques en jeu."
                        FpSettingRow {
                            title: "Synchronisation"
                            description: "VSync = fluide sans déchirure. Mailbox = latence minimale."
                            FpSegmented {
                                model: ["VSync (FIFO)", "Mailbox"]
                                currentIndex: Farplay.mailbox ? 1 : 0
                                onActivated: (i) => Farplay.mailbox = (i === 1)
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Overlay de stats"
                            description: "F3 en jeu."
                            FpSegmented {
                                model: ["Masqué", "Compact", "Détaillé"]
                                currentIndex: Farplay.overlayLevel
                                onActivated: (i) => Farplay.overlayLevel = i
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Journal de stats CSV"
                            description: "Enregistre les statistiques de chaque partie dans un fichier."
                            FpSwitch {
                                checked: Farplay.csvLogging
                                onToggled: (c) => Farplay.csvLogging = c
                            }
                        }
                    }
                    FpSectionCard {
                        iconName: "moon"
                        title: "Fin de session"
                        subtitle: "Ce que fait Farplay de la PS5 quand vous quittez la partie."
                        FpSettingRow {
                            title: "Action"
                            FpSegmented {
                                model: ["Ne rien faire", "Mettre en veille", "Demander"]
                                currentIndex: Chiaki.settings.disconnectAction
                                onActivated: (i) => Chiaki.settings.disconnectAction = i
                            }
                        }
                    }
                    FpSectionCard {
                        iconName: "fullscreen"
                        title: "Fenêtre"
                        subtitle: "Taille de la fenêtre pendant la partie."
                        FpSettingRow {
                            title: "Type de fenêtre"
                            FpSelect {
                                implicitWidth: 340
                                model: ["Résolution du flux", "Résolution personnalisée", "Ajustement manuel", "Plein écran", "Zoom", "Étirer"]
                                currentIndex: Chiaki.settings.windowType
                                onActivated: (i) => Chiaki.settings.windowType = i
                            }
                        }
                        FpSettingRow {
                            visible: Chiaki.settings.windowType === 1
                            divider: true
                            title: "Résolution personnalisée"
                            description: "Largeur × hauteur en pixels."
                            RowLayout {
                                spacing: Theme.unit * 1.5
                                FpTextField {
                                    id: cw
                                    focus: true
                                    compact: true
                                    Layout.preferredWidth: 110
                                    text: Chiaki.settings.customResolutionWidth
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    validator: IntValidator { bottom: 0; top: 9999 }
                                    onEditingFinished: Chiaki.settings.customResolutionWidth = cw.acceptable ? parseInt(cw.text) || 0 : 0
                                }
                                Text { text: "×"; font.family: Theme.ui; font.pixelSize: Theme.body; color: Theme.dim }
                                FpTextField {
                                    id: ch
                                    compact: true
                                    Layout.preferredWidth: 110
                                    text: Chiaki.settings.customResolutionHeight
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    validator: IntValidator { bottom: 0; top: 9999 }
                                    onEditingFinished: Chiaki.settings.customResolutionHeight = ch.acceptable ? parseInt(ch.text) || 0 : 0
                                }
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Plein écran au double-clic"
                            FpSwitch {
                                checked: Chiaki.settings.fullscreenDoubleClick
                                onToggled: (c) => Chiaki.settings.fullscreenDoubleClick = c
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Masquer le curseur"
                            description: "Pendant la partie."
                            FpSwitch {
                                checked: Chiaki.settings.hideCursor
                                onToggled: (c) => Chiaki.settings.hideCursor = c
                            }
                        }
                    }
                    FpSectionCard {
                        iconName: "gear"
                        title: "Décodage et confidentialité"
                        subtitle: "Décodeur vidéo matériel et mode streamer."
                        expanded: false
                        FpSettingRow {
                            visible: (Chiaki.settings.availableDecoders || []).length > 1
                            title: "Décodeur matériel"
                            description: "« Auto » convient dans presque tous les cas."
                            FpSelect {
                                implicitWidth: 260
                                model: Chiaki.settings.availableDecoders
                                currentIndex: Math.max(0, model.indexOf(Chiaki.settings.decoder))
                                onActivated: (i) => Chiaki.settings.decoder = i ? model[i] : ""
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Zero-copy"
                            description: "Évite une copie mémoire de chaque image décodée."
                            FpSwitch {
                                checked: Chiaki.settings.useZeroCopy
                                onToggled: (c) => Chiaki.settings.useZeroCopy = c
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Mode streamer"
                            description: "Masque les adresses et identifiants à l'écran."
                            FpSwitch {
                                checked: Chiaki.settings.streamerMode
                                onToggled: (c) => Chiaki.settings.streamerMode = c
                            }
                        }
                    }
                }

                // ── Profils ─────────────────────────────────────────────
                ColumnLayout {
                    id: profilesPage
                    visible: page.catId === "profiles"
                    width: parent.width
                    spacing: Theme.unit * 2

                    FpSectionCard {
                        iconName: "profiles"
                        title: "Mes profils"
                        subtitle: "Un profil mémorise vos réglages d'image et de fluidité."
                        Repeater {
                            model: FarplayProfiles.names
                            delegate: RowLayout {
                                id: profRow
                                required property string modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.leftMargin: Theme.unit * 2
                                Layout.rightMargin: Theme.unit * 2
                                Layout.topMargin: Theme.unit
                                spacing: Theme.unit * 2
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: profRow.modelData === FarplayProfiles.current ? Theme.mint : Theme.line
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: profRow.modelData
                                    elide: Text.ElideRight
                                    font.family: Theme.ui
                                    font.pixelSize: Theme.body
                                    font.weight: Font.Medium
                                    color: profRow.modelData === FarplayProfiles.current ? Theme.mint : Theme.ivory
                                }
                                FpButton {
                                    text: "Appliquer"
                                    onClicked: FarplayProfiles.apply(profRow.modelData)
                                }
                                FpButton {
                                    text: "Supprimer"
                                    danger: true
                                    onClicked: FarplayProfiles.remove(profRow.modelData)
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.margins: Theme.unit * 2
                            Layout.topMargin: Theme.unit * 3
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
                                leftPadding: 20
                                activeFocusOnTab: true
                                onAccepted: { FarplayProfiles.saveCurrentAs(text); text = "" }
                                onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(nameField)
                                background: Rectangle {
                                    radius: height / 2
                                    color: Theme.night
                                    border.width: nameField.activeFocus ? 2 : 1
                                    border.color: nameField.activeFocus ? Theme.coral : Theme.line
                                }
                            }
                            FpButton {
                                iconName: "plus"
                                text: "Enregistrer le profil actuel"
                                onClicked: { FarplayProfiles.saveCurrentAs(nameField.text); nameField.text = "" }
                            }
                        }
                    }
                    FpSectionCard {
                        iconName: "gear"
                        title: "Sauvegarde et journaux"
                        subtitle: "Exporter ou importer vos réglages, journaux de diagnostic."
                        expanded: false
                        FpSettingRow {
                            title: "Réglages"
                            description: "Enregistre ou restaure tous vos réglages dans un fichier."
                            RowLayout {
                                spacing: Theme.unit * 2
                                FpButton {
                                    id: expBtn
                                    focus: true
                                    text: "Exporter"
                                    onClicked: Chiaki.settings.exportSettings()
                                }
                                FpButton {
                                    id: impBtn
                                    text: "Importer"
                                    onClicked: Chiaki.settings.importSettings()
                                }
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Journaux détaillés"
                            description: "Ajoute des détails techniques aux journaux."
                            FpSwitch {
                                checked: Chiaki.settings.logVerbose
                                onToggled: (c) => Chiaki.settings.logVerbose = c
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Masquer les données personnelles"
                            description: "Retire adresses et identifiants des journaux."
                            FpSwitch {
                                checked: Chiaki.settings.logSanitize
                                onToggled: (c) => Chiaki.settings.logSanitize = c
                            }
                        }
                    }
                    FpSectionCard {
                        iconName: "gear"
                        title: "À propos"
                        subtitle: "Farplay " + Farplay.buildId + " · logiciel libre sous licence AGPL-3.0"
                        expanded: false
                        FpSettingRow {
                            title: "Licence et crédits"
                            description: "Farplay est distribué sous licence GNU AGPL-3.0, sans aucune garantie. Basé sur chiaki-ng et Chiaki (© leurs contributeurs), avec libplacebo, FFmpeg, Qt, AMD FidelityFX FSR 1 (MIT), polices Sora et JetBrains Mono (OFL). Code source : github.com/LuckyS7evin/farplay. Ce projet n'est ni approuvé ni certifié par Sony Interactive Entertainment."
                        }
                    }
                }
            }
        }
    }

    // ── GPU pipeline strip ─────────────────────────────────────────────────
    FpGlass {
        id: pipeline
        visible: page.catId === "image" || page.catId === "fluid"
        x: sidebar.width + contentScope.colX
        width: contentScope.colWidth
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.unit * 2
        height: 112
        radius: 22
        fillAlpha: 0.8

        component Stage: Column {
            id: stage
            property string label
            property var ms
            property color tone: Theme.coral
            width: parent ? parent.width : 100
            spacing: 6
            Item {
                width: parent.width
                height: lbl.implicitHeight
                Text { id: lbl; width: Math.max(0, parent.width - valTxt.implicitWidth - 6); elide: Text.ElideRight; text: stage.label; font.family: Theme.ui; font.pixelSize: Theme.small - 1; color: Theme.dim }
                Text {
                    id: valTxt
                    anchors.right: parent.right
                    text: page.fmt(stage.ms, 1, "ms")
                    font.family: Theme.mono
                    font.pixelSize: Theme.small - 1
                    color: Theme.ivory
                }
            }
            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(0.96, 0.945, 0.933, 0.10)
                Rectangle {
                    width: page.live && stage.ms !== undefined ? Math.max(4, Math.min(1, stage.ms / page.budgetMs) * parent.width) : 0
                    height: parent.height
                    radius: 2
                    color: stage.ms > page.budgetMs * 0.6 ? Theme.alert : stage.tone
                    Behavior on width { NumberAnimation { duration: Theme.duration } }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.unit * 3
            anchors.rightMargin: Theme.unit * 3
            spacing: Theme.unit * 4
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.unit * 1.5
                RowLayout {
                    spacing: Theme.unit * 1.5
                    Text {
                        text: "Pipeline GPU"
                        font.family: Theme.ui
                        font.pixelSize: Theme.body
                        font.weight: Font.Medium
                        color: Theme.ivory
                    }
                    Text {
                        text: page.live ? page.fmt(page.snap.gpuTotal, 1) + " ms sur " + page.budgetMs + " ms de budget" : "Aucune session en cours"
                        font.family: Theme.mono
                        font.pixelSize: Theme.small - 1
                        color: Theme.dim
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.unit * 3
                    Item { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 36
                        Stage { label: "Upscaling"; ms: page.snap.gpuUpscaleAvg } }
                    Item { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 36
                        Stage { label: "Flux optique"; ms: page.snap.fgFlowMs } }
                    Item { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 36
                        Stage { label: "FG"; ms: page.snap.fgSynthMs } }
                    Item { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 36
                        Stage { label: "Rendu"; ms: page.snap.gpuTotal } }
                }
            }
            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.unit * 1.5
                Repeater {
                    model: [
                        { v: page.live && page.snap.gpuTotal !== undefined ? Math.round(page.snap.gpuTotal / page.budgetMs * 100) + " %" : "—", l: "GPU" },
                        { v: page.live && page.snap.fgDelayMs !== undefined ? "+" + Number(page.snap.fgDelayMs).toFixed(0) : "—", l: "ms latence" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 116
                        height: 72
                        radius: 18
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.width: 1
                        border.color: Theme.line
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.v
                                font.family: Theme.mono
                                font.pixelSize: Theme.body + 4
                                color: Theme.ivory
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.l
                                font.family: Theme.ui
                                font.pixelSize: Theme.small - 1
                                color: Theme.dim
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Live status footer ─────────────────────────────────────────────────
    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 44
        color: Theme.side
        Rectangle { width: parent.width; height: 1; color: Theme.line }
        Row {
            x: Theme.unit * 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Rectangle {
                width: 9; height: 9; radius: 4.5
                anchors.verticalCenter: parent.verticalCenter
                color: page.live ? Theme.mint : Theme.dim
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.live
                    ? ["Streaming", (page.snap.resolution && page.snap.outResolution ? page.snap.resolution + " → " + page.snap.outResolution : ""),
                       (page.snap.fgState ? "FG " + page.snap.fgState : ""),
                       (page.snap.fpsIn ? Number(page.snap.fpsIn).toFixed(0) + " → " + Number((page.snap.fpsDistinct || 0) > 0 ? page.snap.fpsDistinct : page.snap.fpsOut || 0).toFixed(0) + " fps" : "")]
                        .filter(function(x) { return x !== "" }).join("  ·  ")
                    : "Aucune session en cours"
                font.family: Theme.mono
                font.pixelSize: Theme.small - 1
                color: Theme.ivory
            }
        }
        FpHints {
            anchors.right: parent.right
            anchors.rightMargin: Theme.unit * 4
            anchors.verticalCenter: parent.verticalCenter
            fontSize: Theme.small - 1
            model: [["✕", "Valider"], ["○", "Retour"]]
        }
    }

    // (le défilement vers l'élément ayant le focus est géré par FpNav / Theme.ensureVisible)
    // Reset scroll when switching section.
    onCatChanged: flick.contentY = 0
}
