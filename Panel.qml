import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "pipetogrep.omatype"
  ipcTarget: "pipetogrep.omatype"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Commons.Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Commons.Color.accent) : "transparent"

  property bool discoverMode: Boolean(setting("openDiscoverByDefault", true))
  property string query: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property bool initialized: false

  readonly property var filteredInstalled: {
    var list = service.installedFonts || []
    var q = query.trim().toLowerCase()
    if (q === "") return list
    var out = []
    for (var i = 0; i < list.length; i++) {
      var f = list[i]
      var hay = (
        String(f.name || "") + " " +
        String(f.foundry || "") + " " +
        (f.monospace ? "monospace mono " : "") +
        (f.variable ? "variable " : "") +
        (f.yours ? "yours user" : "system")
      ).toLowerCase()
      if (hay.indexOf(q) !== -1) out.push(f)
    }
    return out
  }

  readonly property var activeItems: discoverMode ? (service.discoverFonts || []) : filteredInstalled

  function clampSelection() {
    if (activeItems.length === 0) {
      selectedIndex = 0
      return
    }
    if (selectedIndex < 0) selectedIndex = 0
    if (selectedIndex >= activeItems.length) selectedIndex = activeItems.length - 1
  }

  function selectedItem() {
    if (activeItems.length === 0) return null
    var idx = Math.max(0, Math.min(selectedIndex, activeItems.length - 1))
    return activeItems[idx]
  }

  function moveSelection(delta) {
    if (activeItems.length === 0) return
    cursorActive = true
    selectedIndex = Math.max(0, Math.min(activeItems.length - 1, selectedIndex + delta))
    var listView = panel.loadedContent ? panel.loadedContent.fontList : null
    if (listView) listView.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function activateSelected() {
    if (service.binaryMissing) return
    var item = selectedItem()
    if (!item) {
      launchFullApp()
      return
    }
    if (discoverMode) {
      if (!item.installed) service.installFamily(item.family)
    } else {
      launchFullApp()
    }
  }

  function launchFullApp() {
    service.launchApp()
    root.close()
  }

  function refreshActive() {
    service.lastNotice = ""
    if (discoverMode) {
      service.searchCatalog(query)
    } else {
      service.refreshInstalled()
    }
  }

  onActiveItemsChanged: clampSelection()
  onDiscoverModeChanged: {
    selectedIndex = 0
    cursorActive = false
    if (opened) {
      if (discoverMode) service.searchCatalog(query)
      else service.refreshInstalled()
    }
  }

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      selectedIndex = 0
      service.lastNotice = ""
      if (!initialized) {
        initialized = true
        discoverMode = Boolean(setting("openDiscoverByDefault", true))
      }
      service.refreshInstalled()
      if (discoverMode) service.searchCatalog(query)
    } else {
      query = ""
    }
  }

  Timer {
    id: searchDebounce
    interval: 260
    repeat: false
    onTriggered: {
      if (root.opened && root.discoverMode) {
        service.searchCatalog(root.query)
      }
    }
  }

  Service {
    id: service
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    active: root.opened
    readonly property color iconTint: active && useActiveColor ? activeColor : root.barForeground
    fixedWidth: vertical ? -1 : Style.bar.iconSlot
    fixedHeight: vertical ? Style.bar.iconSlot : -1
    tooltipText: service.userFontCount > 0
      ? "Omatype (" + Commons.I18n.formatNumber(service.userFontCount) + " installed)"
      : "Omatype — Fonts"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.launchFullApp()
      else root.toggle()
    }

    PlainText {
      anchors.centerIn: parent
      scale: button.pressScale
      text: "Aa"
      color: button.iconTint
      font.family: button.fontFamily
      font.pixelSize: Math.max(11, Math.round(Style.bar.iconSize * 0.82))
      font.weight: Font.DemiBold
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(520))

    content: PanelKeyCatcher {
      id: keyCatcher
      property alias fontList: fontList
      implicitHeight: contentColumn.implicitHeight
      anchors.fill: parent
      blocked: searchInput.activeFocus

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveSelection(dy)
      }
      onActivateRequested: root.activateSelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refreshActive()
        else if (t === "o" || t === "O") root.launchFullApp()
        else if (t === "d" || t === "D") root.discoverMode = true
        else if (t === "i" || t === "I") root.discoverMode = false
        else if (t === "/") searchInput.forceActiveFocus()
      }

      ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: Style.space(10)

        // Header: title, Discover / Installed toggle, and Open App button.
        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(8)
          Layout.rightMargin: Style.space(4)
          spacing: Style.space(8)

          PlainText {
            Layout.alignment: Qt.AlignVCenter
            text: "Omatype"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
          }

          Item { Layout.fillWidth: true }

          Rectangle {
            Layout.alignment: Qt.AlignVCenter
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
            radius: Math.min(4, Style.cornerRadius)
            implicitWidth: tabRow.implicitWidth + Style.space(4)
            implicitHeight: tabRow.implicitHeight + Style.space(4)

            Row {
              id: tabRow
              anchors.centerIn: parent
              spacing: Style.space(2)

              Rectangle {
                radius: Math.min(3, Style.cornerRadius)
                color: root.discoverMode
                  ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                  : "transparent"
                implicitWidth: discoverTabLabel.implicitWidth + Style.space(12)
                implicitHeight: discoverTabLabel.implicitHeight + Style.space(6)

                PlainText {
                  id: discoverTabLabel
                  anchors.centerIn: parent
                  text: "Discover"
                  color: root.discoverMode ? root.accent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.weight: root.discoverMode ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.discoverMode = true
                }
              }

              Rectangle {
                radius: Math.min(3, Style.cornerRadius)
                color: !root.discoverMode
                  ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                  : "transparent"
                implicitWidth: installedTabLabel.implicitWidth + Style.space(12)
                implicitHeight: installedTabLabel.implicitHeight + Style.space(6)

                PlainText {
                  id: installedTabLabel
                  anchors.centerIn: parent
                  text: "Installed"
                  color: !root.discoverMode ? root.accent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.weight: !root.discoverMode ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.discoverMode = false
                }
              }
            }
          }

          Rectangle {
            id: launchBtn
            Layout.alignment: Qt.AlignVCenter
            radius: Math.min(4, Style.cornerRadius)
            color: launchMouse.containsMouse
              ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24)
              : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
            implicitWidth: launchLabel.implicitWidth + Style.space(12)
            implicitHeight: launchLabel.implicitHeight + Style.space(6)

            PlainText {
              id: launchLabel
              anchors.centerIn: parent
              text: "Open ↗"
              color: launchMouse.containsMouse ? root.accent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
            }

            MouseArea {
              id: launchMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launchFullApp()
            }
          }
        }

        // Search input.
        Rectangle {
          visible: !service.binaryMissing
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(8)
          Layout.rightMargin: Style.space(8)
          implicitHeight: Style.space(32)
          radius: Math.min(4, Style.cornerRadius)
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
          border.width: searchInput.activeFocus ? 1 : 0
          border.color: root.accent

          TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            verticalAlignment: Text.AlignVCenter
            color: root.foreground
            selectionColor: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            clip: true
            text: root.query
            onTextEdited: {
              root.query = text
              if (root.discoverMode) searchDebounce.restart()
            }
            Keys.onEscapePressed: {
              if (root.query !== "") {
                root.query = ""
                if (root.discoverMode) service.searchCatalog("")
              }
              keyCatcher.forceActiveFocus()
            }
            Keys.onReturnPressed: {
              if (root.discoverMode) {
                searchDebounce.stop()
                service.searchCatalog(root.query)
              }
              keyCatcher.forceActiveFocus()
            }
          }

          PlainText {
            visible: searchInput.text === ""
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: root.discoverMode
              ? "Search Google Fonts & indie foundries…"
              : "Filter installed fonts…"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        // Status / feedback banner.
        PlainText {
          visible: service.lastError !== "" || service.lastNotice !== ""
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(10)
          Layout.rightMargin: Style.space(10)
          text: service.lastError !== "" ? service.lastError : service.lastNotice
          color: service.lastError !== "" ? (root.bar ? root.bar.urgent : Commons.Color.urgent) : root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // Setup guidance if the native omatype binary is not installed yet.
        ColumnLayout {
          visible: service.binaryMissing
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(10)
          Layout.rightMargin: Style.space(10)
          Layout.topMargin: Style.space(6)
          Layout.bottomMargin: Style.space(8)
          spacing: Style.space(6)

          PlainText {
            Layout.fillWidth: true
            text: "Omatype binary not found"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.weight: Font.DemiBold
          }

          PlainText {
            Layout.fillWidth: true
            text: "Build and install the native Omatype app from the plugin folder (./bin/install or ./bin/build), then click Refresh."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        // Font results list.
        ListView {
          id: fontList
          visible: !service.binaryMissing && root.activeItems.length > 0
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(Style.space(340), contentHeight)
          clip: true
          spacing: Style.space(2)
          model: root.activeItems

          ScrollBar.vertical: ScrollBar {
            policy: fontList.contentHeight > fontList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
          }

          delegate: Rectangle {
            id: rowItem
            required property var modelData
            required property int index

            readonly property string familyName: root.discoverMode
              ? String(modelData.family || "")
              : String(modelData.name || "")
            readonly property string subtitleText: root.discoverMode
              ? ((Array.isArray(modelData.designers) && modelData.designers.length > 0
                  ? modelData.designers.join(", ") + " · "
                  : "") + String(modelData.source || ""))
              : ((Array.isArray(modelData.styles) ? modelData.styles.length : 0) + " styles" +
                  (modelData.foundry ? " · " + String(modelData.foundry) : ""))
            readonly property bool isRowSelected: root.cursorActive && root.selectedIndex === index
            readonly property bool isRowInstalling: root.discoverMode && service.isInstalling(familyName)
            readonly property bool isRowInstalled: root.discoverMode ? Boolean(modelData.installed) : true

            width: fontList.width
            height: Style.space(44)
            radius: Math.min(4, Style.cornerRadius)
            color: isRowSelected
              ? root.selectedFill
              : (rowMouse.containsMouse ? root.hoverFill : "transparent")

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.selectedIndex = rowItem.index
                if (!root.discoverMode) root.launchFullApp()
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(8)

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(1)

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  PlainText {
                    Layout.fillWidth: true
                    text: rowItem.familyName
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                  }

                  PlainText {
                    visible: Boolean(rowItem.modelData.variable)
                    text: "VF"
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.weight: Font.DemiBold
                  }

                  PlainText {
                    visible: !root.discoverMode && Boolean(rowItem.modelData.monospace)
                    text: "M"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.weight: Font.DemiBold
                  }
                }

                PlainText {
                  Layout.fillWidth: true
                  text: rowItem.subtitleText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Rectangle {
                visible: root.discoverMode
                Layout.alignment: Qt.AlignVCenter
                radius: Math.min(4, Style.cornerRadius)
                color: rowItem.isRowInstalled
                  ? "transparent"
                  : (installBtnMouse.containsMouse
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
                    : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16))
                implicitWidth: actionText.implicitWidth + Style.space(14)
                implicitHeight: actionText.implicitHeight + Style.space(6)

                PlainText {
                  id: actionText
                  anchors.centerIn: parent
                  text: rowItem.isRowInstalled
                    ? "Installed"
                    : (rowItem.isRowInstalling ? "Installing…" : "Install")
                  color: rowItem.isRowInstalled ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.weight: rowItem.isRowInstalled ? Font.Normal : Font.DemiBold
                }

                MouseArea {
                  id: installBtnMouse
                  anchors.fill: parent
                  enabled: !rowItem.isRowInstalled && !rowItem.isRowInstalling
                  hoverEnabled: true
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: service.installFamily(rowItem.familyName)
                }
              }

              PlainText {
                visible: !root.discoverMode && Boolean(rowItem.modelData.yours)
                text: "Yours"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        // Loading / empty state.
        PlainText {
          visible: !service.binaryMissing && root.activeItems.length === 0
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(10)
          Layout.rightMargin: Style.space(10)
          Layout.topMargin: Style.space(8)
          Layout.bottomMargin: Style.space(8)
          text: (root.discoverMode ? service.loadingDiscover : service.loadingInstalled)
            ? "Loading…"
            : (root.query !== "" ? "No matching fonts." : "No fonts to display.")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
