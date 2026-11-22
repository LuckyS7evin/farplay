// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
import QtQuick
import QtQuick.Layouts
import org.streetpea.chiaking

// Labelled single-line text field in the Farplay style (pill, coral focus ring).
FocusScope {
    id: root
    property string label
    property string hint                    // small helper text under the field
    property string placeholder
    property alias text: input.text
    property alias validator: input.validator
    property alias inputMethodHints: input.inputMethodHints
    property alias maximumLength: input.maximumLength
    property bool secret: false             // hidden in streamer mode
    property bool compact: false            // no label, fixed small width
    readonly property bool acceptable: input.acceptableInput
    readonly property bool hasText: input.text.trim().length > 0
    signal accepted()
    signal editingFinished()

    activeFocusOnTab: true
    Layout.fillWidth: !compact
    implicitWidth: compact ? 140 : 480
    implicitHeight: col.implicitHeight
    onActiveFocusChanged: if (activeFocus) Theme.ensureVisible(root)

    function selectAll() { input.selectAll() }
    function paste() { input.paste() }

    Column {
        id: col
        width: parent.width
        spacing: 8
        Text {
            visible: !root.compact && root.label !== ""
            text: root.label
            font.family: Theme.ui
            font.pixelSize: Theme.small
            font.weight: Font.Medium
            color: Theme.dim
        }
        Rectangle {
            id: box
            width: parent.width
            height: root.compact ? 44 : 52
            radius: height / 2
            color: Theme.night
            border.width: input.activeFocus ? 2 : 1
            border.color: input.activeFocus ? Theme.coral : Theme.line
            clip: true
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                clip: true
                selectByMouse: true
                color: Theme.ivory
                selectionColor: Theme.coral
                selectedTextColor: Theme.night
                font.family: Theme.mono
                font.pixelSize: Theme.body - 1
                echoMode: root.secret && Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
                onAccepted: root.accepted()
                onEditingFinished: root.editingFinished()
                Text {
                    visible: input.text.length === 0 && !input.preeditText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.placeholder
                    font.family: Theme.ui
                    font.pixelSize: Theme.body - 1
                    color: Qt.rgba(0.96, 0.945, 0.933, 0.32)
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.IBeamCursor
            }
        }
        Text {
            visible: root.hint !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.hint
            font.family: Theme.ui
            font.pixelSize: Theme.small - 1
            color: Theme.dim
        }
    }
}
