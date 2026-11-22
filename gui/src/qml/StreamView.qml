import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Window

import org.streetpea.chiaking

import "controls" as C

Item {
    id: view

    readonly property var hostWindow: view.Window.window
    property bool sessionError: false
    property bool sessionLoading: true
    property list<Item> restoreFocusItems
    readonly property bool useSeparateMenuWindow: Chiaki.window.runtimeRendererBackend === 1
    readonly property int streamMenuHeight: 200
    readonly property bool streamStatsVisible: false // FARPLAY: l'overlay de stats chiaki est remplacé par StatsOverlay (Farplay)
    property int separateMenuX: 0
    property int separateMenuY: 0
    property int separateMenuWidth: 0
    property int separateStatsX: 0
    property int separateStatsY: 0
    property int separateStatsWidth: 0
    property int separateStatsHeight: 0
    property int separateDialogX: 0
    property int separateDialogY: 0
    property bool sessionStopDialogActive: false
    property bool sessionPinDialogActive: false
    property bool farplayQuickOpen: false // FARPLAY: n'est plus utilisé (reste pour l'ancien contenu du menu chiaki, jamais chargé)

    function grabInput(item) {
        Chiaki.window.grabInput();
        restoreFocusItems.push(hostWindow ? hostWindow.activeFocusItem : null);
        if (item)
            item.forceActiveFocus(Qt.TabFocusReason);
    }

    function releaseInput() {
        Chiaki.window.releaseInput();
        let item = restoreFocusItems.pop();
        if (item && item.visible)
            item.forceActiveFocus(Qt.TabFocusReason);
    }

    function updateSeparateMenuGeometry() {
        if (!hostWindow)
            return;
        const topLeft = view.mapToGlobal(0, 0);
        if (useSeparateMenuWindow) {
            separateMenuX = Math.round(topLeft.x);
            separateMenuY = Math.round(topLeft.y + view.height - streamMenuHeight);
            separateMenuWidth = Math.round(view.width);
            separateStatsX = Math.round(topLeft.x);
            separateStatsY = Math.round(topLeft.y);
            separateStatsWidth = Math.round(view.width);
            separateStatsHeight = Math.round(view.height);
        }
    }

    function updateSeparateDialogGeometry(width, height) {
        if (!useSeparateMenuWindow || !hostWindow)
            return;
        separateDialogX = Math.round(hostWindow.x + (hostWindow.width - width) / 2);
        separateDialogY = Math.round(hostWindow.y + (hostWindow.height - height) / 2);
    }

    function updateOverlayInteractionActive() {
        Chiaki.window.setOverlayInteractionActive(
            menuController.open ||
            menuController.closing ||
            sessionStopDialogActive ||
            separateSessionStopWindow.visible ||
            sessionPinDialogActive ||
            separateSessionPinWindow.visible
        );
    }

    StackView.onActivating: {
        Chiaki.window.keepVideo = true;
        sessionError = false;
        errorTitleLabel.text = "";
        errorTextLabel.text = "";
        sessionLoading = !(Chiaki.window.loadingTransitionComplete || (Chiaki.settings.audioVideoDisabled & 0x02));
    }
    StackView.onDeactivated: Chiaki.window.keepVideo = false

    Component.onCompleted: {
        updateSeparateMenuGeometry();
        updateOverlayInteractionActive();
        Chiaki.window.setStatsOverlayActive(streamStatsVisible);
    }
    onStreamStatsVisibleChanged: {
        if (Chiaki.window)
            Chiaki.window.setStatsOverlayActive(streamStatsVisible);
    }
    onWidthChanged: updateSeparateMenuGeometry()
    onHeightChanged: updateSeparateMenuGeometry()
    onUseSeparateMenuWindowChanged: updateSeparateMenuGeometry()

    Connections {
        target: view.hostWindow
        function onXChanged() { view.updateSeparateMenuGeometry() }
        function onYChanged() { view.updateSeparateMenuGeometry() }
        function onWidthChanged() { view.updateSeparateMenuGeometry() }
        function onHeightChanged() { view.updateSeparateMenuGeometry() }
        function onVisibilityChanged() { view.updateSeparateMenuGeometry() }
    }

    QtObject {
        id: menuController
        property bool closing: false
        property bool open: false

        property real lastToggleTime: 0
        function toggle() {
            var now = Date.now();
            if (now - lastToggleTime < 200)
                return;
            lastToggleTime = now;
            if (open)
                close();
            else {
                // FARPLAY: le panneau Farplay remplace le menu du bas ; l'interface capte l'entrée
                view.updateSeparateMenuGeometry();
                view.grabInput(null);
                open = true;
            }
            view.updateOverlayInteractionActive();
        }

        function close() {
            if (!open)
                return;
            closing = false; // FARPLAY: pas d'animation de fermeture du menu chiaki
            open = false;
            view.releaseInput();
            view.updateOverlayInteractionActive();
        }
    }

    Rectangle {
        id: loadingView
        anchors.fill: parent
        color: "#0A0A0C" // FARPLAY
        opacity: sessionError || sessionLoading || (Chiaki.settings.audioVideoDisabled & 0x02) ? 1.0 : 0.0
        visible: opacity

        Behavior on opacity { NumberAnimation { duration: 250 } }

        // FARPLAY: écran de chargement / erreur Farplay (l'ancien contenu ci-dessous reste caché,
        // il porte seulement le texte d'erreur)
        Loader {
            id: farplayLoadingLoader
            anchors.fill: parent
            source: "qrc:/farplay/ui/FarplayLoading.qml"
            onLoaded: item.focusAction()
        }
        Binding { target: farplayLoadingLoader.item; property: "loading"; value: sessionLoading; when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "errorActive"; value: sessionError; when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "errorTitle"; value: errorTitleLabel.text; when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "errorText"; value: errorTextLabel.text; when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "videoDisabled"; value: !!(Chiaki.settings.audioVideoDisabled & 0x02); when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "audioDisabled"; value: !!(Chiaki.settings.audioVideoDisabled & 0x01); when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "menuShortcut"; value: Chiaki.controllers.length ? Chiaki.settings.stringForStreamMenuShortcut() : "Ctrl+O"; when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "dpadShortcut"; value: Chiaki.settings.stringForDpadShortcut(); when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "dpadTouch"; value: Chiaki.settings.dpadTouchEnabled; when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "host"; value: (Chiaki.session && !Chiaki.settings.streamerMode) ? Chiaki.session.host : ""; when: farplayLoadingLoader.status === Loader.Ready }
        Binding { target: farplayLoadingLoader.item; property: "connected"; value: !!Chiaki.session && Chiaki.session.connected; when: farplayLoadingLoader.status === Loader.Ready }
        Connections {
            target: farplayLoadingLoader.item
            function onBackRequested() { root.showMainView() }
        }
        Connections {
            target: view
            function onSessionErrorChanged() {
                if (view.sessionError && farplayLoadingLoader.item) {
                    view.grabInput(null);
                    farplayLoadingLoader.item.focusAction();
                }
            }
        }

        Item {
            visible: false // FARPLAY
            anchors {
                top: parent.verticalCenter
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            BusyIndicator {
                id: spinner
                anchors.centerIn: parent
                width: 70
                height: width
                visible: sessionLoading
                running: sessionLoading
            }

            Label {
                anchors {
                    top: spinner.bottom
                    horizontalCenter: spinner.horizontalCenter
                    topMargin: 30
                }
                text: {
                    if(Chiaki.settings.dpadTouchEnabled)
                    {
                        if(Chiaki.settings.audioVideoDisabled == 0x01)
                            qsTr("Audio Disabled in settings\n") + qsTr("Press %1 to open stream menu").arg(Chiaki.controllers.length ? Chiaki.settings.stringForStreamMenuShortcut() : "Ctrl+O") + "\n" + qsTr("Press %1 to toggle between regular dpad and dpad touch").arg(Chiaki.settings.stringForDpadShortcut())
                        else
                            qsTr("Press %1 to open stream menu").arg(Chiaki.controllers.length ? Chiaki.settings.stringForStreamMenuShortcut() : "Ctrl+O") + "\n" + qsTr("Press %1 to toggle between regular dpad and dpad touch").arg(Chiaki.settings.stringForDpadShortcut())
                    }
                    else
                    {
                        if(Chiaki.settings.audioVideoDisabled == 0x01)
                            qsTr("Audio Disabled in settings\n") + qsTr("Press %1 to open stream menu").arg(Chiaki.controllers.length ? Chiaki.settings.stringForStreamMenuShortcut() : "Ctrl+O")
                        else
                            qsTr("Press %1 to open stream menu").arg(Chiaki.controllers.length ? Chiaki.settings.stringForStreamMenuShortcut() : "Ctrl+O")
                    }
                }
                visible: sessionLoading
            }

            Label {
                id: audioVideoDisabledTitleLabel
                anchors {
                    bottom: spinner.top
                    horizontalCenter: spinner.horizontalCenter
                }
                text: (Chiaki.settings.audioVideoDisabled & 0x01) ? qsTr("Audio and Video Disabled") : qsTr("Video Disabled")
                font.pixelSize: 24
                visible: !sessionLoading && !sessionError && (Chiaki.settings.audioVideoDisabled & 0x02)
            }

            Label {
                id: audioVideoDisabledTextLabel
                anchors {
                    top: audioVideoDisabledTitleLabel.bottom
                    horizontalCenter: audioVideoDisabledTitleLabel.horizontalCenter
                    topMargin: 10
                }
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 20
                text: (Chiaki.settings.audioVideoDisabled & 0x01) ? qsTr("You have disabled audio and video in your settings.\nTo re-enable change Audio/Video to Audio and Video Enabled in the General tab of the settings.") : qsTr("You have disabled video in your settings.\nTo re-enable change Audio/Video to Audio and Video Enabled in the General tab of the settings.")
                visible: !sessionLoading && !sessionError && (Chiaki.settings.audioVideoDisabled & 0x02)
            }

            Label {
                id: errorTitleLabel
                anchors {
                    bottom: spinner.top
                    horizontalCenter: spinner.horizontalCenter
                }
                font.pixelSize: 24
                visible: text
                onVisibleChanged: if (visible) view.grabInput(errorTitleLabel)
                Keys.onReturnPressed: root.showMainView()
                Keys.onEscapePressed: root.showMainView()
            }

            Label {
                id: errorTextLabel
                anchors {
                    top: errorTitleLabel.bottom
                    horizontalCenter: errorTitleLabel.horizontalCenter
                    topMargin: 10
                }
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 20
                visible: text
            }
        }
    }

    ColumnLayout {
        id: cantDisplayMessage
        anchors.centerIn: parent
        opacity: Chiaki.window.hasVideo && Chiaki.session && Chiaki.session.cantDisplay ? 1.0 : 0.0
        visible: opacity
        spacing: 30

        Behavior on opacity { NumberAnimation { duration: 250 } }

        onVisibleChanged: {
            if (visible) {
                menuController.close();
                view.grabInput(null);
                if (cantDisplayCard.item)
                    cantDisplayCard.item.focusFirst();
            } else {
                view.releaseInput();
            }
        }

        // FARPLAY: carte Farplay à la place des widgets Material
        Loader {
            id: cantDisplayCard
            Layout.alignment: Qt.AlignCenter
            source: "qrc:/farplay/ui/FarplayNotice.qml"
            onLoaded: {
                item.title = "Contenu non affichable";
                item.message = "L'écran contient un contenu que Remote Play ne peut pas afficher.";
                item.actionText = "Retour à l'accueil PS5";
            }
            Connections {
                target: cantDisplayCard.item
                function onAccepted() { Chiaki.sessionGoHome() }
            }
        }
    }

    // FARPLAY: pastille réseau Farplay
    Loader {
        anchors {
            right: parent.right
            top: parent.top
            margins: 32
        }
        z: 90
        source: "qrc:/farplay/ui/FarplayNetBadge.qml"
        opacity: networkIndicatorTimer.running ? 0.9 : 0.0
        visible: opacity

        Behavior on opacity { NumberAnimation { duration: 400 } }
    }
    Timer {
        id: networkIndicatorTimer
        running: Chiaki.session?.averagePacketLoss > (Chiaki.settings.wifiDroppedNotif * 0.01)
        interval: 400
    }
    Component {
        id: streamStatsContent
        Item {
            id: streamStatsContentRoot
            anchors.fill: parent
            ColumnLayout {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 5
                }

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: "Mbps"
                    font.pixelSize: 18
                    visible: Chiaki.session ? true : false

                    Label {
                        anchors {
                            right: parent.left
                            baseline: parent.baseline
                            rightMargin: 5
                        }
                        text: parent.visible ? Chiaki.session.measuredBitrate.toFixed(1) : ""
                        color: Material.accent
                        font.bold: true
                        font.pixelSize: 28
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("queue depth avg")
                    font.pixelSize: 15
                    opacity: Chiaki.session ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Label {
                        anchors {
                            right: parent.left
                            baseline: parent.baseline
                            rightMargin: 5
                        }
                        text: parent.visible ? Chiaki.window.queueDepthAverage.toFixed(1) : ""
                        font.bold: true
                        color: "#90caf9"
                        font.pixelSize: 18
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("pending frame age")
                    font.pixelSize: 15
                    opacity: Chiaki.session ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Label {
                        anchors {
                            right: parent.left
                            baseline: parent.baseline
                            rightMargin: 5
                        }
                        text: parent.visible ? qsTr("%1 ms").arg((Chiaki.window.pendingFrameAge * 1000.0).toFixed(0)) : ""
                        font.bold: true
                        color: "#90caf9"
                        font.pixelSize: 18
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignRight
                    id: statsPacketLossLabel
                    text: qsTr("packet loss")
                    font.pixelSize: 15
                    opacity: Chiaki.session ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Label {
                        anchors {
                            right: parent.left
                            baseline: parent.baseline
                            rightMargin: 5
                        }
                        text: parent.visible ? "%1<font size=\"1\">%</font>".arg((((Chiaki.session && isFinite(Chiaki.session.averagePacketLoss)) ? Chiaki.session.averagePacketLoss : 0) * 100).toFixed(1)) : ""
                        font.bold: true
                        color: "#ef9a9a"
                        font.pixelSize: 18
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("dropped frames")
                    font.pixelSize: 15
                    opacity: Chiaki.session ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Label {
                        id: statsDroppedFramesLabel
                        anchors {
                            right: parent.left
                            baseline: parent.baseline
                            rightMargin: 5
                        }
                        text: parent.visible ? Chiaki.window.droppedFrames : ""
                        color: "#ef9a9a"
                        font.bold: true
                        font.pixelSize: 18
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("lost frames")
                    font.pixelSize: 15
                    opacity: Chiaki.session ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Label {
                        anchors {
                            right: parent.left
                            baseline: parent.baseline
                            rightMargin: 5
                        }
                        text: parent.visible ? ((Chiaki.session && isFinite(Chiaki.session.framesLost)) ? Chiaki.session.framesLost : 0) : ""
                        color: "#ef9a9a"
                        font.bold: true
                        font.pixelSize: 18
                    }
                }
            }
        }
    }

    Component {
        id: menuContentComponent

        Item {
            property Item initialFocusItem: closeButton
            anchors.fill: parent

            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    let ctx = getContext("2d");
                    let gradient = ctx.createLinearGradient(0, 0, 0, height);
                    gradient.addColorStop(0.0, Qt.rgba(0.0, 0.0, 0.0, 0.0));
                    gradient.addColorStop(0.7, Qt.rgba(0.5, 0.5, 0.5, 0.7));
                    gradient.addColorStop(1.0, Qt.rgba(0.5, 0.5, 0.5, 0.9));
                    ctx.fillStyle = gradient;
                    ctx.fillRect(0, 0, width, height);
                }
            }

            RowLayout {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    leftMargin: 30
                    bottomMargin: 40
                }
                spacing: 0

                ToolButton {
                    id: closeButton
                    Layout.rightMargin: 20
                    text: "×"
                    padding: 10
                    font.pixelSize: 50
                    down: activeFocus
                    onClicked: {
                        if (Chiaki.session)
                            Chiaki.window.close();
                        else
                            root.showMainView();
                    }
                    KeyNavigation.right: volumeSlider
                    Keys.onReturnPressed: clicked()
                    Keys.onEscapePressed: menuController.close()
                }

            ToolSeparator {
                Layout.leftMargin: -10
                Layout.rightMargin: 10
            }

            Slider {
                id: volumeSlider
                Layout.rightMargin: 20
                orientation: Qt.Vertical
                from: 0
                to: 128
                Layout.preferredHeight: 100
                padding: 10
                stepSize: 1
                value: Chiaki.settings.audioVolume
                onMoved: Chiaki.settings.audioVolume = value
                KeyNavigation.left: closeButton
                KeyNavigation.right: muteButton
                Keys.onEscapePressed: menuController.close()
                Label {
                    anchors {
                        top: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                        leftMargin: 10
                    }
                    text: {
                        ((parent.value / 128.0) * 100).toFixed(0) + qsTr("% Volume")
                    }
                }
            }

            ToolSeparator {
                Layout.leftMargin: -10
                Layout.rightMargin: -10
            }

            ToolButton {
                id: muteButton
                Layout.rightMargin: 20
                text: qsTr("Mic")
                padding: 10
                checkable: true
                enabled: Chiaki.session && Chiaki.session.connected
                checked: Chiaki.session && !Chiaki.session.muted
                onToggled: Chiaki.session.muted = !Chiaki.session.muted
                KeyNavigation.left: volumeSlider
                KeyNavigation.right: farplayStatsButton // FARPLAY:
                Keys.onReturnPressed: toggled()
                Keys.onEscapePressed: menuController.close()
            }

            // FARPLAY: niveau de l'overlay Farplay (masqué / compact / détaillé)
            ToolButton {
                id: farplayStatsButton
                text: [qsTr("Stats : non"), qsTr("Stats : compact"), qsTr("Stats : détail")][Farplay.overlayLevel]
                padding: 10
                checkable: true
                checked: Farplay.overlayLevel > 0
                onClicked: Farplay.cycleOverlayLevel()
                KeyNavigation.left: muteButton
                KeyNavigation.right: farplayQuickButton
                Keys.onReturnPressed: clicked()
                Keys.onEscapePressed: menuController.close()
            }

            // FARPLAY: réglages rapides en jeu
            ToolButton {
                id: farplayQuickButton
                text: qsTr("Réglages")
                padding: 10
                visible: !view.useSeparateMenuWindow
                onClicked: view.farplayQuickOpen = true
                KeyNavigation.left: farplayStatsButton
                KeyNavigation.right: zoomButton
                Keys.onReturnPressed: clicked()
                Keys.onEscapePressed: menuController.close()
            }

            ToolButton {
                id: zoomButton
                text: qsTr("Zoom")
                padding: 10
                checkable: true
                checked: Chiaki.window.videoMode == ChiakiWindow.VideoMode.Zoom
                onToggled: Chiaki.window.videoMode = Chiaki.window.videoMode == ChiakiWindow.VideoMode.Zoom ? ChiakiWindow.VideoMode.Normal : ChiakiWindow.VideoMode.Zoom
                KeyNavigation.left: farplayQuickButton // FARPLAY:
                KeyNavigation.right: {
                    if(Chiaki.window.videoMode == ChiakiWindow.VideoMode.Zoom)
                        zoomFactor
                    else
                        stretchButton
                }
                Keys.onReturnPressed: toggled()
                Keys.onEscapePressed: menuController.close()
            }

            Slider {
                id: zoomFactor
                orientation: Qt.Vertical
                from: -1
                to: 4
                Layout.preferredHeight: 100
                stepSize: 0.01
                visible: Chiaki.window.videoMode == ChiakiWindow.VideoMode.Zoom
                value: Chiaki.window.ZoomFactor
                onMoved: {
                    Chiaki.window.ZoomFactor = value
                    Chiaki.settings.sZoomFactor = value
                }
                Label {
                    anchors {
                        top: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                        leftMargin: 10
                    }
                    text: {
                        if(parent.value === -1)
                            qsTr("No Black Bars")
                        else if(parent.value >= 0)
                            qsTr((parent.value + 1).toFixed(2)) + qsTr(" x")
                        else
                            qsTr(parent.value.toFixed(2)) + qsTr(" x")
                    }

                }
            }

            ToolSeparator {
                Layout.leftMargin: -10
                Layout.rightMargin: -10
            }

            ToolButton {
                id: stretchButton
                Layout.rightMargin: 50
                text: qsTr("Stretch")
                padding: 10
                checkable: true
                checked: Chiaki.window.videoMode == ChiakiWindow.VideoMode.Stretch
                onToggled: Chiaki.window.videoMode = Chiaki.window.videoMode == ChiakiWindow.VideoMode.Stretch ? ChiakiWindow.VideoMode.Normal : ChiakiWindow.VideoMode.Stretch
                KeyNavigation.left: {
                    if(Chiaki.window.videoMode == ChiakiWindow.VideoMode.Zoom)
                        zoomFactor
                    else
                        zoomButton
                }
                KeyNavigation.right: defaultButton
                Keys.onReturnPressed: toggled()
                Keys.onEscapePressed: menuController.close()
            }

            ToolButton {
                id: defaultButton
                text: qsTr("Default")
                padding: 10
                checkable: true
                checked: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Default
                onToggled: {
                    Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.Default
                    Chiaki.settings.videoPreset = ChiakiWindow.VideoPreset.Default
                }
                KeyNavigation.left: stretchButton
                KeyNavigation.right: highQualityButton
                Keys.onReturnPressed: toggled()
                Keys.onEscapePressed: menuController.close()
            }

            ToolSeparator {
                Layout.leftMargin: -10
                Layout.rightMargin: -10
            }

            ToolButton {
                id: highQualityButton
                text: qsTr("High Quality")
                padding: 10
                checkable: true
                checked: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.HighQuality
                onToggled: {
                    Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.HighQuality
                    Chiaki.settings.videoPreset = ChiakiWindow.VideoPreset.HighQuality
                }
                KeyNavigation.left: defaultButton
                KeyNavigation.right: highQualitySpatialButton
                Keys.onReturnPressed: toggled()
                Keys.onEscapePressed: menuController.close()
            }

            ToolButton {
                id: highQualitySpatialButton
                text: qsTr("HQ + Spatial")
                padding: 10
                checkable: true
                checked: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.HighQualitySpatial
                onToggled: {
                    Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.HighQualitySpatial
                    Chiaki.settings.videoPreset = ChiakiWindow.VideoPreset.HighQualitySpatial
                }
                KeyNavigation.left: highQualityButton
                KeyNavigation.right: highQualityAdvancedSpatialButton
                Keys.onReturnPressed: toggled()
                Keys.onEscapePressed: menuController.close()
            }

            ToolButton {
                id: highQualityAdvancedSpatialButton
                text: qsTr("HQ + Adv Spatial")
                padding: 10
                checkable: true
                checked: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.HighQualityAdvancedSpatial
                onToggled: {
                    Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.HighQualityAdvancedSpatial
                    Chiaki.settings.videoPreset = ChiakiWindow.VideoPreset.HighQualityAdvancedSpatial
                }
                KeyNavigation.left: highQualitySpatialButton
                KeyNavigation.right: customButton
                Keys.onReturnPressed: toggled()
                Keys.onEscapePressed: menuController.close()
            }

            ToolSeparator {
                Layout.leftMargin: -10
                Layout.rightMargin: -10
            }

            ToolButton {
                id: customButton
                text: qsTr("Custom")
                Layout.rightMargin: 40
                padding: 10
                checkable: true
                checked: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom
                onToggled: {
                    Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.Custom
                    Chiaki.settings.videoPreset = ChiakiWindow.VideoPreset.Custom
                }
                KeyNavigation.left: highQualityAdvancedSpatialButton
                KeyNavigation.right: displaySettingsButton
                Keys.onReturnPressed: toggled()
                Keys.onEscapePressed: menuController.close()
            }

            ToolButton {
                id: displaySettingsButton
                text: qsTr("Display")
                padding: 10
                checkable: false
                icon.source: "qrc:/icons/settings-20px.svg";
                onClicked: root.openDisplaySettings()
                KeyNavigation.left: customButton
                KeyNavigation.right: {
                    if(Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom)
                        placeboSettingsButton;
                    else
                        displaySettingsButton;
                }
                Keys.onReturnPressed: {
                    menuController.close();
                    clicked();
                }
                Keys.onEscapePressed: menuController.close()
            }

            ToolButton {
                id: placeboSettingsButton
                text: qsTr("Placebo")
                icon.source: "qrc:/icons/settings-20px.svg";
                padding: 10
                checkable: false
                onClicked: root.openPlaceboSettings()
                KeyNavigation.left: displaySettingsButton
                visible: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom
                Keys.onReturnPressed: {
                    menuController.close();
                    clicked();
                }
                Keys.onEscapePressed: menuController.close()
            }
            }

            Label {
                anchors {
                    right: consoleNameLabel.right
                    bottom: consoleNameLabel.top
                    bottomMargin: 5

                }
                text: "Mbps"
                font.pixelSize: 18
                visible: Chiaki.session

                Label {
                    anchors {
                        right: parent.left
                        baseline: parent.baseline
                        rightMargin: 5
                    }
                        text: visible && Chiaki.session ? Chiaki.session.measuredBitrate.toFixed(1) : ""
                    color: Material.accent
                    font.bold: true
                    font.pixelSize: 28
                }
            }

            Label {
                id: consoleNameLabel
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 30
                }
                text: {
                    if (!Chiaki.session)
                        return "";
                    if (Chiaki.session.connected)
                        return qsTr("Connected to <b>%1</b>").arg(Chiaki.settings.streamerMode ? "hidden" : Chiaki.session.host);
                    return qsTr("Connecting to <b>%1</b>").arg(Chiaki.settings.streamerMode ? "hidden" : Chiaki.session.host);
                }

                RowLayout {
                    anchors {
                        right: parent.right
                        top: parent.bottom
                        topMargin: 12
                    }

                    Label {
                        text: qsTr("packet loss")
                        font.pixelSize: 15
                        opacity: parent.visible && Chiaki.session ? 1.0 : 0.0
                        visible: opacity

                        Behavior on opacity { NumberAnimation { duration: 250 } }

                        Label {
                            anchors {
                                right: parent.left
                                baseline: parent.baseline
                                rightMargin: 5
                            }
                            text: visible ? "%1<font size=\"1\">%</font>".arg((((Chiaki.session && isFinite(Chiaki.session.averagePacketLoss)) ? Chiaki.session.averagePacketLoss : 0) * 100).toFixed(1)) : ""
                            color: "#ef9a9a" // Material.Red
                            font.bold: true
                            font.pixelSize: 18
                        }
                    }

                    Label {
                        Layout.leftMargin: droppedFramesLabel.width + 6
                        text: qsTr("dropped frames")
                        font.pixelSize: 15
                        opacity: parent.visible && Chiaki.window.droppedFrames ? 1.0 : 0.0
                        visible: opacity

                        Behavior on opacity { NumberAnimation { duration: 250 } }

                        Label {
                            id: droppedFramesLabel
                            anchors {
                                right: parent.left
                                baseline: parent.baseline
                                rightMargin: 5
                            }
                            text: visible ? Chiaki.window.droppedFrames : ""
                            color: "#ef9a9a" // Material.Red
                            font.bold: true
                            font.pixelSize: 18
                        }
                    }
                }
            }
        }
    }

    Item {
        id: menuView
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: streamMenuHeight
        y: menuController.open ? parent.height - height : parent.height
        visible: false // FARPLAY: le menu du bas de chiaki-ng n'est jamais affiché (panneau Farplay)
        enabled: false

        Behavior on y {
            NumberAnimation {
                id: inlineMenuAnimation
                duration: 250
                onRunningChanged: {
                    if (!running && !menuController.open) {
                        menuController.closing = false;
                        view.updateOverlayInteractionActive();
                    }
                }
            }
        }

        Loader {
            id: inlineMenuContent
            anchors.fill: parent
            active: false // FARPLAY
            sourceComponent: menuContentComponent
        }
    }

    StreamMenuWindow {
        id: separateMenuWindow
        transientParent: view.hostWindow
        x: separateMenuX
        y: menuController.open ? separateMenuY : separateMenuY + streamMenuHeight
        width: separateMenuWidth > 0 ? separateMenuWidth : view.width
        height: streamMenuHeight
        visible: false // FARPLAY: jamais affichée
        open: false
        closing: false
        onCloseRequested: menuController.close()
        onDisplaySettingsRequested: {
            menuController.close();
            root.openDisplaySettings();
        }
        onPlaceboSettingsRequested: {
            menuController.close();
            root.openPlaceboSettings();
        }
        onMainViewRequested: root.showMainView()
        onCloseAnimationFinished: {
            if (view.hostWindow)
                view.hostWindow.requestActivate();
            menuController.closing = false;
            view.updateOverlayInteractionActive();
        }
    }

    // FARPLAY: dialogues de fin de partie et de PIN au style Farplay (mêmes appels Chiaki.*)
    Popup {
        id: sessionStopDialog
        property int closeAction: 0
        parent: Overlay.overlay
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        modal: true
        padding: 0
        background: Item {}
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.62) }
        onAboutToShow: {
            closeAction = 0;
            sessionStopDialogActive = true;
            view.updateOverlayInteractionActive();
        }
        onOpened: {
            view.grabInput(null);
            if (stopDialogLoader.item)
                stopDialogLoader.item.focusFirst();
        }
        onClosed: {
            view.releaseInput();
            sessionStopDialogActive = false;
            view.updateOverlayInteractionActive();
            if (closeAction)
                Chiaki.stopSession(closeAction == 1);
        }

        contentItem: Loader {
            id: stopDialogLoader
            source: "qrc:/farplay/ui/FarplayStopDialog.qml"
            Connections {
                target: stopDialogLoader.item
                function onSleepRequested() { sessionStopDialog.closeAction = 1; sessionStopDialog.close(); }
                function onKeepOnRequested() { sessionStopDialog.closeAction = 2; sessionStopDialog.close(); }
                function onCancelRequested() { sessionStopDialog.close(); }
            }
        }
    }

    Window {
        id: separateSessionStopWindow
        property int closeAction: 0
        readonly property int dialogWidth: 640
        readonly property int dialogHeight: 224
        visible: false
        flags: Qt.Dialog | Qt.FramelessWindowHint
        color: "transparent"
        transientParent: view.hostWindow
        modality: Qt.ApplicationModal
        x: separateDialogX
        y: separateDialogY
        width: dialogWidth
        height: dialogHeight

        onVisibleChanged: {
            if (visible) {
                closeAction = 0;
                view.updateSeparateDialogGeometry(width, height);
                requestActivate();
                view.grabInput(null);
                if (separateStopLoader.item)
                    separateStopLoader.item.focusFirst();
            } else {
                view.releaseInput();
                if (closeAction)
                    Chiaki.stopSession(closeAction === 1);
            }
            view.updateOverlayInteractionActive();
        }

        Loader {
            id: separateStopLoader
            anchors.fill: parent
            source: "qrc:/farplay/ui/FarplayStopDialog.qml"
            Connections {
                target: separateStopLoader.item
                function onSleepRequested() { separateSessionStopWindow.closeAction = 1; separateSessionStopWindow.visible = false; }
                function onKeepOnRequested() { separateSessionStopWindow.closeAction = 2; separateSessionStopWindow.visible = false; }
                function onCancelRequested() { separateSessionStopWindow.visible = false; }
            }
        }
    }

    Popup {
        id: sessionPinDialog
        parent: Overlay.overlay
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        modal: true
        padding: 0
        background: Item {}
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.62) }
        closePolicy: Popup.NoAutoClose
        onAboutToShow: {
            if (pinDialogLoader.item)
                pinDialogLoader.item.reset();
            sessionPinDialogActive = true;
            view.updateOverlayInteractionActive();
        }
        onOpened: {
            view.grabInput(null);
            if (pinDialogLoader.item)
                pinDialogLoader.item.focusFirst();
        }
        onClosed: {
            view.releaseInput();
            sessionPinDialogActive = false;
            view.updateOverlayInteractionActive();
        }

        contentItem: Loader {
            id: pinDialogLoader
            source: "qrc:/farplay/ui/FarplayPinDialog.qml"
            Connections {
                target: pinDialogLoader.item
                function onPinEntered(pin) { Chiaki.enterPin(pin); sessionPinDialog.close(); }
                function onCancelled() { sessionPinDialog.close(); Chiaki.stopSession(false); }
            }
        }
    }

    Window {
        id: separateSessionPinWindow
        readonly property int dialogWidth: 560
        readonly property int dialogHeight: 316
        visible: false
        flags: Qt.Dialog | Qt.FramelessWindowHint
        color: "transparent"
        transientParent: view.hostWindow
        modality: Qt.ApplicationModal
        x: separateDialogX
        y: separateDialogY
        width: dialogWidth
        height: dialogHeight

        onVisibleChanged: {
            if (visible) {
                if (separatePinLoader.item)
                    separatePinLoader.item.reset();
                view.updateSeparateDialogGeometry(width, height);
                requestActivate();
                view.grabInput(null);
                if (separatePinLoader.item)
                    separatePinLoader.item.focusFirst();
            } else {
                view.releaseInput();
            }
            view.updateOverlayInteractionActive();
        }

        Loader {
            id: separatePinLoader
            anchors.fill: parent
            source: "qrc:/farplay/ui/FarplayPinDialog.qml"
            Connections {
                target: separatePinLoader.item
                function onPinEntered(pin) { separateSessionPinWindow.visible = false; Chiaki.enterPin(pin); }
                function onCancelled() { separateSessionPinWindow.visible = false; Chiaki.stopSession(false); }
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 2000
        onTriggered: root.showMainView()
    }

    Connections {
        target: Chiaki

        function onSessionChanged() {
            if (!Chiaki.session) {
                if (errorTitleLabel.text)
                    closeTimer.start();
                else
                    root.showMainView();
            } else {
                sessionError = false;
                errorTitleLabel.text = "";
                errorTextLabel.text = "";
                sessionLoading = !(Chiaki.window.loadingTransitionComplete || (Chiaki.settings.audioVideoDisabled & 0x02));
            }
        }

        function onSessionError(title, text) {
            sessionError = true;
            sessionLoading = false;
            errorTitleLabel.text = title;
            errorTextLabel.text = text;
            closeTimer.start();
        }

        function onSessionPinDialogRequested() {
            if (sessionPinDialog.opened || separateSessionPinWindow.visible)
                return;
            menuController.close();
            if (useSeparateMenuWindow)
                separateSessionPinWindow.visible = true;
            else
                sessionPinDialog.open();
            Chiaki.window.requestOverlayUpdate();
        }

        function onSessionStopDialogRequested() {
            if (sessionStopDialog.opened || separateSessionStopWindow.visible)
                return;
            menuController.close();
            if (useSeparateMenuWindow)
                separateSessionStopWindow.visible = true;
            else
                sessionStopDialog.open();
            Chiaki.window.requestOverlayUpdate();
        }
    }

    Connections {
        target: Chiaki.window

        function onLoadingTransitionCompleteChanged() {
            if (Chiaki.window.loadingTransitionComplete) {
                sessionLoading = false;
                Chiaki.window.noteLoadingTransitionComplete();
                Chiaki.window.requestOverlayUpdate();
            } else if (Chiaki.session) {
                sessionLoading = !(Chiaki.settings.audioVideoDisabled & 0x02);
            }
        }

        function onMenuRequested() {
            if (sessionPinDialog.opened || sessionStopDialog.opened || separateSessionPinWindow.visible || separateSessionStopWindow.visible)
                return;
            menuController.toggle();
            Chiaki.window.requestOverlayUpdate();
        }
    }
    Connections {
        target: Chiaki

        function onSessionChanged() {
            if (!Chiaki.session)
                menuController.close();
        }
    }
    // FARPLAY: le panneau de réglages rapides + la barre du haut remplacent le menu du bas de
    // chiaki-ng. Ouverture = menuController.open (PS button, Ctrl+O, bouton de la barre) ; l'entrée
    // est alors captée par l'interface (Chiaki.window.grabInput) et n'est pas envoyée à la PS5.
    Loader {
        id: farplayQuickLoader
        anchors.fill: parent
        z: 200
        active: menuController.open && !view.useSeparateMenuWindow
        source: "qrc:/farplay/ui/FarplayStreamOverlay.qml"
        onLoaded: item.focusFirst()
        Connections {
            target: farplayQuickLoader.item
            function onCloseRequested() { menuController.close() }
            function onQuitRequested() { menuController.close(); Chiaki.window.close() }
            function onDisplaySettingsRequested() { menuController.close(); root.openDisplaySettings() }
        }
    }
    // Rendu vidéo en fenêtre native : le même panneau dans une fenêtre sans cadre
    Window {
        id: farplayQuickWindow
        visible: view.useSeparateMenuWindow && menuController.open
        flags: Qt.Tool | Qt.FramelessWindowHint
        color: "transparent"
        transientParent: view.hostWindow
        x: view.separateStatsX
        y: view.separateStatsY
        width: view.separateStatsWidth > 0 ? view.separateStatsWidth : view.width
        height: view.separateStatsHeight > 0 ? view.separateStatsHeight : view.height
        onVisibleChanged: {
            if (visible) {
                requestActivate();
                if (farplayQuickWindowLoader.item)
                    farplayQuickWindowLoader.item.focusFirst();
            } else if (view.hostWindow) {
                view.hostWindow.requestActivate();
            }
        }
        Loader {
            id: farplayQuickWindowLoader
            anchors.fill: parent
            active: farplayQuickWindow.visible
            source: "qrc:/farplay/ui/FarplayStreamOverlay.qml"
            onLoaded: item.focusFirst()
            Connections {
                target: farplayQuickWindowLoader.item
                function onCloseRequested() { menuController.close() }
                function onQuitRequested() { menuController.close(); Chiaki.window.close() }
                function onDisplaySettingsRequested() { menuController.close(); root.openDisplaySettings() }
            }
        }
    }

    // FARPLAY: barre du haut (apparaît quand la souris approche du haut de l'écran, ou menu ouvert)
    Loader {
        id: farplayBarLoader
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 96
        z: 250
        active: !!Chiaki.session && !sessionLoading && !sessionError
        source: "qrc:/farplay/ui/FarplayStreamBar.qml"
        Binding {
            target: farplayBarLoader.item
            property: "shown"
            value: Farplay.topBarActive || (menuController.open && !view.useSeparateMenuWindow)
            when: farplayBarLoader.status === Loader.Ready
        }
        Binding {
            target: farplayBarLoader.item
            property: "muted"
            value: !!Chiaki.session && Chiaki.session.muted
            when: farplayBarLoader.status === Loader.Ready
        }
        Connections {
            target: farplayBarLoader.item
            function onQuickSettingsRequested() { menuController.toggle() }
            function onMuteToggled() { if (Chiaki.session) Chiaki.session.muted = !Chiaki.session.muted }
            function onFullscreenToggled() {
                if (Chiaki.window.visibility === Window.FullScreen)
                    Chiaki.window.normalTime()
                else
                    Chiaki.window.fullscreenTime()
            }
            function onQuitRequested() { Chiaki.window.close() }
        }
    }

    // FARPLAY: overlay de stats (F3 ou bouton "Stats" du menu de flux)
    Loader {
        anchors { left: parent.left; top: parent.top; margins: 16 }
        z: 100
        active: Farplay.overlayLevel > 0 && !!Chiaki.session && !sessionLoading && !sessionError
        source: "qrc:/farplay/StatsOverlay.qml"
    }
    Connections {
        target: Chiaki.session

        function onConnectedChanged() {
            if (Chiaki.settings.audioVideoDisabled & 0x02)
                sessionLoading = false;
        }
    }
}
