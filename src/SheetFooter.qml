import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// The bottom row of a sheet that has its own actions: they sit to the left of
// Close, as text, with the same geometry as the standard button box.
Item {
    id: footer
    required property var sheet
    default property alias actions: actionRow.data

    implicitHeight: Theme.hControl + Theme.s2 + Theme.s4

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s4
        anchors.rightMargin: Theme.s4
        anchors.topMargin: Theme.s2
        anchors.bottomMargin: Theme.s4
        spacing: Theme.s2

        Item { Layout.fillWidth: true }
        RowLayout { id: actionRow; spacing: Theme.s2 }
        Button {
            text: qsTr("Close")
            implicitWidth: Math.max(Theme.s5 * 3 + Theme.s2, implicitContentWidth + leftPadding + rightPadding)
            onClicked: footer.sheet.close()
        }
    }
}
