import QtQuick
import QtQuick.Templates as T
import Omatype 1.0

T.MenuSeparator {
    id: control
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    topPadding: Theme.s1
    bottomPadding: Theme.s1
    leftPadding: 0
    rightPadding: 0
    contentItem: Item {
        implicitHeight: Theme.hairline
        Rectangle {
            x: -Theme.s1
            width: parent.width + Theme.s1 * 2
            height: Theme.hairline
            color: Theme.border
        }
    }
}
