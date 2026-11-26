import QtQuick

// Safe Text wrapper for plugin UI: forces PlainText so font family names,
// designer attributions, and paths are never interpreted as rich text markup.
Text {
  textFormat: Text.PlainText
  renderType: Text.NativeRendering
}
