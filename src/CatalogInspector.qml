import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// Right-hand detail & attribution pane for a selected open-source catalog
// typeface: prominent type designer credit, foundry/license provenance, live
// multi-size specimen waterfall, one-click family install, and granular weight
// selection.
Rectangle {
    id: panel
    color: Theme.panelBg

    signal openInLibraryRequested(string familyName)

    readonly property var fam: catalog.selectedFamily
    readonly property bool hasSelection: (fam.id ?? "") !== ""
    readonly property var files: catalog.selectedFiles
    property bool preferVariable: true
    property var selectedFilenames: []

    onFamChanged: {
        // Reset per-weight selection when switching families
        selectedFilenames = []
        preferVariable = fam.variable ?? false
    }

    function toggleFile(filename) {
        const idx = selectedFilenames.indexOf(filename)
        const next = selectedFilenames.slice()
        if (idx >= 0) next.splice(idx, 1)
        else next.push(filename)
        selectedFilenames = next
    }

    Loader {
        id: faceLoader
        active: (panel.fam.previewFile ?? "") !== ""
        sourceComponent: FontLoader { source: catalog.fileUrl(panel.fam.previewFile) }
    }
    readonly property bool faceReady: faceLoader.item !== null && faceLoader.item.status === FontLoader.Ready

    component Chip: Rectangle {
        property string text: ""
        property color tone: Theme.textSecondary
        implicitWidth: lbl.implicitWidth + Theme.s2 * 2
        implicitHeight: Theme.szIcon + Theme.s1 + 2
        radius: Theme.rChip
        color: Theme.withAlpha(tone, 0.12)
        border.width: Theme.hairline
        border.color: Theme.withAlpha(tone, 0.45)
        Text {
            id: lbl
            anchors.centerIn: parent
            text: parent.text
            textFormat: Text.PlainText
            color: parent.tone
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsCaption
            font.weight: Theme.wHeading
        }
    }

    component Fact: RowLayout {
        property string label: ""
        property string value: ""
        visible: value !== ""
        Layout.fillWidth: true
        spacing: Theme.s2
        Label {
            Layout.preferredWidth: Theme.wFactLabel
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s3
            implicitHeight: Theme.hNavHeader
            spacing: Theme.s2
            Label { text: qsTr("Typeface Details"); font.weight: Theme.wHeading; color: Theme.textPrimary }
            Item { Layout.fillWidth: true }
            ToolButton {
                visible: panel.hasSelection
                icon.name: "bookmark"
                checked: panel.fam.shortlisted ?? false
                onClicked: catalog.toggleShortlist(panel.fam.id)
                ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay
                ToolTip.text: (panel.fam.shortlisted ?? false) ? qsTr("Remove from Shortlist") : qsTr("Add to Shortlist")
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: Theme.hairline; color: Theme.border }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: content.implicitHeight + Theme.s5 * 2
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: content
                x: Theme.s4
                y: Theme.s4
                width: flick.width - Theme.s4 * 2
                spacing: Theme.s3
                visible: panel.hasSelection

                // Hero display name in its own typeface
                Text {
                    Layout.fillWidth: true
                    text: panel.fam.family ?? ""
                    textFormat: Text.PlainText
                    font.family: panel.faceReady ? faceLoader.item.name : Theme.fontFamily
                    font.pixelSize: 32
                    color: Theme.specimenInk
                    wrapMode: Text.Wrap
                }

                // Prominent Designer Attribution card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: attrCol.implicitHeight + Theme.s3 * 2
                    radius: Theme.rCard
                    color: Theme.panelRaised
                    border.width: Theme.hairline
                    border.color: Theme.border
                    ColumnLayout {
                        id: attrCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: Theme.s3
                        spacing: Theme.s1
                        Label {
                            text: qsTr("TYPE DESIGNER")
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.weight: Theme.wHeading
                            font.letterSpacing: Theme.capsTracking
                        }
                        Label {
                            Layout.fillWidth: true
                            text: (panel.fam.designersText ?? "") !== "" ? panel.fam.designersText : qsTr("Open-source contributors")
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fsHeading
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }
                        Label {
                            Layout.fillWidth: true
                            text: [panel.fam.sourceLabel ?? "", panel.fam.license ?? ""].filter(s => s !== "").join("  ·  ")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fsLabel
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // Classification & capability chips
                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.s1
                    Chip { visible: panel.fam.installed ?? false; text: qsTr("Installed"); tone: Theme.success }
                    Chip { text: panel.fam.category ?? ""; tone: Theme.textSecondary }
                    Chip { visible: panel.fam.variable ?? false; text: qsTr("Variable"); tone: Theme.accent }
                    Chip { text: Theme.plural(panel.fam.styleCount ?? 1, qsTr("style"), qsTr("styles")) }
                    Chip { visible: (panel.fam.weightRange ?? "") !== ""; text: panel.fam.weightRange ?? "" }
                }

                // ── 1-Click Install / Manage Actions ────────────────────────
                Button {
                    objectName: "inspectorCatalogInstall"
                    Layout.fillWidth: true
                    highlighted: !(panel.fam.installed ?? false)
                    enabled: !(panel.fam.installing ?? false)
                    icon.name: (panel.fam.installed ?? false) ? "check" : "download"
                    text: (panel.fam.installing ?? false) ? qsTr("Installing…")
                        : (panel.fam.installed ?? false) ? qsTr("Installed · Reinstall Family")
                        : panel.selectedFilenames.length > 0 ? qsTr("Install %1 Selected").arg(panel.selectedFilenames.length)
                        : (panel.fam.variable ?? false) && panel.preferVariable ? qsTr("One-Click Install (Variable)")
                        : qsTr("One-Click Install Family")
                    onClicked: catalog.installFamily(panel.fam.id, panel.preferVariable, panel.selectedFilenames)
                }

                RowLayout {
                    visible: panel.fam.installed ?? false
                    Layout.fillWidth: true
                    spacing: Theme.s1
                    Button {
                        Layout.fillWidth: true
                        icon.name: "type"
                        text: qsTr("Open in Library")
                        onClicked: panel.openInLibraryRequested(panel.fam.family)
                    }
                    Button {
                        Layout.fillWidth: true
                        icon.name: "trash-2"
                        text: qsTr("Uninstall")
                        onClicked: catalog.uninstallFamily(panel.fam.id)
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsCaption
                    text: qsTr("Installs directly to ~/.local/share/fonts/ and refreshes fontconfig — ready for FigCraft, ArtCraft and desktop apps.")
                }

                // ── Live Mini-Waterfall ─────────────────────────────────────
                SectionLabel { text: qsTr("SPECIMEN") }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: wfCol.implicitHeight + Theme.s3 * 2
                    radius: Theme.rCard
                    color: Theme.pasteboard
                    border.width: Theme.hairline
                    border.color: Theme.border
                    ColumnLayout {
                        id: wfCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: Theme.s3
                        spacing: Theme.s2
                        Repeater {
                            model: [28, 18, 13]
                            Text {
                                required property int modelData
                                Layout.fillWidth: true
                                text: catalog.sampleText === "" ? "The quick brown fox jumps over the lazy dog" : catalog.sampleText
                                textFormat: Text.PlainText
                                font.family: panel.faceReady ? faceLoader.item.name : Theme.fontFamily
                                font.pixelSize: modelData
                                color: Theme.specimenInk
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // ── Description (for indie/curated typefaces) ───────────────
                Label {
                    visible: (panel.fam.description ?? "") !== ""
                    Layout.fillWidth: true
                    text: panel.fam.description ?? ""
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fsLabel
                    wrapMode: Text.Wrap
                }

                // ── Metadata & Provenance ───────────────────────────────────
                SectionLabel { text: qsTr("METADATA") }
                Fact { label: qsTr("Foundry"); value: panel.fam.foundry ?? "" }
                Fact { label: qsTr("License"); value: (panel.fam.license ?? "") + qsTr(" (free for commercial & personal use)") }
                Fact { label: qsTr("Axes"); value: panel.fam.axesSummary ?? "" }
                Fact { label: qsTr("Scripts"); value: (panel.fam.subsets ?? []).join(", ") }
                Fact { label: qsTr("Added"); value: panel.fam.dateAdded ?? "" }

                // Clickable external links
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s1
                    visible: (panel.fam.homepage ?? "") !== "" || (panel.fam.repoUrl ?? "") !== ""
                    Button {
                        visible: (panel.fam.homepage ?? "") !== ""
                        Layout.fillWidth: true
                        flat: true
                        icon.name: "external-link"
                        text: qsTr("Specimen")
                        onClicked: catalog.openUrl(panel.fam.homepage)
                    }
                    Button {
                        visible: (panel.fam.repoUrl ?? "") !== ""
                        Layout.fillWidth: true
                        flat: true
                        icon.name: "globe"
                        text: qsTr("Repository")
                        onClicked: catalog.openUrl(panel.fam.repoUrl)
                    }
                }

                // ── Weight & Style Management ───────────────────────────────
                SectionLabel { text: qsTr("WEIGHTS & FILES") }
                RowLayout {
                    visible: (panel.fam.variable ?? false) && panel.files.length > 1
                    Layout.fillWidth: true
                    spacing: Theme.s1
                    Button {
                        Layout.fillWidth: true
                        text: qsTr("Variable")
                        checked: panel.preferVariable && panel.selectedFilenames.length === 0
                        onClicked: { panel.preferVariable = true; panel.selectedFilenames = [] }
                    }
                    Button {
                        Layout.fillWidth: true
                        text: qsTr("All Static")
                        checked: !panel.preferVariable && panel.selectedFilenames.length === 0
                        onClicked: { panel.preferVariable = false; panel.selectedFilenames = [] }
                    }
                }
                Label {
                    visible: catalog.loadingManifest
                    text: qsTr("Loading weight manifest…")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsLabel
                }
                Repeater {
                    model: panel.files
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.s1
                        CheckBox {
                            checked: panel.selectedFilenames.indexOf(modelData.filename) >= 0
                            onToggled: panel.toggleFile(modelData.filename)
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.style
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fsLabel
                            elide: Text.ElideRight
                        }
                        Chip {
                            visible: modelData.variable
                            text: "VF"
                            tone: Theme.accent
                        }
                        Label {
                            text: modelData.weight > 0 ? String(modelData.weight) : ""
                            color: Theme.textMuted
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fsCaption
                        }
                    }
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                visible: !panel.hasSelection
                width: flick.width - Theme.s5 * 2
                spacing: Theme.s2
                Icon { name: "type"; size: Theme.szIconHero; color: Theme.textMuted; anchors.horizontalCenter: parent.horizontalCenter }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.textPrimary
                    font.weight: Theme.wHeading
                    text: qsTr("Select a typeface")
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsLabel
                    text: qsTr("Click any card to see its designer attribution, license, weight manifest, and specimen waterfall.")
                }
            }
        }
    }
}
