import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// Asks before an install restarts the registered apps that are running.
// A restart can lose unsaved work, so it is off until ticked, and it is shown
// only when there is something to restart.
CheckBox {
    id: check
    readonly property var apps: backend.restartableApps
    visible: apps.length > 0
    Layout.fillWidth: true
    leftPadding: 0
    checked: backend.restartApps
    onToggled: backend.restartApps = checked
    text: qsTr("Restart %1 after installing").arg(names())
    font.pixelSize: Theme.fsLabel

    function names() {
        const n = apps.map(a => a.name)
        if (n.length <= 1) return n.join("")
        return qsTr("%1 and %2").arg(n.slice(0, -1).join(", ")).arg(n[n.length - 1])
    }

    // Which apps are running changes while Omatype is open; the views that
    // hold this call backend.refreshRunningApps() when what they show changes.
}
