import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// The validation report: one row per file, with what is wrong or worth knowing.
Sheet {
    id: sheet
    objectName: "validationSheet"
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Theme.s5 * 2, 720)
    height: Math.min(parent.height - Theme.s5 * 2, 560)
    modal: true
    title: backend.validationTitle
    standardButtons: Dialog.Close
    onClosed: backend.clearValidation()

    // One list, rows divided by hairlines, icons in the sidebar's quiet
    // treatment: the words say what is wrong, not the colour.
    contentItem: Rectangle {
        radius: Theme.rCard
        color: Theme.panelRaised
        border.width: Theme.hairline
        border.color: Theme.border
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            model: backend.validationReport
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                height: body.implicitHeight + Theme.s3 * 2

                RowLayout {
                    id: body
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.leftMargin: Theme.s3; anchors.rightMargin: Theme.s3; anchors.topMargin: Theme.s3
                    spacing: Theme.s2 + 2

                    Icon {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 3
                        name: modelData.status === "error" ? "circle-alert" : modelData.status === "warning" ? "info" : "circle-check"
                        size: 14
                        color: Theme.textMuted
                        opacity: 0.65
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s1
                        RowLayout {
                            spacing: Theme.s2
                            Label { text: modelData.name; color: Theme.textPrimary; font.weight: Theme.wHeading; elide: Text.ElideMiddle; Layout.fillWidth: true }
                            Label { text: (modelData.kind ?? "") + (modelData.glyphCount > 0 ? " · " + Theme.plural(modelData.glyphCount, qsTr("glyph"), qsTr("glyphs")) : ""); color: Theme.textMuted; font.pixelSize: Theme.fsLabel }
                        }
                        Repeater {
                            model: modelData.problems
                            Label { required property string modelData; text: modelData; color: Theme.textSecondary; font.pixelSize: Theme.fsLabel; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        }
                        Repeater {
                            model: modelData.warnings
                            Label { required property string modelData; text: modelData; color: Theme.textMuted; font.pixelSize: Theme.fsLabel; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        }
                        Label { visible: modelData.status === "ok"; text: qsTr("Passed every check"); color: Theme.textMuted; font.pixelSize: Theme.fsLabel }
                    }
                }
                Rectangle {
                    visible: row.index < list.count - 1
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Theme.hairline
                    color: Theme.border
                }
            }
        }
    }
}
