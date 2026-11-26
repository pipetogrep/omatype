import QtQuick
import QtQuick.Layouts
import Omatype 1.0

// A text tab with an underline when active: the filter rows in Discover and
// Library share it.
Item {
    id: tab
    property string text: ""
    property bool active: false
    signal clicked()
    implicitWidth: tabLabel.implicitWidth + 10
    implicitHeight: 30

    HoverHandler { id: tabHover }
    TapHandler { onTapped: tab.clicked() }

    Text {
        id: tabLabel
        anchors.centerIn: parent
        text: tab.text
        color: tab.active ? Theme.textPrimary : tabHover.hovered ? Theme.textSecondary : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        font.weight: tab.active ? Font.Medium : Font.Normal
    }
    Rectangle {
        visible: tab.active
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: tabLabel.implicitWidth
        height: 2
        radius: 1
        color: Theme.textPrimary
    }
}
