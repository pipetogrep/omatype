import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var installedFonts: []
  property var discoverFonts: []
  property bool loadingInstalled: false
  property bool loadingDiscover: false
  property bool binaryMissing: false
  property string lastError: ""
  property string lastNotice: ""
  property var installingFamilies: ({})

  readonly property int userFontCount: {
    var count = 0
    for (var i = 0; i < installedFonts.length; i++) {
      if (installedFonts[i] && installedFonts[i].yours) count++
    }
    return count
  }

  readonly property string localBuildBinaryPath: {
    var resolved = String(Qt.resolvedUrl("build/omatype"))
    return resolved.indexOf("file://") === 0 ? resolved.slice(7) : resolved
  }

  // Locate the compiled `omatype` binary: prefer PATH (/usr/bin/omatype),
  // then ~/.local/bin/omatype, then a local build/omatype inside the plugin checkout.
  function buildCommand(args) {
    var script = 'local_bin="$1"; shift; ' +
      'if command -v omatype >/dev/null 2>&1; then exec omatype "$@"; ' +
      'elif [ -x "$HOME/.local/bin/omatype" ]; then exec "$HOME/.local/bin/omatype" "$@"; ' +
      'elif [ -x "$local_bin" ]; then exec "$local_bin" "$@"; ' +
      'else echo "OMATYPE_BINARY_MISSING" >&2; exit 127; fi'
    return ["/bin/sh", "-c", script, "--", localBuildBinaryPath].concat(args)
  }

  function isInstalling(family) {
    return !!installingFamilies[String(family)]
  }

  function setInstalling(family, active) {
    var next = Object.assign({}, installingFamilies)
    if (active) next[String(family)] = true
    else delete next[String(family)]
    installingFamilies = next
  }

  function refreshInstalled() {
    if (listProcess.running) return
    loadingInstalled = true
    lastError = ""
    listProcess.command = buildCommand(["list", "--json"])
    listProcess.running = true
  }

  function searchCatalog(query) {
    var trimmed = String(query || "").trim()
    pendingQuery = trimmed
    if (searchProcess.running) {
      queuedSearch = true
      return
    }
    runSearch(trimmed)
  }

  property string pendingQuery: ""
  property bool queuedSearch: false

  function runSearch(query) {
    loadingDiscover = true
    lastError = ""
    var args = ["search"]
    if (query === "") {
      args.push("--source", "indie")
    } else {
      args.push(query)
    }
    args.push("--json")
    searchProcess.command = buildCommand(args)
    searchProcess.running = true
  }

  function installFamily(family) {
    var name = String(family || "").trim()
    if (name === "" || isInstalling(name)) return
    setInstalling(name, true)
    lastError = ""
    lastNotice = ""

    var proc = installProcessComponent.createObject(root, {
      targetFamily: name,
      command: buildCommand(["get", name, "--json"])
    })
    if (proc) {
      proc.running = true
    } else {
      setInstalling(name, false)
    }
  }

  function launchApp() {
    Quickshell.execDetached(buildCommand([]))
  }

  Process {
    id: listProcess
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parsed = JSON.parse(this.text || "[]")
          root.installedFonts = Array.isArray(parsed) ? parsed : []
          root.binaryMissing = false
          root.lastError = ""
        } catch (e) {
          if (!root.binaryMissing) root.lastError = "Failed to read installed fonts"
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        var msg = (this.text || "").trim()
        if (msg.indexOf("OMATYPE_BINARY_MISSING") !== -1) {
          root.binaryMissing = true
          root.lastError = ""
        } else if (msg !== "") {
          root.lastError = msg
        }
      }
    }
    onExited: function(code) {
      root.loadingInstalled = false
      if (code === 127) root.binaryMissing = true
    }
  }

  Process {
    id: searchProcess
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parsed = JSON.parse(this.text || "[]")
          root.discoverFonts = Array.isArray(parsed) ? parsed : []
          root.binaryMissing = false
          root.lastError = ""
        } catch (e) {
          if (!root.binaryMissing) root.lastError = "Failed to read font catalog"
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        var msg = (this.text || "").trim()
        if (msg.indexOf("OMATYPE_BINARY_MISSING") !== -1) {
          root.binaryMissing = true
          root.lastError = ""
        } else if (msg !== "") {
          root.lastError = msg
        }
      }
    }
    onExited: function(code) {
      root.loadingDiscover = false
      if (code === 127) root.binaryMissing = true
      if (root.queuedSearch) {
        root.queuedSearch = false
        root.runSearch(root.pendingQuery)
      }
    }
  }

  Component {
    id: installProcessComponent

    Process {
      id: installProc
      property string targetFamily: ""
      property string stdoutText: ""
      property string stderrText: ""

      stdout: StdioCollector {
        onStreamFinished: installProc.stdoutText = (this.text || "").trim()
      }
      stderr: StdioCollector {
        onStreamFinished: installProc.stderrText = (this.text || "").trim()
      }

      onExited: function(code) {
        root.setInstalling(installProc.targetFamily, false)
        if (code === 127 || installProc.stderrText.indexOf("OMATYPE_BINARY_MISSING") !== -1) {
          root.binaryMissing = true
        } else if (code === 0) {
          root.lastNotice = "Installed " + installProc.targetFamily
          // Mark installed locally so the button updates right away.
          var updated = []
          for (var i = 0; i < root.discoverFonts.length; i++) {
            var item = Object.assign({}, root.discoverFonts[i])
            if (item.family === installProc.targetFamily) item.installed = true
            updated.push(item)
          }
          root.discoverFonts = updated
          root.refreshInstalled()
        } else {
          var errMsg = installProc.stderrText
          try {
            var parsed = JSON.parse(installProc.stdoutText || "{}")
            if (parsed.error) errMsg = String(parsed.error)
          } catch (e) {}
          root.lastError = errMsg || ("Could not install " + installProc.targetFamily)
        }
        installProc.destroy()
      }
    }
  }
}
