import QtQuick
import Quickshell.Io
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null

    readonly property string ctlPath: pluginApi?.pluginSettings?.ctlPath
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.ctlPath
        ?? "draind-ctl"
    readonly property int refreshInterval: pluginApi?.pluginSettings?.refreshInterval
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.refreshInterval
        ?? 5000

    property bool available: false
    property string profile: ""
    property bool dimmed: false
    property string activeSession: ""
    property var profiles: []
    property bool profilesLoaded: false

    property bool batteryPresent: false
    property int batteryPercent: -1
    property string batteryStatus: ""
    property int batteryTimeToEmpty: -1
    property int batteryTimeToFull: -1

    property string _statusOutput: ""
    property string _profilesOutput: ""
    property string _batteryOutput: ""
    property string _targetProfile: ""

    function refreshStatus() {
        _statusOutput = ""
        statusProcess.running = true
        _batteryOutput = ""
        batteryProcess.running = true
    }

    function loadProfiles() {
        _profilesOutput = ""
        profilesProcess.running = true
    }

    function setProfile(name) {
        if (!available || name === profile) return
        _targetProfile = name
        setProfileProcess.running = true
    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Process {
        id: statusProcess
        command: ["sh", "-c", root.ctlPath + " status"]
        stdout: SplitParser {
            onRead: line => root._statusOutput += line + "\n"
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                var p = "", d = false, s = ""
                root._statusOutput.split("\n").forEach(line => {
                    var m = line.match(/^(\S+):\s+(.+)$/)
                    if (m) {
                        var k = m[1], v = m[2].trim()
                        if (k === "profile") p = v
                        else if (k === "dimmed") d = v === "yes"
                        else if (k === "active_session") s = v
                    }
                })
                root.profile = p
                root.dimmed = d
                root.activeSession = s
                root.available = p !== ""
            } else {
                root.available = false
                root.profile = ""
                root.dimmed = false
                root.activeSession = ""
            }
            root._statusOutput = ""
            if (!root.profilesLoaded) root.loadProfiles()
        }
    }

    Process {
        id: profilesProcess
        command: ["sh", "-c", root.ctlPath + " list-profiles"]
        stdout: SplitParser {
            onRead: line => {
                var t = line.trim()
                if (t) root._profilesOutput += t + "\n"
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                var list = root._profilesOutput.split("\n").filter(l => l !== "")
                root.profiles = list
                root.profilesLoaded = list.length > 0
            }
            root._profilesOutput = ""
        }
    }

    Process {
        id: batteryProcess
        command: ["sh", "-c", root.ctlPath + " battery"]
        stdout: SplitParser {
            onRead: line => root._batteryOutput += line + "\n"
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                var present = false, pct = -1, st = "", tte = -1, ttf = -1
                root._batteryOutput.split("\n").forEach(line => {
                    var m = line.match(/^(\S+):\s+(.+)$/)
                    if (m) {
                        var k = m[1], v = m[2].trim()
                        if (k === "status") {
                            st = v
                            present = (v !== "absent" && v !== "unknown")
                        } else if (k === "percent") {
                            pct = parseInt(v)
                        } else if (k === "time_to_empty") {
                            var te = v.match(/(\d+)h\s+(\d+)m/)
                            if (te) tte = parseInt(te[1]) * 60 + parseInt(te[2])
                        } else if (k === "time_to_full") {
                            var tf = v.match(/(\d+)h\s+(\d+)m/)
                            if (tf) ttf = parseInt(tf[1]) * 60 + parseInt(tf[2])
                        }
                    }
                })
                root.batteryPresent = present
                root.batteryPercent = pct
                root.batteryStatus = st
                root.batteryTimeToEmpty = tte
                root.batteryTimeToFull = ttf
            }
            root._batteryOutput = ""
        }
    }

    Process {
        id: setProfileProcess
        command: ["sh", "-c", root.ctlPath + " set-profile " + root._targetProfile]
        onExited: exitCode => {
            if (exitCode === 0) {
                var msg = pluginApi?.tr("toast.profile_set") ?? "Profile changed to {profile}"
                ToastService.showNotice(msg.replace("{profile}", root._targetProfile))
            } else {
                ToastService.showNotice(pluginApi?.tr("toast.profile_set_failed") ?? "Failed to change power profile")
            }
            root.refreshStatus()
        }
    }

    IpcHandler {
        target: "plugin:" + (pluginApi?.manifest?.id ?? "draind")
        function toggle() {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
            }
        }
        function refresh() {
            root.refreshStatus()
        }
    }

    Component.onCompleted: Qt.callLater(root.refreshStatus)
}
