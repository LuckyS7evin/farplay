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
    property int cat: 1
    readonly property bool live: !!Chiaki.session
    readonly property var snap: Farplay.snapshot || ({})
    readonly property var cats: [
        { text: "Accueil", icon: "home", action: true },
        { text: "Image", icon: "image", sub: "Qualité du flux et de l'agrandissement." },
        { text: "Fluidité", icon: "framegen", sub: "Plus d'images par seconde, sans changer le jeu." },
        { text: "Couleur & HDR", icon: "color", sub: "Rendu des couleurs et de la luminosité." },
        { text: "Affichage", icon: "display", sub: "Synchronisation, statistiques et fin de session." },
        { text: "Diagnostic", icon: "diagnostic", action: true },
        { text: "Profils", icon: "profiles", sub: "Enregistrez et rappelez vos combinaisons de réglages." }
    ]
    readonly property real budgetMs: 8

    function fmt(v, d, unit) {
        return (!live || v === undefined || v === null) ? "—" : Number(v).toFixed(d) + (unit ? " " + unit : "")
    }
    function activateCat(i) {
        if (i === 0) root.showMainView()
        else if (i === 5) root.showFarplayView("qrc:/farplay/ui/FarplayDiagnostic.qml")
        else focusContent()
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

    Keys.onEscapePressed: { if (sidebar.activeFocus) root.showMainView(); else focusSidebar() }
    Component.onCompleted: focusSidebar()

    Rectangle { anchors.fill: parent; color: Theme.night }

    // ── Sidebar ────────────────────────────────────────────────────────────
    FocusScope {
        id: sidebar
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

        Column {
            x: Theme.unit * 2
            y: 96
            width: parent.width - Theme.unit * 4
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

        // Current console
        Rectangle {
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
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: pipeline.visible ? pipeline.top : footer.top
        anchors.bottomMargin: pipeline.visible ? Theme.unit * 2 : 0

        Keys.onUpPressed: { var i = nextItemInFocusChain(false); if (i) i.forceActiveFocus() }
        Keys.onDownPressed: { var i = nextItemInFocusChain(true); if (i) i.forceActiveFocus() }
        Keys.onLeftPressed: page.focusSidebar()

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
                visible: page.cat !== 6
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
            ScrollBar.vertical: ScrollBar { policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

            Item {
                id: contentCol
                x: contentScope.colX
                y: 4
                width: contentScope.colWidth
                implicitHeight: Math.max(imagePage.visible ? imagePage.implicitHeight : 0,
                                         fluidPage.visible ? fluidPage.implicitHeight : 0,
                                         colorPage.visible ? colorPage.implicitHeight : 0,
                                         displayPage.visible ? displayPage.implicitHeight : 0,
                                         profilesPage.visible ? profilesPage.implicitHeight : 0)
                height: implicitHeight

                // ── Image ───────────────────────────────────────────────
                ColumnLayout {
                    id: imagePage
                    visible: page.cat === 1
                    width: parent.width
                    spacing: Theme.unit * 2

                    FpSectionCard {
                        iconName: "stats"
                        title: "Flux"
                        subtitle: "Cadence et qualité de l'image envoyée par la PS5."
                        FpSettingRow {
                            title: "Images par seconde"
                            description: "Régler sur la cadence du jeu évite les images dupliquées."
                            costs: ({ fluidite: "+", latence: "−" })
                            FpSegmented {
                                model: ["30", "60"]
                                currentIndex: Chiaki.settings.fpsLocalPS5 === 60 ? 1 : 0
                                onActivated: (i) => { Chiaki.settings.fpsLocalPS5 = (i + 1) * 30; Chiaki.settings.fpsRemotePS5 = (i + 1) * 30 }
                            }
                        }
                        FpSettingRow {
                            divider: true
                            title: "Bitrate"
                            description: "Plus haut = image plus nette, demande un réseau stable."
                            costs: ({ image: "+" })
                            FpSlider {
                                width: 320
                                from: 2; to: 100; stepSize: 1; unit: "Mbps"
                                value: Chiaki.settings.bitrateLocalPS5 / 1000
                                onMoved: (v) => Chiaki.settings.bitrateLocalPS5 = v * 1000
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
                    visible: page.cat === 2
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
                    visible: page.cat === 3
                    width: parent.width
                    spacing: Theme.unit * 2

                    FpSectionCard {
                        iconName: "display"
                        title: "HDR"
                        subtitle: "Demande un flux HDR à la PS5. Il faut que la console voie un écran HDR."
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
                    visible: page.cat === 4
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
                        iconName: "gear"
                        title: "Avancé"
                        subtitle: "Tous les réglages de chiaki-ng."
                        FpSettingRow {
                            title: "Réglages chiaki-ng complets"
                            description: "Manette, réseau, enregistrement et autres options."
                            FpButton {
                                text: "Ouvrir"
                                onClicked: root.showSettingsDialog()
                            }
                        }
                    }
                }

                // ── Profils ─────────────────────────────────────────────
                ColumnLayout {
                    id: profilesPage
                    visible: page.cat === 6
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
                }
            }
        }
    }

    // ── GPU pipeline strip ─────────────────────────────────────────────────
    FpGlass {
        id: pipeline
        visible: page.cat === 1 || page.cat === 2
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

    // Navigation au clavier/à la manette : garder l'élément sélectionné visible
    Connections {
        target: page.Window.window
        function onActiveFocusItemChanged() {
            const it = page.Window.window ? page.Window.window.activeFocusItem : null
            if (!it || flick.contentHeight <= flick.height || !contentCol.visible) return
            // Only react to items living inside the scrolled content.
            let p = it
            while (p && p !== contentCol) p = p.parent
            if (!p) return
            const pos = it.mapToItem(flick.contentItem, 0, 0)
            if (pos.y < flick.contentY + 16)
                flick.contentY = Math.max(0, pos.y - 16)
            else if (pos.y + it.height > flick.contentY + flick.height - 16)
                flick.contentY = Math.min(flick.contentHeight - flick.height, pos.y + it.height - flick.height + 16)
        }
    }
    // Reset scroll when switching section.
    onCatChanged: flick.contentY = 0
}
