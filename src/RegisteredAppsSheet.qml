import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// Manage registered design apps that should reload after font installs so new
// fonts appear immediately without manual restarts.
Sheet {
    id: sheet
    objectName: "registeredAppsSheet"
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Theme.s5 * 2, 740)
    height: Math.min(parent.height - Theme.s5 * 2, 640)
    modal: true
    title: qsTr("Applications")
    footer: SheetFooter {
        sheet: sheet
        Button { flat: true; text: qsTr("Refresh"); onClicked: sheet.refreshAll() }
    }

    property var discovered: []
    property string searchQuery: ""
    property bool showCustomForm: false
    property string noticeText: ""
    property bool noticeError: false

    function refreshAll() {
        backend.refreshRunningApps()
        discovered = backend.discoverApps()
    }

    function filteredDiscovered() {
        const q = searchQuery.trim().toLowerCase()
        const out = []
        for (let i = 0; i < discovered.length; ++i) {
            const d = discovered[i]
            if (d.registered) continue
            if (q === "") {
                out.push(d)
            } else {
                const hay = (d.name + " " + d.processName + " " + d.category).toLowerCase()
                if (hay.indexOf(q) >= 0) out.push(d)
            }
        }
        return out
    }

    onAboutToShow: {
        noticeText = ""
        noticeError = false
        showCustomForm = false
        refreshAll()
    }

    Connections {
        target: backend
        function onAppsChanged() {
            if (sheet.visible) discovered = backend.discoverApps()
        }
        function onAppReloaded(name, ok, message) {
            if (!sheet.visible) return
            sheet.noticeText = message
            sheet.noticeError = !ok
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.s3

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.textSecondary
            font.pixelSize: Theme.fsLabel
            text: qsTr("Register applications that cache system fonts at startup. After Omatype installs a font and updates fontconfig, running applications can be gracefully restarted (or triggered via a custom command). Apps with unsaved work dialogs are never force-killed.")
        }

        // Optional feedback strip when testing a reload
        Rectangle {
            visible: sheet.noticeText !== ""
            Layout.fillWidth: true
            implicitHeight: noticeRow.implicitHeight + Theme.s2 * 2
            radius: Theme.rControl
            color: Theme.panelRaised
            border.width: Theme.hairline
            border.color: Theme.border
            RowLayout {
                id: noticeRow
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.s3; anchors.rightMargin: Theme.s3
                spacing: Theme.s2
                Icon {
                    name: sheet.noticeError ? "circle-alert" : "circle-check"
                    size: 14
                    color: Theme.textMuted
                    opacity: 0.65
                }
                Label {
                    Layout.fillWidth: true
                    text: sheet.noticeText
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fsLabel
                    wrapMode: Text.Wrap
                }
            }
        }

        // ── Registered apps list ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Label {
                text: qsTr("Registered")
                color: Theme.textPrimary
                font.weight: Theme.wHeading
            }
            Item { Layout.fillWidth: true }
            Button {
                flat: true
                text: sheet.showCustomForm ? qsTr("Cancel") : qsTr("Add custom")
                onClicked: sheet.showCustomForm = !sheet.showCustomForm
            }
        }

        // Inline custom app form
        Rectangle {
            visible: sheet.showCustomForm
            Layout.fillWidth: true
            implicitHeight: customForm.implicitHeight + Theme.s3 * 2
            radius: Theme.rCard
            color: Theme.panelRaised
            border.width: Theme.hairline
            border.color: Theme.border
            ColumnLayout {
                id: customForm
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: Theme.s3
                spacing: Theme.s2
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Theme.s2
                    rowSpacing: Theme.s2
                    TextField {
                        id: customName
                        Layout.fillWidth: true
                        placeholderText: qsTr("App name (e.g. Inkscape)")
                    }
                    TextField {
                        id: customProc
                        Layout.fillWidth: true
                        placeholderText: qsTr("Process name (e.g. inkscape)")
                    }
                    TextField {
                        id: customLaunch
                        Layout.fillWidth: true
                        placeholderText: qsTr("Launch command (optional, e.g. inkscape)")
                    }
                    TextField {
                        id: customReload
                        Layout.fillWidth: true
                        placeholderText: qsTr("Custom reload cmd (optional, e.g. pkill -USR1 kitty)")
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s2
                    CheckBox {
                        id: customAuto
                        text: qsTr("Auto-reload on font install")
                        checked: true
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        highlighted: true
                        text: qsTr("Register")
                        enabled: customName.text.trim() !== "" && (customProc.text.trim() !== "" || customLaunch.text.trim() !== "" || customReload.text.trim() !== "")
                        onClicked: {
                            backend.registerApp(customName.text, customProc.text, customLaunch.text, customReload.text, customAuto.checked)
                            customName.text = ""
                            customProc.text = ""
                            customLaunch.text = ""
                            customReload.text = ""
                            customAuto.checked = true
                            sheet.showCustomForm = false
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: backend.registeredApps.length === 0 ? 54 : Math.min(200, regList.contentHeight + 2)
            radius: Theme.rCard
            color: Theme.panelRaised
            border.width: Theme.hairline
            border.color: Theme.border
            clip: true

            Label {
                anchors.centerIn: parent
                visible: backend.registeredApps.length === 0
                color: Theme.textMuted
                font.pixelSize: Theme.fsLabel
                text: qsTr("No apps registered yet. Pick one from the list below or add a custom command.")
            }

            ListView {
                id: regList
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                model: backend.registeredApps
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Item {
                    id: rrow
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 46

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s3
                        anchors.rightMargin: Theme.s3
                        spacing: Theme.s2

                        Rectangle {
                            implicitWidth: 8; implicitHeight: 8; radius: 4
                            color: rrow.modelData.running ? Theme.success : Theme.withAlpha(Theme.textMuted, 0.35)
                            ToolTip.visible: dotHover.hovered; ToolTip.delay: Theme.tooltipDelay
                            ToolTip.text: rrow.modelData.running ? qsTr("Currently running") : qsTr("Not running")
                            HoverHandler { id: dotHover }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                Layout.fillWidth: true
                                text: rrow.modelData.name
                                color: Theme.textPrimary
                                font.weight: Theme.wHeading
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: rrow.modelData.reloadCommand !== ""
                                    ? qsTr("Command: %1").arg(rrow.modelData.reloadCommand)
                                    : (rrow.modelData.launchCommand !== ""
                                       ? qsTr("Process: %1 · Relaunch: %2").arg(rrow.modelData.processName, rrow.modelData.launchCommand)
                                       : qsTr("Process: %1 · Relaunch with original command").arg(rrow.modelData.processName))
                                color: Theme.textMuted
                                font.family: Theme.monoFamily
                                font.pixelSize: Theme.fsCaption
                                elide: Text.ElideRight
                            }
                        }
                        CheckBox {
                            text: qsTr("Auto")
                            checked: rrow.modelData.autoReload
                            onToggled: backend.setAppAutoReload(rrow.modelData.id, checked)
                            ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay
                            ToolTip.text: qsTr("Automatically reload after installing a font (when off, shows a one-click Reload button)")
                        }
                        Button {
                            flat: true
                            text: qsTr("Reload")
                            enabled: rrow.modelData.running || rrow.modelData.reloadCommand !== ""
                            onClicked: backend.reloadRegisteredApp(rrow.modelData.id)
                        }
                        Button {
                            flat: true
                            text: qsTr("Remove")
                            onClicked: backend.removeRegisteredApp(rrow.modelData.id)
                        }
                    }
                    Rectangle {
                        visible: rrow.index < regList.count - 1
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Theme.hairline
                        color: Theme.border
                    }
                }
            }
        }

        // ── Quick-add from discovered installed/running desktop apps ─────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.s1
            spacing: Theme.s2
            Label {
                text: qsTr("Installed applications")
                color: Theme.textPrimary
                font.weight: Theme.wHeading
            }
            Item { Layout.fillWidth: true }
            TextField {
                id: appFilter
                Layout.preferredWidth: 240
                placeholderText: qsTr("Search applications…")
                onTextChanged: sheet.searchQuery = text
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.rCard
            color: Theme.panelRaised
            border.width: Theme.hairline
            border.color: Theme.border
            clip: true

            ListView {
                id: discoverList
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                model: sheet.filteredDiscovered()
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Item {
                    id: drow
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 40

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s3
                        anchors.rightMargin: Theme.s3
                        spacing: Theme.s2

                        Rectangle {
                            implicitWidth: 7; implicitHeight: 7; radius: 4
                            color: drow.modelData.running ? Theme.success : "transparent"
                            border.width: drow.modelData.running ? 0 : 1
                            border.color: Theme.withAlpha(Theme.textMuted, 0.35)
                        }
                        Label {
                            text: drow.modelData.name
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: drow.modelData.processName + (drow.modelData.category !== "" ? " · " + drow.modelData.category : "")
                            color: Theme.textMuted
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fsCaption
                            elide: Text.ElideRight
                        }
                        Button {
                            flat: true
                            text: qsTr("Register")
                            onClicked: backend.registerApp(drow.modelData.name, drow.modelData.processName, drow.modelData.launchCommand, "", true)
                        }
                    }
                    Rectangle {
                        visible: drow.index < discoverList.count - 1
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
