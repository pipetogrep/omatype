import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// A strip of FilterTabs that never spills out of its space. It measures every
// tab, shows as many as fit in order, and puts the rest behind a "more" button
// whose menu lists them. The active tab is never the one folded away. In a
// RowLayout it shrinks before anything else does.
Item {
    id: strip
    // [{ key, label }]
    property var model: []
    property string current: ""
    property int spacing: Theme.s1 + 2
    signal activated(string key)

    readonly property int count: model ? model.length : 0
    readonly property int fullWidth: Math.ceil(measure.implicitWidth)

    implicitWidth: fullWidth
    implicitHeight: 30
    Layout.fillWidth: true
    Layout.preferredWidth: fullWidth
    Layout.maximumWidth: fullWidth
    // Never narrower than the more button plus the active tab it keeps.
    Layout.minimumWidth: more.implicitWidth + spacing + currentWidth
    readonly property real currentWidth: {
        for (let i = 0; i < measureRepeater.count; ++i)
            if (model[i].key === current) { const item = measureRepeater.itemAt(i); return item ? item.implicitWidth : 0 }
        return 0
    }

    // Which tabs are shown: as many as fit, front to back, leaving room for
    // the more button whenever any are left out. The active tab always keeps
    // its place, so the row still says what is selected.
    readonly property var shown: {
        const n = measureRepeater.count
        const out = []
        for (let i = 0; i < n; ++i) out.push(true)
        if (fullWidth <= width) return out
        let currentIndex = -1
        for (let i = 0; i < n; ++i) if (model[i].key === current) { currentIndex = i; break }
        const widthOf = (i) => { const item = measureRepeater.itemAt(i); return item ? item.implicitWidth : 0 }
        let available = width - more.implicitWidth - spacing
        if (currentIndex >= 0) available -= widthOf(currentIndex) + spacing
        let used = 0
        let full = false
        for (let i = 0; i < n; ++i) {
            if (i === currentIndex) continue
            const w = widthOf(i) + spacing
            if (full || used + w > available) { out[i] = false; full = true; continue }
            used += w
        }
        return out
    }
    readonly property int fitCount: shown.filter(v => v).length
    readonly property bool overflowing: fitCount < count

    // Invisible twin of the strip, at full width, for measuring.
    Row {
        id: measure
        visible: false
        spacing: strip.spacing
        Repeater {
            id: measureRepeater
            model: strip.model
            FilterTab { required property var modelData; text: modelData.label }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: strip.spacing
        Repeater {
            model: strip.model
            FilterTab {
                required property var modelData
                required property int index
                visible: strip.shown[index] ?? true
                text: modelData.label
                active: modelData.key === strip.current
                onClicked: strip.activated(modelData.key)
            }
        }
        ToolButton {
            id: more
            objectName: "overflowMore"
            anchors.verticalCenter: parent.verticalCenter
            visible: strip.overflowing
            icon.name: "ellipsis"
            onClicked: moreMenu.popup(more, 0, more.height)
            ToolTip.visible: hovered; ToolTip.delay: Theme.tooltipDelay
            ToolTip.text: qsTr("More")
            Menu {
                id: moreMenu
                height: Math.min(implicitHeight, 420)
                Repeater {
                    model: strip.model
                    MenuItem {
                        required property var modelData
                        required property int index
                        visible: !(strip.shown[index] ?? true)
                        height: visible ? implicitHeight : 0
                        text: modelData.label
                        checkable: true
                        checked: modelData.key === strip.current
                        onTriggered: strip.activated(modelData.key)
                    }
                }
            }
        }
    }
}
