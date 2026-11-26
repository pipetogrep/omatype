import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// Editorial open-source type catalog.
// Single unified control bar, hairline-ruled specimens on shared baselines,
// hover-revealed actions, zero ellipses, zero fallback-font ghosts.
Rectangle {
    id: root
    color: Theme.windowBg

    property bool sidebarOpen: true
    signal toggleSidebarRequested()

    property int previewSize: 40
    property string layoutMode: "grid" // "grid" | "list"
    property bool editingSample: false

    readonly property var samplePresets: [
        { label: qsTr("Editorial"), text: "Typography is what language looks like." },
        { label: qsTr("Pangram"), text: "The quick brown fox jumps over the lazy dog" },
        { label: qsTr("Figures"), text: "0123456789 · $4,290.50 · 2026–11–26" },
        { label: qsTr("Alphabet"), text: "Aa Bb Cc Dd Ee Ff Gg Hh Ii Jj Kk Ll Mm Nn" },
        { label: qsTr("Paragraph"), text: "Good typography is invisible until it is absent. Every letterform carries rhythm, proportion, and quiet intent." }
    ]

    readonly property var categories: [
        { key: "", label: qsTr("All") },
        { key: "Sans Serif", label: qsTr("Sans") },
        { key: "Serif", label: qsTr("Serif") },
        { key: "Display", label: qsTr("Display") },
        { key: "Handwriting", label: qsTr("Script") },
        { key: "Monospace", label: qsTr("Mono") }
    ]

    readonly property var scripts: [
        { key: "", label: qsTr("Scripts") },
        { key: "latin", label: qsTr("Latin") },
        { key: "latin-ext", label: qsTr("Latin Extended") },
        { key: "greek", label: qsTr("Greek") },
        { key: "cyrillic", label: qsTr("Cyrillic") },
        { key: "arabic", label: qsTr("Arabic") },
        { key: "devanagari", label: qsTr("Devanagari") },
        { key: "japanese", label: qsTr("Japanese") },
        { key: "korean", label: qsTr("Korean") }
    ]

    readonly property var sortOptions: [
        { key: "popular", label: qsTr("Popular") },
        { key: "trending", label: qsTr("Trending") },
        { key: "newest", label: qsTr("Newest") },
        { key: "name", label: qsTr("A–Z") },
        { key: "styles", label: qsTr("Styles") }
    ]

    function focusSearch() {
        catalogSearchField.forceActiveFocus()
        catalogSearchField.selectAll()
    }

    function currentScriptLabel() {
        for (let i = 0; i < scripts.length; ++i)
            if (scripts[i].key === catalog.scriptFilter) return scripts[i].label
        return qsTr("Scripts")
    }

    function currentSortLabel() {
        for (let i = 0; i < sortOptions.length; ++i)
            if (sortOptions[i].key === catalog.sortBy) return sortOptions[i].label
        return qsTr("Popular")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Single unified Discover control bar ─────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            color: Theme.windowBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s4
                anchors.rightMargin: Theme.s4
                spacing: Theme.s1 + 2

                ToolButton {
                    icon.name: "panel-left"
                    checked: root.sidebarOpen
                    onClicked: root.toggleSidebarRequested()
                    ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay; ToolTip.text: qsTr("Sidebar  Ctrl+B")
                }

                // Quiet search input
                TextField {
                    id: catalogSearchField
                    objectName: "searchField"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 112
                    Layout.minimumWidth: 88
                    Layout.maximumWidth: 112
                    text: catalog.query
                    placeholderText: qsTr("Search…")
                    leftPadding: Theme.s2 + Theme.szIcon + Theme.s1
                    rightPadding: text !== "" ? 26 : Theme.s2
                    font.pixelSize: Theme.fsLabel
                    onTextEdited: catalog.query = text
                    Keys.onEscapePressed: { text = ""; catalog.query = ""; focus = false }
                    background: Rectangle {
                        implicitHeight: 28
                        radius: Theme.rControl
                        color: catalogSearchField.activeFocus ? Theme.panelBg : Theme.withAlpha(Theme.panelBg, 0.55)
                        border.width: Theme.hairline
                        border.color: catalogSearchField.activeFocus ? Theme.borderStrong : Theme.withAlpha(Theme.border, 0.5)
                    }
                    Icon { name: "search"; size: 14; color: Theme.textMuted; x: Theme.s2; anchors.verticalCenter: parent.verticalCenter }
                    ToolButton {
                        visible: catalogSearchField.text !== ""
                        icon.name: "x"
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        onClicked: { catalogSearchField.text = ""; catalog.query = "" }
                    }
                }

                Rectangle { implicitWidth: Theme.hairline; implicitHeight: 16; color: Theme.withAlpha(Theme.border, 0.6) }

                // Category tabs
                OverflowTabs {
                    objectName: "categoryTabs"
                    model: root.categories
                    current: catalog.category
                    onActivated: (key) => catalog.category = key
                }

                // Orthogonal Variable toggle (clean text toggle, no dead dark checkbox)
                Rectangle { implicitWidth: Theme.hairline; implicitHeight: 16; color: Theme.withAlpha(Theme.border, 0.5) }
                Button {
                    flat: !catalog.variableOnly
                    checked: catalog.variableOnly
                    implicitHeight: 26
                    text: qsTr("Variable")
                    font.pixelSize: Theme.fsLabel
                    onClicked: catalog.variableOnly = !catalog.variableOnly
                }

                Item { Layout.fillWidth: true }

                QuietMenuButton {
                    id: scriptMenuBtn
                    text: root.currentScriptLabel()
                    onClicked: scriptMenu.popup(scriptMenuBtn, 0, scriptMenuBtn.height)
                    Menu {
                        id: scriptMenu
                        Repeater {
                            model: root.scripts
                            MenuItem {
                                required property var modelData
                                text: modelData.label
                                checkable: true
                                checked: catalog.scriptFilter === modelData.key
                                onTriggered: catalog.scriptFilter = modelData.key
                            }
                        }
                    }
                }

                QuietMenuButton {
                    id: sortMenuBtn
                    text: root.currentSortLabel()
                    onClicked: sortMenu.popup(sortMenuBtn, 0, sortMenuBtn.height)
                    Menu {
                        id: sortMenu
                        Repeater {
                            model: root.sortOptions
                            MenuItem {
                                required property var modelData
                                text: modelData.label
                                checkable: true
                                checked: catalog.sortBy === modelData.key
                                onTriggered: catalog.sortBy = modelData.key
                            }
                        }
                    }
                }

                Rectangle { visible: catalogSizeSlider.visible; implicitWidth: Theme.hairline; implicitHeight: 16; color: Theme.withAlpha(Theme.border, 0.5) }

                // Size slider followed by matching toolbar readout
                // The size readout steps aside when the right panel leaves the
                // toolbar too little room; the tabs fold first.
                Slider {
                    id: catalogSizeSlider
                    visible: root.width >= 640
                    Layout.preferredWidth: 50
                    from: 24; to: 64; stepSize: 2
                    value: root.previewSize
                    onMoved: root.previewSize = Math.round(value)
                }
                Label {
                    visible: catalogSizeSlider.visible
                    text: String(root.previewSize)
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    Layout.preferredWidth: 18
                }

                // Clear Sample menu (instead of cryptic bare T icon)
                QuietMenuButton {
                    id: sampleBtn
                    text: qsTr("Sample")
                    onClicked: sampleMenu.popup(sampleBtn, -80, sampleBtn.height)
                    Menu {
                        id: sampleMenu
                        MenuItem {
                            text: root.editingSample ? qsTr("Hide custom text bar") : qsTr("Type custom text")
                            onTriggered: {
                                root.editingSample = !root.editingSample
                                if (root.editingSample) inlineSampleField.forceActiveFocus()
                            }
                        }
                        MenuSeparator {}
                        Repeater {
                            model: root.samplePresets
                            MenuItem {
                                required property var modelData
                                text: modelData.label
                                checkable: true
                                checked: catalog.sampleText === modelData.text
                                onTriggered: catalog.sampleText = modelData.text
                            }
                        }
                    }
                }

                // Below this width the grid is one column anyway.
                ToolButton {
                    visible: root.width >= 600
                    icon.name: root.layoutMode === "grid" ? "rows-3" : "layout-grid"
                    onClicked: root.layoutMode = root.layoutMode === "grid" ? "list" : "grid"
                    ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay
                    ToolTip.text: root.layoutMode === "grid" ? qsTr("Full-width rows") : qsTr("Grid")
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.hairline; color: Theme.border }
        }

        // ── Contextual Shortlist actions (only when viewing Shortlist) ──────
        Rectangle {
            visible: catalog.sourceFilter === "shortlist" && catalog.shortlistCount > 0
            Layout.fillWidth: true
            implicitHeight: visible ? 40 : 0
            color: Theme.windowBg
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s5
                anchors.rightMargin: Theme.s5
                spacing: Theme.s2
                Label {
                    text: Theme.plural(catalog.shortlistCount, qsTr("shortlisted typeface"), qsTr("shortlisted typefaces"))
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fsLabel
                }
                Item { Layout.fillWidth: true }
                Button { flat: true; implicitHeight: 26; text: qsTr("Clear"); font.pixelSize: Theme.fsLabel; onClicked: catalog.clearShortlist() }
                Button {
                    implicitHeight: 26
                    text: qsTr("Install all")
                    font.pixelSize: Theme.fsLabel
                    enabled: !catalog.installingAny
                    onClicked: catalog.installShortlist()
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.hairline; color: Theme.withAlpha(Theme.border, 0.45) }
        }

        // ── Optional custom sample input (only shown when user clicks "Type custom text") ─
        Rectangle {
            visible: root.editingSample
            Layout.fillWidth: true
            implicitHeight: visible ? 40 : 0
            color: Theme.panelBg
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s5
                anchors.rightMargin: Theme.s5
                spacing: Theme.s2
                TextField {
                    id: inlineSampleField
                    objectName: "catalogSampleField"
                    Layout.fillWidth: true
                    text: catalog.sampleText
                    placeholderText: qsTr("Type any text to preview across all typefaces…")
                    onTextEdited: catalog.sampleText = text
                    Keys.onEscapePressed: root.editingSample = false
                    background: null
                }
                ToolButton { icon.name: "x"; onClicked: root.editingSample = false }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.hairline; color: Theme.border }
        }

        // ── Optional offline notice ─────────────────────────────────────────
        Rectangle {
            visible: catalog.error !== ""
            Layout.fillWidth: true
            implicitHeight: visible ? 28 : 0
            color: Theme.withAlpha(Theme.warning, 0.10)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s5
                anchors.rightMargin: Theme.s5
                spacing: Theme.s2
                Icon { name: "circle-alert"; size: 13; color: Theme.warning }
                Label { Layout.fillWidth: true; text: catalog.error; color: Theme.warning; font.pixelSize: Theme.fsLabel; elide: Text.ElideRight }
            }
        }

        // ── Editorial specimen grid (edge-to-edge Swiss cells, zero hover jump) ─
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid
                anchors.fill: parent
                clip: true
                model: catalog.model
                readonly property int columns: root.layoutMode === "list" ? 1 : Math.max(1, Math.floor(width / 430))
                cellWidth: Math.floor(width / columns)
                cellHeight: root.layoutMode === "list"
                    ? Math.max(144, Math.round(root.previewSize * 1.15 * 2 + 80))
                    : Math.max(138, Math.round(root.previewSize * 1.15 + 92))
                cacheBuffer: cellHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                delegate: Item {
                    id: cell
                    required property int index
                    required property string id
                    required property string family
                    required property string source
                    required property string sourceLabel
                    required property string designersText
                    required property string category
                    required property string license
                    required property int styleCount
                    required property string weightRange
                    required property bool variable
                    required property string previewFile
                    required property bool installed
                    required property bool installing
                    required property bool shortlisted

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Component.onCompleted: catalog.requestPreview(cell.id)
                    onIdChanged: catalog.requestPreview(cell.id)
                    onPreviewFileChanged: if (previewFile === "") catalog.requestPreview(cell.id)

                    Loader {
                        id: faceLoader
                        active: cell.previewFile !== ""
                        sourceComponent: FontLoader { source: catalog.fileUrl(cell.previewFile) }
                    }
                    readonly property bool faceReady: faceLoader.item !== null && faceLoader.item.status === FontLoader.Ready
                    readonly property bool selected: catalog.selectedId === cell.id
                    readonly property bool hasRightNeighbor: (cell.index % grid.columns) < (grid.columns - 1)

                    // Edge-to-edge cell surface: calm tint on hover/selection, no borders shifting layout
                    Rectangle {
                        id: surface
                        anchors.fill: parent
                        color: cell.selected ? Theme.withAlpha(Theme.accent, 0.08)
                             : cellHover.hovered ? Theme.withAlpha(Theme.textPrimary, 0.028) : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.dFast } }

                        // Edge-to-edge bottom hairline
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Theme.hairline
                            color: Theme.withAlpha(Theme.border, 0.45)
                        }

                        // Edge-to-edge vertical cell divider between columns
                        Rectangle {
                            visible: cell.hasRightNeighbor
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Theme.hairline
                            color: Theme.withAlpha(Theme.border, 0.45)
                        }

                        HoverHandler { id: cellHover }
                        TapHandler { onTapped: catalog.selectFamily(cell.id) }

                        // Fixed-height header so hover actions never cause vertical jump
                        RowLayout {
                            id: cellHeader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: Theme.s5
                            anchors.rightMargin: Theme.s4
                            anchors.topMargin: Theme.s3
                            height: 28
                            spacing: Theme.s2

                            Text {
                                text: cell.family
                                textFormat: Text.PlainText
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsControl
                                font.weight: Font.Medium
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: cell.designersText !== ""
                                text: "—  " + cell.designersText
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Opacity-only reveal so text never reflows or jumps on hover
                            RowLayout {
                                spacing: Theme.s1
                                opacity: (cellHover.hovered || cell.selected || cell.installed || cell.shortlisted || cell.installing) ? 1.0 : 0.0
                                enabled: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: Theme.dFast } }

                                ToolButton {
                                    opacity: (cellHover.hovered || cell.selected || cell.shortlisted) ? 1.0 : 0.0
                                    enabled: opacity > 0
                                    icon.name: "bookmark"
                                    checked: cell.shortlisted
                                    onClicked: catalog.toggleShortlist(cell.id)
                                    ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay
                                    ToolTip.text: cell.shortlisted ? qsTr("Remove from Shortlist") : qsTr("Shortlist")
                                }

                                Icon {
                                    visible: cell.installed
                                    name: "check"
                                    size: 14
                                    color: Theme.success
                                }

                                Button {
                                    objectName: "cardInstall_" + cell.id
                                    visible: !cell.installed
                                    opacity: (cellHover.hovered || cell.selected || cell.installing) ? 1.0 : 0.0
                                    enabled: opacity > 0 && !cell.installing
                                    flat: true
                                    implicitHeight: 24
                                    text: cell.installing ? qsTr("Installing") : qsTr("Install")
                                    font.pixelSize: Theme.fsLabel
                                    onClicked: catalog.installFamily(cell.id, true, [])
                                }
                            }
                        }

                        // Specimen: true typographic baseline alignment across every row;
                        // never ellipsized; never drawn in a fallback font while loading.
                        Item {
                            id: specimenBox
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: cellHeader.bottom
                            anchors.bottom: cellFooter.top
                            anchors.leftMargin: Theme.s5
                            anchors.rightMargin: Theme.s5
                            anchors.topMargin: Theme.s1
                            anchors.bottomMargin: Theme.s2
                            clip: true

                            // Exact shared baseline coordinate for every cell in a row
                            Item {
                                id: sharedBaseline
                                anchors.left: parent.left
                                anchors.right: parent.right
                                y: Math.min(parent.height - 6, Math.round(root.previewSize * 1.0))
                                height: 1
                            }

                            // Quiet baseline rule while the subsetted TTF streams in
                            Rectangle {
                                visible: !cell.faceReady
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: sharedBaseline.top
                                height: Theme.hairline
                                color: Theme.withAlpha(Theme.border, 0.55)
                            }

                            Text {
                                id: specimenText
                                visible: cell.faceReady
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.baseline: root.layoutMode === "grid" ? sharedBaseline.top : undefined
                                anchors.top: root.layoutMode === "list" ? parent.top : undefined
                                text: catalog.sampleText === "" ? "Typography is what language looks like." : catalog.sampleText
                                textFormat: Text.PlainText
                                font.family: cell.faceReady ? faceLoader.item.name : Theme.fontFamily
                                font.pixelSize: root.previewSize
                                color: Theme.specimenInk
                                wrapMode: root.layoutMode === "list" ? Text.Wrap : Text.NoWrap
                                maximumLineCount: root.layoutMode === "list" ? 2 : 1
                                lineHeightMode: Text.FixedHeight
                                lineHeight: Math.round(root.previewSize * 1.15)
                                elide: Text.ElideNone
                            }

                            // Subtle right-edge fade when single-line specimen extends past cell
                            Rectangle {
                                visible: cell.faceReady && root.layoutMode === "grid" && specimenText.implicitWidth > specimenBox.width
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 36
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: cell.selected ? Qt.tint(Theme.windowBg, Theme.withAlpha(Theme.accent, 0.08)) : Theme.windowBg }
                                }
                            }
                        }

                        // Quiet single-line provenance footer
                        Text {
                            id: cellFooter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: Theme.s5
                            anchors.rightMargin: Theme.s5
                            anchors.bottomMargin: Theme.s3
                            text: (cell.source === "google" ? "Google Fonts" : cell.sourceLabel)
                                  + "  ·  "
                                  + (cell.variable ? qsTr("Variable") : Theme.plural(cell.styleCount, qsTr("style"), qsTr("styles")))
                            color: Theme.withAlpha(Theme.textSecondary, 0.72)
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Quiet empty / loading state
            Column {
                anchors.centerIn: parent
                visible: grid.count === 0
                spacing: Theme.s2
                width: Math.min(parent.width - Theme.s6 * 2, 340)
                BusyIndicator {
                    visible: catalog.loading
                    running: visible
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fsTitle
                    font.weight: Theme.wHeading
                    text: catalog.loading ? qsTr("Loading catalog…")
                        : catalog.sourceFilter === "shortlist" ? qsTr("No shortlisted typefaces")
                        : qsTr("No matches")
                }
                Button {
                    visible: !catalog.loading && catalog.sourceFilter !== "shortlist"
                    anchors.horizontalCenter: parent.horizontalCenter
                    flat: true
                    text: qsTr("Reset filters")
                    onClicked: catalog.resetFilters()
                }
            }
        }
    }
}
