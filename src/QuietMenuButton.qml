import QtQuick
import QtQuick.Layouts
import Omatype 1.0

// Text with a small chevron that opens a menu, with no button chrome.
Item {
    id: qmb
    property string text: ""
    signal clicked()
    implicitWidth: qmbRow.implicitWidth + Theme.s2
    implicitHeight: 28

    HoverHandler { id: qmbHover }
    TapHandler { onTapped: qmb.clicked() }

    RowLayout {
        id: qmbRow
        anchors.centerIn: parent
        spacing: 4
        Text {
            text: qmb.text
            color: qmbHover.hovered ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsLabel
        }
        Icon {
            name: "chevron-down"
            size: 12
            color: qmbHover.hovered ? Theme.textPrimary : Theme.textMuted
        }
    }
}
