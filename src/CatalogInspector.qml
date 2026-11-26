import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// Printed-specimen-style detail panel:
// Display name -> Designer -> Solid primary Install -> Modular waterfall +
// glyph/paragraph study -> Clean metadata -> Unified weight picker.
Rectangle {
    id: panel
    color: Theme.panelBg

    signal openInLibraryRequested(string familyName)

    readonly property var fam: catalog.selectedFamily
    readonly property bool hasSelection: (fam.id ?? "") !== ""
    readonly property var files: catalog.selectedFiles
    property var selectedFilenames: []

    onFamChanged: selectedFilenames = []

    function toggleFile(filename) {
        const idx = selectedFilenames.indexOf(filename)
        const next = selectedFilenames.slice()
        if (idx >= 0) next.splice(idx, 1)
        else next.push(filename)
        selectedFilenames = next
    }

    function formatSubsets(list) {
        const map = {
            "latin": "Latin",
            "latin-ext": "Latin Extended",
            "cyrillic": "Cyrillic",
            "cyrillic-ext": "Cyrillic Extended",
            "greek": "Greek",
            "greek-ext": "Greek Extended",
            "vietnamese": "Vietnamese",
            "arabic": "Arabic",
            "hebrew": "Hebrew",
            "devanagari": "Devanagari",
            "japanese": "Japanese",
            "korean": "Korean",
            "thai": "Thai",
            "bengali": "Bengali",
            "tamil": "Tamil",
            "telugu": "Telugu"
        }
        const out = []
        for (let i = 0; i < list.length; ++i) {
            const k = list[i].toLowerCase()
            out.push(map[k] ?? (k.charAt(0).toUpperCase() + k.slice(1)))
        }
        return out.join(", ")
    }

    function installCtaLabel() {
        if (fam.installing ?? false) return qsTr("Installing…")
        if (fam.installed ?? false) return qsTr("Installed")
        if (selectedFilenames.length > 0)
            return qsTr("Install %1").arg(Theme.plural(selectedFilenames.length, qsTr("style"), qsTr("styles")))
        return qsTr("Install")
    }

    Loader {
        id: faceLoader
        active: (panel.fam.previewFile ?? "") !== ""
        sourceComponent: FontLoader { source: catalog.fileUrl(panel.fam.previewFile) }
    }
    readonly property bool faceReady: faceLoader.item !== null && faceLoader.item.status === FontLoader.Ready

    component Fact: RowLayout {
        property string label: ""
        property string value: ""
        visible: value !== ""
        Layout.fillWidth: true
        spacing: Theme.s3
        Label {
            Layout.preferredWidth: 64
            Layout.alignment: Qt.AlignTop
            text: label
            color: Theme.textMuted
            font.pixelSize: Theme.fsLabel
        }
        Label {
            Layout.fillWidth: true
            text: value
            color: Theme.textSecondary
            font.pixelSize: Theme.fsLabel
            wrapMode: Text.Wrap
        }
    }

    component TextLink: Item {
        id: linkItem
        property string text: ""
        signal clicked()
        implicitWidth: linkLabel.implicitWidth
        implicitHeight: linkLabel.implicitHeight + 4
        HoverHandler { id: linkHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: linkItem.clicked() }
        Text {
            id: linkLabel
            anchors.verticalCenter: parent.verticalCenter
            text: linkItem.text + " ↗"
            color: linkHover.hovered ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsLabel
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight + Theme.s5 * 2
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: content
            x: Theme.s5
            y: Theme.s5
            width: flick.width - Theme.s5 * 2
            spacing: Theme.s4
            visible: panel.hasSelection

            // ── Identity & Designer Attribution ─────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s2
                    Text {
                        Layout.fillWidth: true
                        text: panel.fam.family ?? ""
                        textFormat: Text.PlainText
                        font.family: panel.faceReady ? faceLoader.item.name : Theme.fontFamily
                        font.pixelSize: 34
                        color: Theme.specimenInk
                        wrapMode: Text.Wrap
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 38
                    }
                    ToolButton {
                        Layout.alignment: Qt.AlignTop
                        flat: true
                        icon.name: "bookmark"
                        checked: panel.fam.shortlisted ?? false
                        onClicked: catalog.toggleShortlist(panel.fam.id)
                        ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay
                        ToolTip.text: (panel.fam.shortlisted ?? false) ? qsTr("Remove from Shortlist") : qsTr("Shortlist")
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: (panel.fam.designersText ?? "") !== ""
                    text: panel.fam.designersText ?? ""
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fsControl
                    wrapMode: Text.Wrap
                }

                Label {
                    Layout.fillWidth: true
                    text: [
                        panel.fam.sourceLabel ?? "",
                        panel.fam.category ?? "",
                        panel.fam.license ?? ""
                    ].filter(s => s !== "").join("  ·  ")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsLabel
                    wrapMode: Text.Wrap
                }
            }

            // ── The one solid primary CTA in the window ─────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s2

                Rectangle {
                    id: installBtn
                    objectName: "inspectorCatalogInstall"
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.rControl
                    readonly property bool isInstalled: panel.fam.installed ?? false
                    readonly property bool isBusy: panel.fam.installing ?? false
                    color: isInstalled ? Theme.controlBg
                         : installHover.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                    opacity: isBusy ? 0.65 : 1.0

                    HoverHandler { id: installHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        enabled: !installBtn.isBusy
                        onTapped: catalog.installFamily(panel.fam.id, true, panel.selectedFilenames)
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Theme.s2
                        Icon {
                            name: installBtn.isInstalled ? "check" : "download"
                            size: 15
                            color: installBtn.isInstalled ? Theme.success : Theme.accentText
                        }
                        Text {
                            text: panel.installCtaLabel()
                            color: installBtn.isInstalled ? Theme.textPrimary : Theme.accentText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsControl
                            font.weight: Font.DemiBold
                        }
                    }
                }

                RowLayout {
                    visible: panel.fam.installed ?? false
                    Layout.fillWidth: true
                    spacing: Theme.s3
                    TextLink { text: qsTr("Open in Library"); onClicked: panel.openInLibraryRequested(panel.fam.family) }
                    Item { Layout.fillWidth: true }
                    TextLink { text: qsTr("Uninstall"); onClicked: catalog.uninstallFamily(panel.fam.id) }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.hairline; color: Theme.withAlpha(Theme.border, 0.45) }

            // ── Printed-specimen waterfall + glyphs + body paragraph ────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                visible: panel.faceReady

                Repeater {
                    model: [40, 26, 16]
                    Item {
                        required property int modelData
                        Layout.fillWidth: true
                        implicitHeight: wfText.implicitHeight
                        clip: true

                        Text {
                            id: wfLabel
                            anchors.left: parent.left
                            anchors.baseline: wfText.baseline
                            width: 20
                            text: String(modelData)
                            color: Theme.textMuted
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fsCaption
                            horizontalAlignment: Text.AlignRight
                        }

                        Text {
                            id: wfText
                            anchors.left: parent.left
                            anchors.leftMargin: 28
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: catalog.sampleText === "" ? "Typography is what language looks like." : catalog.sampleText
                            textFormat: Text.PlainText
                            font.family: panel.faceReady ? faceLoader.item.name : Theme.fontFamily
                            font.pixelSize: modelData
                            color: Theme.specimenInk
                            wrapMode: Text.NoWrap
                            maximumLineCount: 1
                            lineHeightMode: Text.FixedHeight
                            lineHeight: Math.round(modelData * 1.18)
                        }

                        Rectangle {
                            visible: wfText.implicitWidth > wfText.width
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 28
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Theme.panelBg }
                            }
                        }
                    }
                }

                // Glyphs & figures study (shows what the grid cannot)
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.s1
                    text: "AaBbCcGgQqRr&\n0123456789"
                    textFormat: Text.PlainText
                    font.family: panel.faceReady ? faceLoader.item.name : Theme.fontFamily
                    font.pixelSize: 22
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 28
                    color: Theme.textSecondary
                }

                // Editorial body-copy texture
                Text {
                    Layout.fillWidth: true
                    text: (panel.fam.description ?? "") !== ""
                        ? panel.fam.description
                        : "Good typography is invisible until it is absent. Every letterform carries rhythm, proportion, and quiet intent."
                    textFormat: Text.PlainText
                    font.family: panel.faceReady ? faceLoader.item.name : Theme.fontFamily
                    font.pixelSize: 14
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 21
                    color: Theme.textSecondary
                    wrapMode: Text.Wrap
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.hairline; color: Theme.withAlpha(Theme.border, 0.45) }

            // ── Deduplicated Metadata & Quiet Links ─────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Fact { label: qsTr("Axes"); value: panel.fam.axesSummary ?? "" }
                Fact { label: qsTr("Weights"); value: (panel.fam.axesSummary ?? "") === "" ? (panel.fam.weightRange ?? "") : "" }
                Fact { label: qsTr("Scripts"); value: panel.formatSubsets(panel.fam.subsets ?? []) }
                Fact { label: qsTr("Added"); value: panel.fam.dateAdded ?? "" }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.s1
                    spacing: Theme.s4
                    visible: (panel.fam.homepage ?? "") !== "" || (panel.fam.repoUrl ?? "") !== ""
                    TextLink {
                        visible: (panel.fam.homepage ?? "") !== ""
                        text: qsTr("Specimen")
                        onClicked: catalog.openUrl(panel.fam.homepage)
                    }
                    TextLink {
                        visible: (panel.fam.repoUrl ?? "") !== ""
                        text: qsTr("Source")
                        onClicked: catalog.openUrl(panel.fam.repoUrl)
                    }
                }
            }

            Rectangle {
                visible: panel.files.length > 0 || catalog.loadingManifest
                Layout.fillWidth: true
                implicitHeight: Theme.hairline
                color: Theme.withAlpha(Theme.border, 0.45)
            }

            // ── Single unified Weight Picker (left accent bar, no checkboxes) ─
            ColumnLayout {
                visible: panel.files.length > 0 || catalog.loadingManifest
                Layout.fillWidth: true
                spacing: 2

                Label {
                    visible: catalog.loadingManifest
                    text: qsTr("Loading styles…")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsLabel
                }

                Repeater {
                    model: panel.files
                    Item {
                        id: wRow
                        required property var modelData
                        readonly property bool chosen: panel.selectedFilenames.indexOf(modelData.filename) >= 0
                        Layout.fillWidth: true
                        implicitHeight: 28

                        HoverHandler { id: wHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: panel.toggleFile(wRow.modelData.filename) }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rControl
                            color: wRow.chosen ? Theme.withAlpha(Theme.textPrimary, 0.06)
                                 : wHover.hovered ? Theme.withAlpha(Theme.textPrimary, 0.03) : "transparent"
                        }
                        Rectangle {
                            visible: wRow.chosen
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 5
                            anchors.bottomMargin: 5
                            width: 2
                            color: Theme.accent
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s2
                            anchors.rightMargin: Theme.s2
                            spacing: Theme.s2
                            Label {
                                Layout.fillWidth: true
                                text: wRow.modelData.style
                                color: wRow.chosen ? Theme.textPrimary : Theme.textSecondary
                                font.pixelSize: Theme.fsLabel
                                font.weight: wRow.chosen ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }
                            Label {
                                visible: !wRow.modelData.variable && wRow.modelData.weight > 0
                                text: String(wRow.modelData.weight)
                                color: Theme.textMuted
                                font.family: Theme.monoFamily
                                font.pixelSize: Theme.fsCaption
                            }
                        }
                    }
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: !panel.hasSelection
            width: flick.width - Theme.s6 * 2
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.textMuted
            font.pixelSize: Theme.fsLabel
            text: qsTr("Select a typeface")
        }
    }
}
