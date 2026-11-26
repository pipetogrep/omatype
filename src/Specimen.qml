import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omatype 1.0

// The type specimen: the name at display size, a full-width editable sample
// bar, the sample at five sizes flush left with the size numerals in a
// right-aligned column, and the character set, divided by full-width hairlines.
// It sits on the same surface as the toolbar and status bar around it. It
// renders from the font FILE, never from an installed family name, so a
// staged-but-uninstalled font and a just-installed one both preview correctly:
// Qt only snapshots families at start-up.
Rectangle {
    id: specimen
    color: Theme.windowBg

    readonly property string file: backend.previewFile
    Loader {
        id: loader
        active: specimen.file !== ""
        sourceComponent: FontLoader { source: backend.fileUrl(specimen.file) }
    }
    readonly property bool ready: loader.item !== null && loader.item.status === FontLoader.Ready
    readonly property string family: ready ? loader.item.name : ""
    readonly property bool failed: loader.item !== null && loader.item.status === FontLoader.Error

    component FullRule: Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.hairline
        color: Theme.border
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + Theme.s6
        clip: true
        visible: specimen.ready
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: column
            width: flick.width
            spacing: 0

            // ── Display header ──────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.s6
                Layout.rightMargin: Theme.s6
                Layout.topMargin: Theme.s6
                Layout.bottomMargin: Theme.s5
                spacing: Theme.s3

                Text {
                    Layout.fillWidth: true
                    text: backend.previewTitle
                    textFormat: Text.PlainText
                    font.family: specimen.family
                    font.pixelSize: Math.round(Theme.fsSpecimenName * backend.specimenScale)
                    color: Theme.specimenInk
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                RowLayout {
                    spacing: Theme.s2
                    Label {
                        visible: !backend.staged && (backend.selectedInfo.designer ?? "") !== ""
                        text: qsTr("by %1").arg(backend.selectedInfo.designer ?? "")
                        color: Theme.textSecondary
                        font.weight: Theme.wHeading
                    }
                    Label {
                        visible: !backend.staged && (backend.selectedInfo.designer ?? "") !== ""
                        text: "·"
                        color: Theme.textMuted
                    }
                    Label {
                        text: backend.staged
                            ? qsTr("%1 staged from %2").arg(Theme.plural(backend.stagedSelected.length, qsTr("face"), qsTr("faces"))).arg(backend.stagedSource)
                            : Theme.plural((backend.selected.styles ?? []).length, qsTr("style"), qsTr("styles"))
                        color: Theme.textMuted
                    }
                    Label { visible: specimen.family !== "" && specimen.family !== backend.previewTitle; text: "·  " + specimen.family; color: Theme.textMuted }
                }
            }

            // ── Full-width editable sample input ────────────────────────────
            FullRule {}
            TextField {
                id: sampleField
                objectName: "sampleField"
                Layout.fillWidth: true
                implicitHeight: 42
                leftPadding: Theme.s6
                rightPadding: Theme.s6
                text: backend.sample
                placeholderText: qsTr("Type a sample…")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsControl
                onEditingFinished: backend.sample = text
                onTextEdited: backend.sample = text
                Keys.onEscapePressed: { focus = false; specimen.forceActiveFocus() }
                background: Rectangle {
                    radius: 0
                    color: sampleField.activeFocus ? Theme.panelBg
                         : sampleField.hovered ? Theme.withAlpha(Theme.panelBg, 0.5) : "transparent"
                }
            }
            FullRule {}

            // ── Five sizes, flush left with right-aligned size numerals ─────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.s6
                Layout.rightMargin: Theme.s6
                Layout.topMargin: Theme.s5
                Layout.bottomMargin: Theme.s5
                spacing: Theme.s4

                Repeater {
                    model: Theme.specimenSizes
                    RowLayout {
                        required property int modelData
                        Layout.fillWidth: true
                        spacing: Theme.s4

                        Text {
                            Layout.fillWidth: true
                            text: backend.sample === "" ? backend.defaultSample : backend.sample
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            font.family: specimen.family
                            font.pixelSize: Math.round(modelData * backend.specimenScale)
                            color: Theme.specimenInk
                        }
                        Label {
                            Layout.preferredWidth: Theme.wSpecimenGutter
                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                            text: Math.round(modelData * backend.specimenScale)
                            color: Theme.textMuted
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fsCaption
                            horizontalAlignment: Text.AlignRight
                            topPadding: Theme.s1
                        }
                    }
                }
            }

            FullRule {}

            // ── Character set ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.s6
                Layout.rightMargin: Theme.s6
                Layout.topMargin: Theme.s5
                Layout.bottomMargin: Theme.s5
                spacing: Theme.s4

                Text {
                    Layout.fillWidth: true
                    text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n0123456789\n!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~\n£€¥©®™ àáâäåæçèéêëìíîïñòóôöøùúûüß"
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    lineHeight: 1.35
                    font.family: specimen.family
                    font.pixelSize: Math.round(Theme.fsSpecimenCharset * backend.specimenScale)
                    color: Theme.specimenInk
                }
                Label {
                    Layout.preferredWidth: Theme.wSpecimenGutter
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    text: "Aa"
                    color: Theme.textMuted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fsCaption
                    horizontalAlignment: Text.AlignRight
                    topPadding: Theme.s1
                }
            }
        }
    }

    // Empty states: nothing chosen, still loading, or a file Qt could not read.
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.s6 * 2, 420)
        spacing: Theme.s2
        visible: !specimen.ready
        Icon {
            name: specimen.failed ? "circle-alert" : backend.staging ? "package" : "type"
            size: Theme.szIconHero
            color: specimen.failed ? Theme.warning : Theme.textMuted
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.textPrimary
            font.pixelSize: Theme.fsTitle
            font.weight: Theme.wHeading
            text: specimen.failed ? qsTr("This file would not load")
                : backend.staging ? qsTr("Reading %1…").arg(backend.stagedSource)
                : backend.scanning ? qsTr("Reading your fonts…")
                : qsTr("Choose a family, or drop fonts here")
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.textMuted
            text: specimen.failed ? qsTr("fontconfig knows it, but Qt could not render it. It may be a bitmap or Type 1 font.")
                : backend.staging || backend.scanning ? ""
                : qsTr("A file, a folder or a zip. Everything installable inside is staged and previewed before anything is written.")
        }
    }
}
