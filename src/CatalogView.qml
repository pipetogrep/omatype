import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// Open-source type discovery: an Adobe Fonts-style browsing surface designed
// around generous whitespace, live custom specimens, designer attribution,
// Suitcase-style shortlisting, and one-click installation.
Rectangle {
    id: root
    color: Theme.pasteboard

    property int previewSize: 34
    property string layoutMode: "grid" // "grid" | "list"

    readonly property var samplePresets: [
        { label: qsTr("Sentence"), text: "The quick brown fox jumps over the lazy dog" },
        { label: qsTr("Editorial"), text: "Typography is what language looks like." },
        { label: qsTr("Paragraph"), text: "Good typography is invisible until it is absent. Every letterform carries rhythm, proportion, and quiet intent." },
        { label: qsTr("Figures"), text: "0123456789 · $4,290.50 · 2026–11–26 · 14:30" },
        { label: qsTr("Alphabet"), text: "Aa Bb Cc Dd Ee Ff Gg Hh Ii Jj Kk Ll Mm Nn Oo Pp" }
    ]

    readonly property var categories: [
        { key: "", label: qsTr("All") },
        { key: "Sans Serif", label: qsTr("Sans Serif") },
        { key: "Serif", label: qsTr("Serif") },
        { key: "Display", label: qsTr("Display") },
        { key: "Handwriting", label: qsTr("Handwriting") },
        { key: "Monospace", label: qsTr("Monospace") }
    ]

    readonly property var scripts: [
        { key: "", label: qsTr("Any script") },
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
        { key: "name", label: qsTr("Name A–Z") },
        { key: "styles", label: qsTr("Most styles") }
    ]

    component FilterPill: Button {
        property bool active: false
        flat: !active
        checked: active
        implicitHeight: Theme.hControl
        font.pixelSize: Theme.fsLabel
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Specimen bar: editable sample text, presets, size, layout ───────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 54
            color: Theme.panelBg
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s4
                anchors.rightMargin: Theme.s4
                spacing: Theme.s2

                TextField {
                    id: catalogSampleField
                    objectName: "catalogSampleField"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    text: catalog.sampleText
                    placeholderText: qsTr("Type your own words to preview every typeface…")
                    leftPadding: Theme.s2 + Theme.szIcon + Theme.s2
                    onTextEdited: catalog.sampleText = text
                    Icon { name: "type"; size: Theme.szIcon; color: Theme.textMuted; x: Theme.s2; anchors.verticalCenter: parent.verticalCenter }
                }

                Button {
                    id: presetBtn
                    flat: true
                    text: qsTr("Presets")
                    icon.name: "chevron-down"
                    property bool iconTrailing: true
                    onClicked: presetMenu.popup(presetBtn, 0, presetBtn.height)
                    Menu {
                        id: presetMenu
                        Repeater {
                            model: root.samplePresets
                            MenuItem {
                                required property var modelData
                                text: modelData.label
                                onTriggered: {
                                    catalog.sampleText = modelData.text
                                    catalogSampleField.text = modelData.text
                                }
                            }
                        }
                    }
                }

                Rectangle { implicitWidth: Theme.hairline; implicitHeight: 20; color: Theme.border }

                Label {
                    text: root.previewSize + "px"
                    color: Theme.textMuted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fsCaption
                    Layout.preferredWidth: 32
                    horizontalAlignment: Text.AlignRight
                }
                Slider {
                    id: catalogSizeSlider
                    Layout.preferredWidth: 104
                    from: 20; to: 64; stepSize: 2
                    value: root.previewSize
                    onMoved: root.previewSize = Math.round(value)
                }

                Rectangle {
                    implicitWidth: layoutRow.implicitWidth + Theme.s1 * 2
                    implicitHeight: Theme.hControl + 4
                    radius: Theme.rControl
                    color: Theme.withAlpha(Theme.controlBg, 0.55)
                    border.width: Theme.hairline
                    border.color: Theme.border
                    RowLayout {
                        id: layoutRow
                        anchors.centerIn: parent
                        spacing: 0
                        ToolButton {
                            icon.name: "layout-grid"
                            checked: root.layoutMode === "grid"
                            onClicked: root.layoutMode = "grid"
                            ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay; ToolTip.text: qsTr("Specimen grid")
                        }
                        ToolButton {
                            icon.name: "rows-3"
                            checked: root.layoutMode === "list"
                            onClicked: root.layoutMode = "list"
                            ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay; ToolTip.text: qsTr("Full-width specimen rows")
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.hairline; color: Theme.border }
        }

        // ── Faceted filter bar: classification, variable, script, sort ──────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 46
            color: Theme.withAlpha(Theme.panelBg, 0.72)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s4
                anchors.rightMargin: Theme.s4
                spacing: Theme.s1

                Repeater {
                    model: root.categories
                    FilterPill {
                        required property var modelData
                        text: modelData.label
                        active: catalog.category === modelData.key
                        onClicked: catalog.category = modelData.key
                    }
                }

                Rectangle { implicitWidth: Theme.hairline; implicitHeight: 18; Layout.leftMargin: Theme.s1; Layout.rightMargin: Theme.s1; color: Theme.border }

                FilterPill {
                    text: qsTr("Variable")
                    icon.name: "sliders-horizontal"
                    active: catalog.variableOnly
                    onClicked: catalog.variableOnly = !catalog.variableOnly
                }

                Item { Layout.fillWidth: true }

                ComboBox {
                    id: scriptCombo
                    Layout.preferredWidth: 126
                    model: root.scripts
                    textRole: "label"
                    currentIndex: {
                        for (let i = 0; i < root.scripts.length; ++i)
                            if (root.scripts[i].key === catalog.scriptFilter) return i
                        return 0
                    }
                    onActivated: (idx) => catalog.scriptFilter = root.scripts[idx].key
                }

                ComboBox {
                    id: sortCombo
                    Layout.preferredWidth: 126
                    model: root.sortOptions
                    textRole: "label"
                    currentIndex: {
                        for (let i = 0; i < root.sortOptions.length; ++i)
                            if (root.sortOptions[i].key === catalog.sortBy) return i
                        return 0
                    }
                    onActivated: (idx) => catalog.sortBy = root.sortOptions[idx].key
                }

                Label {
                    Layout.leftMargin: Theme.s2
                    text: catalog.loading ? qsTr("Indexing…") : Theme.plural(catalog.filteredCount, qsTr("typeface"), qsTr("typefaces"))
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsLabel
                    font.family: Theme.monoFamily
                }

                ToolButton {
                    icon.name: "refresh-cw"
                    enabled: !catalog.loading
                    onClicked: catalog.load(true)
                    ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay; ToolTip.text: qsTr("Refresh open-source catalog")
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.hairline; color: Theme.border }
        }

        // ── Optional non-blocking notice banner (offline/cached) ────────────
        Rectangle {
            visible: catalog.error !== ""
            Layout.fillWidth: true
            implicitHeight: visible ? 32 : 0
            color: Theme.withAlpha(Theme.warning, 0.12)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s4
                anchors.rightMargin: Theme.s4
                spacing: Theme.s2
                Icon { name: "circle-alert"; size: Theme.szIcon - 2; color: Theme.warning }
                Label { Layout.fillWidth: true; text: catalog.error; color: Theme.warning; font.pixelSize: Theme.fsLabel; elide: Text.ElideRight }
            }
        }

        // ── Main specimen grid / full-width rows ────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid
                anchors.fill: parent
                anchors.leftMargin: Theme.s5
                anchors.rightMargin: Theme.s5
                anchors.topMargin: Theme.s4
                anchors.bottomMargin: Theme.s4
                clip: true
                model: catalog.model
                readonly property int columns: root.layoutMode === "list" ? 1 : Math.max(1, Math.floor(width / 360))
                cellWidth: Math.floor(width / columns)
                cellHeight: root.layoutMode === "list"
                    ? Math.max(156, Math.round(root.previewSize * 2.1 + 96))
                    : Math.max(220, Math.round(root.previewSize * 2.4 + 132))
                cacheBuffer: cellHeight * 3
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                delegate: Item {
                    id: cardWrap
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

                    Component.onCompleted: catalog.requestPreview(cardWrap.id)
                    onIdChanged: catalog.requestPreview(cardWrap.id)
                    onPreviewFileChanged: if (previewFile === "") catalog.requestPreview(cardWrap.id)

                    Loader {
                        id: faceLoader
                        active: cardWrap.previewFile !== ""
                        sourceComponent: FontLoader { source: catalog.fileUrl(cardWrap.previewFile) }
                    }
                    readonly property bool faceReady: faceLoader.item !== null && faceLoader.item.status === FontLoader.Ready
                    readonly property bool selected: catalog.selectedId === cardWrap.id

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: Theme.s2
                        radius: Theme.rCard + 2
                        color: cardWrap.selected
                            ? Theme.withAlpha(Theme.accent, 0.08)
                            : cardHover.hovered ? Theme.panelRaised : Theme.panelBg
                        border.width: cardWrap.selected ? Theme.selectionRing : Theme.hairline
                        border.color: cardWrap.selected ? Theme.accent : cardHover.hovered ? Theme.borderStrong : Theme.border

                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.dFast } }

                        HoverHandler { id: cardHover }
                        TapHandler {
                            onTapped: catalog.selectFamily(cardWrap.id)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s5
                            anchors.rightMargin: Theme.s5
                            anchors.topMargin: Theme.s4
                            anchors.bottomMargin: Theme.s4
                            spacing: Theme.s3

                            // Header: Family name + Designer attribution + Source/VF badges
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.s2

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: cardWrap.family
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsSection
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: cardWrap.designersText !== ""
                                        text: qsTr("by %1").arg(cardWrap.designersText)
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                    }
                                }

                                // Variable pill
                                Rectangle {
                                    visible: cardWrap.variable
                                    implicitWidth: vfText.implicitWidth + Theme.s2 * 2
                                    implicitHeight: 20
                                    radius: Theme.rChip
                                    color: Theme.withAlpha(Theme.accent, 0.12)
                                    border.width: Theme.hairline
                                    border.color: Theme.withAlpha(Theme.accent, 0.45)
                                    Text {
                                        id: vfText
                                        anchors.centerIn: parent
                                        text: "VF"
                                        color: Theme.accent
                                        font.family: Theme.monoFamily
                                        font.pixelSize: Theme.fsCaption
                                        font.weight: Theme.wHeading
                                    }
                                }

                                // Source badge
                                Rectangle {
                                    implicitWidth: srcText.implicitWidth + Theme.s2 * 2
                                    implicitHeight: 20
                                    radius: Theme.rChip
                                    color: Theme.withAlpha(Theme.controlBg, 0.9)
                                    border.width: Theme.hairline
                                    border.color: Theme.border
                                    Text {
                                        id: srcText
                                        anchors.centerIn: parent
                                        text: cardWrap.source === "google" ? "Google" : cardWrap.sourceLabel
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsCaption
                                    }
                                }
                            }

                            // Hero specimen: generous whitespace around live type
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: catalog.sampleText === "" ? "The quick brown fox jumps over the lazy dog" : catalog.sampleText
                                    textFormat: Text.PlainText
                                    font.family: cardWrap.faceReady ? faceLoader.item.name : Theme.fontFamily
                                    font.pixelSize: root.previewSize
                                    color: Theme.specimenInk
                                    opacity: cardWrap.faceReady ? 1.0 : 0.22
                                    wrapMode: Text.Wrap
                                    maximumLineCount: root.layoutMode === "list" ? 2 : 3
                                    lineHeight: 1.22
                                    elide: Text.ElideRight
                                    Behavior on opacity { NumberAnimation { duration: 180 } }
                                }
                            }

                            // Footer: metadata + Shortlist + 1-click Install
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.s2

                                Label {
                                    Layout.fillWidth: true
                                    text: [
                                        Theme.plural(cardWrap.styleCount, qsTr("style"), qsTr("styles")),
                                        cardWrap.weightRange !== "" ? cardWrap.weightRange : "",
                                        cardWrap.category
                                    ].filter(s => s !== "").join("  ·  ")
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fsCaption
                                    elide: Text.ElideRight
                                }

                                ToolButton {
                                    icon.name: "bookmark"
                                    checked: cardWrap.shortlisted
                                    onClicked: catalog.toggleShortlist(cardWrap.id)
                                    ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay
                                    ToolTip.text: cardWrap.shortlisted ? qsTr("Remove from Shortlist") : qsTr("Add to Shortlist")
                                }

                                Button {
                                    objectName: "cardInstall_" + cardWrap.id
                                    implicitHeight: Theme.hControl
                                    highlighted: !cardWrap.installed && !cardWrap.installing
                                    enabled: !cardWrap.installing
                                    icon.name: cardWrap.installed ? "check" : "download"
                                    text: cardWrap.installing ? qsTr("Installing…")
                                        : cardWrap.installed ? qsTr("Installed")
                                        : qsTr("Install")
                                    onClicked: {
                                        if (cardWrap.installed) {
                                            catalog.selectFamily(cardWrap.id)
                                        } else {
                                            catalog.installFamily(cardWrap.id, true, [])
                                        }
                                    }
                                    ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay
                                    ToolTip.text: cardWrap.installed
                                        ? qsTr("Installed in ~/.local/share/fonts — click to manage weights")
                                        : qsTr("One-click install %1 to your system fonts").arg(cardWrap.family)
                                }
                            }
                        }
                    }
                }
            }

            // Empty / loading state
            Column {
                anchors.centerIn: parent
                visible: grid.count === 0
                spacing: Theme.s3
                width: Math.min(parent.width - Theme.s6 * 2, 420)
                BusyIndicator {
                    visible: catalog.loading
                    running: visible
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Icon {
                    visible: !catalog.loading
                    name: catalog.sourceFilter === "shortlist" ? "bookmark" : "globe"
                    size: Theme.szIconHero
                    color: Theme.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fsTitle
                    font.weight: Theme.wHeading
                    text: catalog.loading ? qsTr("Loading open-source type catalogs…")
                        : catalog.sourceFilter === "shortlist" ? qsTr("Your shortlist is empty")
                        : qsTr("No matching typefaces")
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.textMuted
                    text: catalog.loading ? qsTr("Fetching Google Fonts and curated indie foundries.")
                        : catalog.sourceFilter === "shortlist" ? qsTr("Bookmark candidates while browsing, compare them, then install the whole shortlist in one click.")
                        : qsTr("Try clearing a filter or broadening your search.")
                }
                Button {
                    visible: !catalog.loading && catalog.sourceFilter !== "shortlist"
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Reset filters")
                    onClicked: catalog.resetFilters()
                }
            }
        }

        // ── Suitcase-style Shortlist tray ───────────────────────────────────
        Rectangle {
            visible: catalog.shortlistCount > 0
            Layout.fillWidth: true
            implicitHeight: visible ? 50 : 0
            color: Theme.panelBg
            Rectangle { anchors.top: parent.top; width: parent.width; height: Theme.hairline; color: Theme.border }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s4
                anchors.rightMargin: Theme.s4
                spacing: Theme.s2

                Icon { name: "bookmark"; size: Theme.szIcon; color: Theme.accent }
                Label {
                    text: qsTr("Shortlist · %1").arg(catalog.shortlistCount)
                    color: Theme.textPrimary
                    font.weight: Theme.wHeading
                }

                // First few shortlisted names as clickable chips
                Repeater {
                    model: catalog.shortlistItems.slice(0, 5)
                    Button {
                        required property var modelData
                        flat: true
                        implicitHeight: 26
                        text: modelData.family + (modelData.installed ? " ✓" : "")
                        font.pixelSize: Theme.fsLabel
                        onClicked: catalog.selectFamily(modelData.id)
                    }
                }
                Label {
                    visible: catalog.shortlistCount > 5
                    text: qsTr("+%1 more").arg(catalog.shortlistCount - 5)
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsLabel
                }

                Item { Layout.fillWidth: true }

                Button {
                    flat: true
                    text: qsTr("View shortlist")
                    visible: catalog.sourceFilter !== "shortlist"
                    onClicked: catalog.sourceFilter = "shortlist"
                }
                Button {
                    flat: true
                    icon.name: "x"
                    text: qsTr("Clear")
                    onClicked: catalog.clearShortlist()
                }
                Button {
                    highlighted: true
                    icon.name: "download"
                    text: qsTr("Install Shortlist")
                    enabled: !catalog.installingAny
                    onClicked: catalog.installShortlist()
                }
            }
        }
    }
}
