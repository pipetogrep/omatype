import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// Unified left sidebar: Discover catalogs on top, Library sections below.
// When browsing Library, the active section expands inline to show its matching
// families nested underneath—no separate second left column needed.
Rectangle {
    id: sidebar
    color: Theme.panelBg

    property string mode: "discover"
    property bool sourceExpanded: true
    property var activeFamilyList: null

    signal discoverSelected(string sourceFilter)
    signal librarySelected()
    signal newCollectionRequested()
    signal newSmartRequested()
    signal editSmartRequested(string id)
    signal renameRequested(string id, string name)
    signal renameTagRequested(string tag)
    // Deleting library data cannot be undone, so Main asks first.
    signal deleteRequested(string id, string name, bool smart)
    signal deleteTagRequested(string tag)

    function focusFamilyList() {
        if (activeFamilyList) activeFamilyList.forceActiveFocus()
    }

    Connections {
        target: backend
        function onSourceChanged() {
            sidebar.sourceExpanded = true
        }
    }

    component NestedFamilyList: Item {
        id: nested
        Layout.fillWidth: true
        readonly property int maxHeight: Math.max(240, Math.round(sidebar.height * 0.56))
        implicitHeight: Math.min(Math.max(list.contentHeight, list.count === 0 ? 52 : 0), maxHeight) + Theme.s1

        Component.onCompleted: sidebar.activeFamilyList = list
        Component.onDestruction: {
            if (sidebar.activeFamilyList === list) sidebar.activeFamilyList = null
        }

        ListView {
            id: list
            objectName: "familyList"
            activeFocusOnTab: true
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: Theme.s1
            clip: true
            model: backend.families
            currentIndex: backend.families.indexOf(backend.selectedName)
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Theme.dFast
            keyNavigationEnabled: false
            keyNavigationWraps: false
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            cacheBuffer: 30 * 18

            function step(delta) {
                const i = Math.max(0, Math.min(count - 1, (currentIndex < 0 ? 0 : currentIndex) + delta))
                const name = backend.families.nameAt(i)
                if (name === "") return
                if (backend.staged || backend.staging) backend.clearStage()
                if (backend.view === "compare") backend.view = "specimen"
                backend.selectedName = name
            }
            Keys.onUpPressed: step(-1)
            Keys.onDownPressed: step(1)
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Home) { step(-count); event.accepted = true }
                else if (event.key === Qt.Key_End) { step(count); event.accepted = true }
                else if (event.key === Qt.Key_PageDown) { step(12); event.accepted = true }
                else if (event.key === Qt.Key_PageUp) { step(-12); event.accepted = true }
            }
            Connections {
                target: backend
                function onSelectionChanged() {
                    const i = backend.families.indexOf(backend.selectedName)
                    if (i >= 0) list.positionViewAtIndex(i, ListView.Contain)
                }
            }

            delegate: ItemDelegate {
                id: frow
                required property int index
                required property string name
                required property bool user
                required property bool mono
                required property bool latin
                required property bool coverage
                required property bool inactive
                required property bool duplicate
                required property bool starred
                required property var members
                required property string previewFile
                required property var styles
                width: ListView.view.width
                height: 30
                highlighted: name === backend.selectedName && !backend.staged && backend.view !== "compare"
                leftPadding: 40
                rightPadding: Theme.s3
                onClicked: {
                    if (backend.staged || backend.staging) backend.clearStage()
                    if (backend.view === "compare") backend.view = "specimen"
                    backend.selectedName = name
                    list.forceActiveFocus()
                }
                Accessible.name: name

                Loader {
                    id: face
                    active: frow.latin && frow.previewFile !== ""
                    sourceComponent: FontLoader { source: backend.fileUrl(frow.previewFile) }
                }
                readonly property bool faceReady: face.item !== null && face.item.status === FontLoader.Ready
                readonly property real markOpacity: highlighted || hovered ? 0.85 : 0.45

                contentItem: RowLayout {
                    spacing: Theme.s1 + 2
                    Text {
                        Layout.fillWidth: true
                        text: frow.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        color: frow.inactive ? Theme.textMuted : frow.highlighted ? Theme.textPrimary : Theme.textSecondary
                        font.family: frow.faceReady ? face.item.name : Theme.fontFamily
                        font.pixelSize: frow.faceReady ? 14 : Theme.fsControl
                        font.strikeout: frow.inactive
                    }
                    // Status marks share the nav's quiet icon treatment: one size,
                    // muted, brighter on the hovered or selected row.
                    Icon { visible: frow.starred; name: "star"; size: 11; color: Theme.textMuted; opacity: frow.markOpacity }
                    Label {
                        visible: frow.members.length > 0 && !frow.mono && !frow.coverage
                        text: frow.styles.length
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.monoFamily
                        ToolTip.visible: membersHover.hovered
                        ToolTip.delay: Theme.tooltipDelay
                        ToolTip.text: qsTr("Includes %1").arg(frow.members.join(", "))
                        HoverHandler { id: membersHover }
                    }
                    Icon { visible: frow.inactive; name: "eye-off"; size: 11; color: Theme.textMuted; opacity: frow.markOpacity }
                    Icon {
                        visible: frow.duplicate && !frow.inactive
                        name: "copy"
                        size: 11
                        color: Theme.textMuted
                        opacity: frow.markOpacity
                        ToolTip.visible: dupHover.hovered
                        ToolTip.delay: Theme.tooltipDelay
                        ToolTip.text: qsTr("Duplicate font files")
                        HoverHandler { id: dupHover }
                    }
                    Icon {
                        visible: frow.mono
                        name: "monospace"
                        size: 11
                        color: Theme.textMuted
                        opacity: frow.markOpacity
                        ToolTip.visible: monoHover.hovered
                        ToolTip.delay: Theme.tooltipDelay
                        ToolTip.text: qsTr("Monospace")
                        HoverHandler { id: monoHover }
                    }
                }
                background: Rectangle {
                    x: 32
                    width: parent.width - 32 - Theme.s2
                    height: parent.height
                    radius: Theme.rControl
                    color: frow.down ? Theme.pressedOn(Theme.controlHover)
                         : frow.highlighted ? Theme.withAlpha(Theme.accent, 0.12)
                         : frow.hovered ? Theme.controlHover : "transparent"
                }
            }

            Item {
                anchors.fill: parent
                visible: list.count === 0
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 40
                    anchors.rightMargin: Theme.s3
                    wrapMode: Text.Wrap
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsLabel
                    text: backend.scanning ? qsTr("Reading the font list…")
                        : backend.filter !== "" ? qsTr("Nothing matches “%1”").arg(backend.filter)
                        : qsTr("No fonts found")
                }
            }
        }
    }

    component DiscoverRow: ItemDelegate {
        id: drow
        property string sourceFilter: "all"
        property string label: ""
        property string iconName: ""
        property int count: -1
        Layout.fillWidth: true
        Layout.leftMargin: Theme.s2
        Layout.rightMargin: Theme.s2
        width: ListView.view ? ListView.view.width : parent.width
        height: Theme.hRow
        highlighted: sidebar.mode === "discover" && catalog.sourceFilter === sourceFilter
        leftPadding: Theme.s2
        rightPadding: Theme.s2
        onClicked: sidebar.discoverSelected(sourceFilter)
        Accessible.name: label
        contentItem: RowLayout {
            spacing: Theme.s2 + 2
            Icon {
                name: drow.iconName
                size: 14
                color: drow.highlighted ? Theme.accent : Theme.textMuted
                opacity: drow.highlighted ? 0.9 : 0.65
                visible: drow.iconName !== ""
            }
            Text {
                Layout.fillWidth: true
                text: drow.label
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: drow.highlighted ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsControl
                font.weight: drow.highlighted ? Font.Medium : Font.Normal
            }
            Label {
                visible: drow.count > 0
                text: drow.count
                color: Theme.textMuted
                font.pixelSize: Theme.fsCaption
                font.family: Theme.monoFamily
            }
        }
        background: Rectangle {
            radius: Theme.rControl
            color: drow.down ? Theme.pressedOn(Theme.controlHover)
                 : drow.highlighted ? Theme.withAlpha(Theme.accent, 0.10)
                 : drow.hovered ? Theme.controlHover : "transparent"
        }
    }

    component SourceRow: ColumnLayout {
        id: srow
        property string source: ""
        property string label: ""
        property string iconName: ""
        property int count: -1
        property bool editable: false
        readonly property bool isActive: sidebar.mode === "library" && backend.source === source
        readonly property bool isExpanded: isActive && sidebar.sourceExpanded
        // Every source opens into its family list; an empty one has nothing to show.
        readonly property bool expandable: count !== 0
        signal doubleClicked()
        signal rightClicked()

        Layout.fillWidth: true
        spacing: 0

        ItemDelegate {
            id: row
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            Layout.rightMargin: Theme.s2
            height: Theme.hRow
            highlighted: srow.isActive
            leftPadding: Theme.s2
            rightPadding: Theme.s2
            onClicked: {
                if (backend.view === "compare") backend.view = "specimen"
                if (srow.isActive) {
                    sidebar.sourceExpanded = !sidebar.sourceExpanded
                } else {
                    sidebar.librarySelected()
                    backend.source = srow.source
                    sidebar.sourceExpanded = true
                }
            }
            onDoubleClicked: srow.doubleClicked()
            Accessible.name: srow.label

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: srow.rightClicked()
            }

            contentItem: RowLayout {
                spacing: Theme.s2 + 2
                // Open: a down chevron. Hovered and closed: a right chevron in
                // place of the icon, so the row says it can be expanded.
                Icon {
                    readonly property bool showChevron: srow.isExpanded || (row.hovered && srow.expandable)
                    name: srow.isExpanded ? "chevron-down"
                        : showChevron ? "chevron-right" : srow.iconName
                    size: 14
                    color: row.highlighted || showChevron ? (row.highlighted ? Theme.accent : Theme.textSecondary) : Theme.textMuted
                    opacity: row.highlighted ? 0.9 : showChevron ? 0.85 : 0.65
                    visible: showChevron || srow.iconName !== ""
                }
                Text {
                    Layout.fillWidth: true
                    text: srow.label
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    color: row.highlighted ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsControl
                    font.weight: row.highlighted ? Font.Medium : Font.Normal
                }
                Label {
                    readonly property int shownCount: srow.isActive && backend.filter !== "" ? backend.visibleCount : srow.count
                    visible: shownCount > 0 || (srow.isActive && backend.filter !== "")
                    text: shownCount
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsCaption
                    font.family: Theme.monoFamily
                }
            }
            background: Rectangle {
                radius: Theme.rControl
                color: row.down ? Theme.pressedOn(Theme.controlHover)
                     : row.highlighted ? Theme.withAlpha(Theme.accent, 0.10)
                     : row.hovered ? Theme.controlHover : "transparent"
            }
        }

        Loader {
            active: srow.isExpanded
            visible: active
            Layout.fillWidth: true
            Layout.preferredHeight: item ? item.implicitHeight : 0
            sourceComponent: Component {
                NestedFamilyList {}
            }
        }
    }

    component Heading: RowLayout {
        property string text: ""
        property string action: ""
        signal actionClicked()
        Layout.fillWidth: true
        Layout.leftMargin: Theme.s4
        Layout.rightMargin: Theme.s2
        Layout.topMargin: Theme.s4
        Layout.bottomMargin: 6
        spacing: Theme.s2
        Label {
            text: parent.text
            color: Theme.textMuted
            font.pixelSize: Theme.fsLabel
            font.weight: Font.Medium
        }
        Item { Layout.fillWidth: true }
        ToolButton {
            visible: parent.action !== ""
            icon.name: "plus"
            onClicked: parent.actionClicked()
            ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay; ToolTip.text: parent.action
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + Theme.s4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 0

            // Centred on the toolbar's height, so "Discover" sits level with
            // the sidebar toggle beside it.
            Heading { text: qsTr("Discover"); Layout.topMargin: Math.round((Theme.hToolbar - implicitHeight) / 2) }
            DiscoverRow { sourceFilter: "all"; label: qsTr("Browse Catalog"); iconName: "globe"; count: catalog.totalCount }
            DiscoverRow { sourceFilter: "google"; label: qsTr("Google Fonts"); iconName: "type"; count: catalog.googleCount }
            DiscoverRow { sourceFilter: "indie"; label: qsTr("Indie Foundries"); iconName: "pen-tool"; count: catalog.indieCount }
            DiscoverRow { sourceFilter: "shortlist"; label: qsTr("Shortlist"); iconName: "bookmark"; count: catalog.shortlistCount; visible: catalog.shortlistCount > 0 || (sidebar.mode === "discover" && catalog.sourceFilter === "shortlist") }
            DiscoverRow { sourceFilter: "installed"; label: qsTr("Installed"); iconName: "check"; count: catalog.installedCatalogCount; visible: catalog.installedCatalogCount > 0 || (sidebar.mode === "discover" && catalog.sourceFilter === "installed") }

            Heading { text: qsTr("Library") }
            SourceRow { source: "all"; label: qsTr("All Fonts"); iconName: "type"; count: backend.totalCount }
            SourceRow { source: "yours"; label: qsTr("Yours"); iconName: "download"; count: backend.userCount }
            SourceRow { source: "system"; label: qsTr("System"); iconName: "package"; count: backend.systemCount }
            SourceRow { source: "starred"; label: qsTr("Starred"); iconName: "star"; count: backend.starredCount; visible: backend.starredCount > 0 || backend.source === "starred" }
            SourceRow { source: "mono"; label: qsTr("Monospace"); iconName: "monospace"; count: backend.monoCount }
            SourceRow { source: "recent"; label: qsTr("Recently Added"); iconName: "clock"; count: backend.recentCount }
            SourceRow { source: "inactive"; label: qsTr("Deactivated"); iconName: "eye-off"; count: backend.inactiveCount; visible: backend.inactiveCount > 0 || backend.source === "inactive" }
            SourceRow { source: "duplicates"; label: qsTr("Duplicates"); iconName: "copy"; count: backend.duplicateCount; visible: backend.duplicateCount > 0 || backend.source === "duplicates" }

            ColumnLayout {
                visible: sidebar.mode === "library"
                Layout.fillWidth: true
                spacing: 0

                Heading { visible: backend.tagFacets.length > 0; text: qsTr("Tags") }
                Flow {
                    visible: backend.tagFacets.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.s4
                    Layout.rightMargin: Theme.s3
                    spacing: Theme.s1
                    Repeater {
                        model: backend.tagFacets
                        Button {
                            required property var modelData
                            text: "#" + modelData.name + "  " + modelData.count
                            flat: backend.source !== modelData.key
                            checked: backend.source === modelData.key
                            font.pixelSize: Theme.fsLabel
                            onClicked: backend.source = backend.source === modelData.key ? "all" : modelData.key
                            TapHandler { acceptedButtons: Qt.RightButton; onTapped: tagMenu.openFor(modelData.name) }
                        }
                    }
                }
                Loader {
                    active: sidebar.mode === "library" && sidebar.sourceExpanded && backend.source.indexOf("tag:") === 0
                    visible: active
                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    sourceComponent: Component { NestedFamilyList {} }
                }

                Heading { text: qsTr("Collections"); action: qsTr("New collection"); onActionClicked: sidebar.newCollectionRequested() }
                Repeater {
                    model: backend.collections
                    SourceRow {
                        required property var modelData
                        source: "coll:" + modelData.id
                        label: modelData.name
                        iconName: "folder-open"
                        count: modelData.count
                        editable: true
                        onRightClicked: collectionMenu.openFor(modelData.id, modelData.name, false)
                    }
                }

                Heading { text: qsTr("Smart Collections"); action: qsTr("New smart collection"); onActionClicked: sidebar.newSmartRequested() }
                Repeater {
                    model: backend.smartCollections
                    SourceRow {
                        required property var modelData
                        source: "smart:" + modelData.id
                        label: modelData.name
                        iconName: "search"
                        count: modelData.count
                        onDoubleClicked: sidebar.editSmartRequested(modelData.id)
                        onRightClicked: collectionMenu.openFor(modelData.id, modelData.name, true)
                    }
                }
            }
        }
    }

    Menu {
        id: tagMenu
        property string tag: ""
        function openFor(t) { tag = t; popup() }
        MenuItem { text: qsTr("Rename tag"); onTriggered: sidebar.renameTagRequested(tagMenu.tag) }
        MenuItem { text: qsTr("Remove tag from every family"); onTriggered: sidebar.deleteTagRequested(tagMenu.tag) }
    }
    Menu {
        id: collectionMenu
        property string targetId: ""
        property string targetName: ""
        property bool smart: false
        function openFor(id, name, isSmart) { targetId = id; targetName = name; smart = isSmart; popup() }
        MenuItem { text: qsTr("Edit rules"); visible: collectionMenu.smart; height: visible ? implicitHeight : 0; onTriggered: sidebar.editSmartRequested(collectionMenu.targetId) }
        MenuItem { text: qsTr("Activate everything in it"); icon.name: "eye"; visible: !collectionMenu.smart; height: visible ? implicitHeight : 0; onTriggered: backend.activateCollection(collectionMenu.targetId) }
        MenuItem { text: qsTr("Deactivate everything in it"); icon.name: "eye-off"; visible: !collectionMenu.smart; height: visible ? implicitHeight : 0; onTriggered: backend.deactivateCollection(collectionMenu.targetId) }
        MenuItem { text: qsTr("Export"); icon.name: "folder-output"; visible: !collectionMenu.smart; height: visible ? implicitHeight : 0; onTriggered: backend.exportCollection(collectionMenu.targetId) }
        MenuItem { text: qsTr("Rename"); onTriggered: sidebar.renameRequested(collectionMenu.targetId, collectionMenu.targetName) }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Delete")
            icon.name: "trash-2"
            onTriggered: sidebar.deleteRequested(collectionMenu.targetId, collectionMenu.targetName, collectionMenu.smart)
        }
    }
}
