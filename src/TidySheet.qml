import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// The Tidy room: everything worth cleaning up, each with a fix. A fix that
// deletes files asks first (Main owns the confirmation sheet); deactivating is
// undone from the Deactivated source, so it does not.
Sheet {
    id: sheet
    objectName: "tidySheet"
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Theme.s5 * 2, 760)
    height: Math.min(parent.height - Theme.s5 * 2, 620)
    modal: true
    title: qsTr("Tidy up")
    onAboutToShow: backend.buildTidy()

    Connections {
        target: backend
        function onScanFinished() { if (sheet.visible) backend.buildTidy() }
    }

    signal confirmRequested(string title, string text, string button, var action)
    signal showCoverageRequested()

    function under(file) { return file.indexOf(backend.fontRoot + "/") === 0 }
    function isOtf(file) { return file.toLowerCase().endsWith(".otf") }
    function fileList(files) { return files.map(f => f.substring(f.lastIndexOf("/") + 1)).join(", ") }
    // Keep one format of OTF/TTF twins: your copies of the other are deleted,
    // package copies only deactivated (as backend.tidyKeepFormat does).
    function keepFormat(family, files, ext) {
        const going = files.filter(f => under(f) && (ext === "otf" ? !isOtf(f) : isOtf(f)))
        if (going.length === 0) { backend.tidyKeepFormat(family, ext); return }
        confirmRequested(qsTr("Keep the %1 copies of %2?").arg(ext.toUpperCase()).arg(family),
                         qsTr("%1 will be deleted from your font folder: %2. Package copies are only deactivated.")
                             .arg(Theme.plural(going.length, qsTr("file"), qsTr("files"))).arg(fileList(going)),
                         qsTr("Delete"), () => backend.tidyKeepFormat(family, ext))
    }
    function removeFiles(files) {
        const going = files.filter(under)
        confirmRequested(qsTr("Remove %1?").arg(Theme.plural(going.length, qsTr("file"), qsTr("files"))),
                         qsTr("These will be deleted from your font folder: %1. To hide them without deleting, deactivate them instead.").arg(fileList(going)),
                         qsTr("Remove"), () => backend.tidyRemoveFiles(files))
    }

    footer: SheetFooter {
        sheet: sheet
        Button { flat: true; text: qsTr("Check again"); onClicked: backend.buildTidy() }
    }

    // One list, rows divided by hairlines. Icons take the sidebar's quiet
    // treatment whatever the severity; the words say how much it matters.
    contentItem: Rectangle {
        radius: Theme.rCard
        color: Theme.panelRaised
        border.width: Theme.hairline
        border.color: Theme.border
        clip: true

        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.s5 * 2
            spacing: Theme.s2
            visible: backend.tidyReport.length === 0
            Icon { name: "circle-check"; size: 14; color: Theme.textMuted; opacity: 0.65; anchors.horizontalCenter: parent.horizontalCenter }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.textSecondary
                text: qsTr("Nothing to tidy. Every family is in order.")
            }
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            model: backend.tidyReport
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                height: body.implicitHeight + Theme.s3 * 2
                readonly property bool mine: (modelData.files ?? []).length > 0 && modelData.files.every(f => f.indexOf(backend.fontRoot + "/") === 0)
                readonly property bool fixable: modelData.kind === "invalid" || modelData.kind === "nolatin"

                RowLayout {
                    id: body
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.leftMargin: Theme.s3; anchors.rightMargin: Theme.s2; anchors.topMargin: Theme.s3
                    spacing: Theme.s2 + 2

                    Icon {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 3
                        name: modelData.severity === "error" ? "circle-alert" : modelData.severity === "warning" ? "copy" : "info"
                        size: 14
                        color: Theme.textMuted
                        opacity: 0.65
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Theme.s1
                        Label { Layout.fillWidth: true; text: modelData.title; color: Theme.textPrimary; font.weight: Theme.wHeading; wrapMode: Text.Wrap }
                        Label { Layout.fillWidth: true; text: modelData.detail; color: Theme.textSecondary; font.pixelSize: Theme.fsLabel; wrapMode: Text.Wrap }
                        Label {
                            Layout.fillWidth: true
                            visible: modelData.kind === "twins" || modelData.kind === "variable"
                            text: modelData.kind === "variable" ? qsTr("The static copies are deactivated, not deleted.")
                                : row.mine ? qsTr("Your copies are deleted, after asking; package copies are deactivated.")
                                : qsTr("Package copies are deactivated, never deleted.")
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            wrapMode: Text.Wrap
                        }
                    }
                    // Actions, as text, on the right.
                    RowLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: -Theme.s1
                        spacing: 0
                        // OTF/TTF twins: keep one format.
                        Button { flat: true; visible: modelData.kind === "twins"; enabled: !backend.busy; text: qsTr("Keep OTF"); onClicked: sheet.keepFormat(modelData.family, modelData.files ?? [], "otf") }
                        Button { flat: true; visible: modelData.kind === "twins"; enabled: !backend.busy; text: qsTr("Keep TTF"); onClicked: sheet.keepFormat(modelData.family, modelData.files ?? [], "ttf") }
                        // Static beside variable: the static copies are deactivated, not deleted.
                        Button { flat: true; visible: modelData.kind === "variable"; enabled: !backend.busy; text: qsTr("Keep variable"); onClicked: backend.tidyKeepVariable(modelData.family) }
                        // Broken files and stray non-Latin fonts.
                        Button { flat: true; visible: row.fixable; enabled: !backend.busy; text: qsTr("Deactivate"); onClicked: backend.tidyDeactivateFiles(modelData.files) }
                        Button { flat: true; visible: row.fixable && row.mine; enabled: !backend.busy; text: qsTr("Remove"); onClicked: sheet.removeFiles(modelData.files ?? []) }
                        // System Noto language-coverage families.
                        Button { flat: true; visible: modelData.kind === "coverage" && (modelData.files ?? []).length > 0; enabled: !backend.busy; text: qsTr("Deactivate all"); onClicked: backend.tidyDeactivateFiles(modelData.files) }
                        Button { flat: true; visible: modelData.kind === "coverage"; text: qsTr("Show in Library"); onClicked: { sheet.showCoverageRequested(); sheet.close() } }
                        Button { flat: true; visible: (modelData.family ?? "") !== ""; text: qsTr("Show"); onClicked: { backend.selectedName = modelData.family; sheet.close() } }
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
