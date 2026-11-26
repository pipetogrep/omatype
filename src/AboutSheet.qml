import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// About: what Omatype is, where it lives and how to support it. Links open in
// the browser.
Sheet {
    id: sheet
    objectName: "aboutSheet"
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Theme.s5 * 2, 480)
    modal: true
    title: qsTr("About Omatype")
    standardButtons: Dialog.Close

    readonly property var links: [
        { label: qsTr("Website"), text: "omatype.com", url: "https://omatype.com" },
        { label: qsTr("Source"), text: "github.com/pipetogrep/omatype", url: "https://github.com/pipetogrep/omatype" },
        { label: qsTr("Support"), text: "ko-fi.com/pipetogrep", url: "https://ko-fi.com/pipetogrep" }
    ]

    contentItem: ColumnLayout {
        spacing: Theme.s3

        Label {
            visible: Qt.application.version !== ""
            text: qsTr("Version %1").arg(Qt.application.version)
            color: Theme.textMuted
            font.pixelSize: Theme.fsLabel
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.textSecondary
            text: qsTr("Browse open-source type and install it in one click, then manage the fonts you already have. Made for Omarchy.")
        }

        // One list, hairline-divided, like the other sheets.
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.s1
            implicitHeight: linkColumn.implicitHeight + 2
            radius: Theme.rCard
            color: Theme.panelRaised
            border.width: Theme.hairline
            border.color: Theme.border
            clip: true

            Column {
                id: linkColumn
                x: 1; y: 1
                width: parent.width - 2
                Repeater {
                    model: sheet.links
                    ItemDelegate {
                        id: linkRow
                        required property var modelData
                        required property int index
                        width: linkColumn.width
                        height: 40
                        leftPadding: Theme.s3
                        rightPadding: Theme.s3
                        onClicked: Qt.openUrlExternally(modelData.url)
                        Accessible.name: modelData.label + " " + modelData.text
                        contentItem: RowLayout {
                            spacing: Theme.s2
                            Label { text: linkRow.modelData.label; color: Theme.textMuted; Layout.preferredWidth: Theme.wFactLabel }
                            Label {
                                Layout.fillWidth: true
                                text: linkRow.modelData.text
                                color: linkRow.hovered ? Theme.textPrimary : Theme.textSecondary
                                elide: Text.ElideMiddle
                            }
                            Icon { name: "external-link"; size: 14; color: Theme.textMuted; opacity: linkRow.hovered ? 0.85 : 0.65 }
                        }
                        background: Rectangle {
                            color: linkRow.down ? Theme.pressedOn(Theme.controlHover) : linkRow.hovered ? Theme.controlHover : "transparent"
                            Rectangle {
                                visible: linkRow.index < sheet.links.length - 1
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Theme.hairline
                                color: Theme.border
                            }
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: Theme.s1
            wrapMode: Text.Wrap
            color: Theme.textMuted
            font.pixelSize: Theme.fsLabel
            text: qsTr("MIT licence. Typefaces belong to their designers and are shown under their own licences.")
        }
    }
}
