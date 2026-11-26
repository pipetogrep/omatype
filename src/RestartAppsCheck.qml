import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// Asks before an install restarts the registered apps that are running.
// A restart can lose unsaved work, so it is off until ticked. Which apps it
// covers is set in the Applications sheet, which the link opens.
RowLayout {
    id: row
    signal manageApps()
    visible: backend.registeredAppCount > 0
    Layout.fillWidth: true
    spacing: 0

    CheckBox {
        Layout.alignment: Qt.AlignBaseline
        leftPadding: 0
        rightPadding: 0
        checked: backend.restartApps
        onToggled: backend.restartApps = checked
        text: qsTr("Restart") + " "
        font.pixelSize: Theme.fsLabel
    }
    Text {
        Layout.alignment: Qt.AlignBaseline
        text: qsTr("select applications")
        color: link.hovered ? Theme.textPrimary : Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        font.underline: true
        HoverHandler { id: link; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: row.manageApps() }
    }
    Item { Layout.fillWidth: true }
}
