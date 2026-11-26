import QtQuick
import QtQuick.Templates as T
import Omatype 1.0

T.MenuItem {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding,
                             implicitIndicatorHeight + topPadding + bottomPadding)

    padding: Theme.s1
    leftPadding: Theme.s2 + 2
    rightPadding: Theme.s2 + 2
    spacing: Theme.s2
    hoverEnabled: true
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fsControl
    // Icons follow the sidebar, the source of truth: 14 px, muted, 0.65.
    icon.width: 14
    icon.height: 14
    opacity: enabled ? 1 : Theme.disabledOpacity

    // Room at the left for an icon or check mark, so labels line up down the
    // menu: the sidebar's 14 px icon and 10 px gap.
    readonly property real lead: 14 + Theme.s2 + 2

    contentItem: Item {
        implicitWidth: control.lead + label.implicitWidth + (control.subMenu ? 14 + control.spacing : 0)
        implicitHeight: label.implicitHeight
        Icon {
            visible: control.icon.name !== "" && !control.checkable
            name: control.icon.name
            size: control.icon.width
            color: Theme.textMuted
            opacity: 0.65
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: label
            x: control.lead
            width: parent.width - x - (control.subMenu ? 14 + control.spacing : 0)
            text: control.text
            textFormat: Text.PlainText
            font: control.font
            color: control.highlighted ? Theme.textPrimary : Theme.textSecondary
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    indicator: Icon {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        visible: control.checkable && control.checked
        name: "check"
        size: 14
        color: Theme.accent
    }

    arrow: Icon {
        x: control.width - width - control.rightPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        visible: control.subMenu
        name: "chevron-right"
        size: 14
        color: Theme.textMuted
    }

    background: Rectangle {
        implicitWidth: Theme.wInspector - Theme.s5 * 2
        implicitHeight: Theme.hRow
        radius: Theme.rControl
        color: control.down ? Theme.pressedOn(Theme.controlHover)
             : control.highlighted ? Theme.controlHover : "transparent"
    }
}
