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
    property bool screenOff: false
    property string activeSession: ""
    property var profiles: []
    property bool profilesLoaded: false

    property int dimInSec: -1
    property int screenOffInSec: -1
    property int sleepInSec: -1
    property int lockInSec: -1
    property bool dimInhibited: false
    property bool screenOffInhibited: false
    property bool sleepInhibited: false
    property bool lockInhibited: false
    property bool lockOnScreenOff: false
    property bool inhibited: false
    property var inhibitors: []
    property bool manualInhibitActive: false

    property int cpuFreqMhz: -1

    property bool batteryPresent: false
    property int batteryPercent: -1
    property string batteryStatus: ""
    property int batteryTimeToEmpty: -1
    property int batteryTimeToFull: -1

    property string _statusOutput: ""
    property string _profilesOutput: ""
    property string _batteryOutput: ""
    property string _inhibitorsOutput: ""
    property string _targetProfile: ""

    // "dim in:"/"screen off in:"/"sleep in:" report "prevented by inhibitor" instead of a
    // countdown while an inhibitor is active, since the underlying timer keeps running.
    function parseTimeLeft(v) {
        if (v === "prevented by inhibitor") return { sec: -1, inhibited: true }
        var m = v.match(/(\d+)m\s+(\d+)s/)
        return { sec: m ? parseInt(m[1]) * 60 + parseInt(m[2]) : -1, inhibited: false }
    }

    // "lock in:" additionally reports "with screen off" (locks via lock_on_screen_off rather
    // than its own timer) and "disabled" (lock_timeout is 0 and lock_on_screen_off is off).
    function parseLockIn(v) {
        if (v === "prevented by inhibitor") return { sec: -1, inhibited: true, onScreenOff: false }
        if (v === "with screen off") return { sec: -1, inhibited: false, onScreenOff: true }
        if (v === "disabled") return { sec: -1, inhibited: false, onScreenOff: false }
        var m = v.match(/(\d+)m\s+(\d+)s/)
        return { sec: m ? parseInt(m[1]) * 60 + parseInt(m[2]) : -1, inhibited: false, onScreenOff: false }
    }

    function refreshStatus() {
        _statusOutput = ""
        statusProcess.running = true
        _batteryOutput = ""
        batteryProcess.running = true
        _inhibitorsOutput = ""
        inhibitorsProcess.running = true
        watchdog.restart()
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

    function lock() {
        if (!available) return
        lockProcess.running = true
    }

    function reloadConfig() {
        if (!available) return
        reloadConfigProcess.running = true
    }

    // No reason given on uninhibit: the daemon removes the sole manual inhibitor if
    // there's exactly one, which is what the panel's single toggle button expects.
    function toggleManualInhibit() {
        if (!available) return
        if (manualInhibitActive) uninhibitProcess.running = true
        else inhibitProcess.running = true
    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        onTriggered: root.refreshStatus()
    }

    // Guards against a hung or missing draind-ctl binary leaving the bar stuck on stale
    // "available" state: if the status poll hasn't completed by the next tick, force unavailable.
    Timer {
        id: watchdog
        interval: root.refreshInterval * 2
        repeat: false
        onTriggered: root.available = false
    }

    Process {
        id: statusProcess
        command: ["sh", "-c", root.ctlPath + " status"]
        stdout: SplitParser {
            onRead: line => root._statusOutput += line + "\n"
        }
        onExited: exitCode => {
            watchdog.stop()
            if (exitCode === 0) {
                var p = "", d = false, so = false, s = ""
                var dimIn = -1, screenOffIn = -1, sleepIn = -1, lockIn = -1
                var dimInh = false, screenOffInh = false, sleepInh = false, lockInh = false
                var lockOnSo = false
                var cpuFreq = -1
                root._statusOutput.split("\n").forEach(line => {
                    var idx = line.indexOf(":")
                    if (idx === -1) return
                    var k = line.slice(0, idx).trim(), v = line.slice(idx + 1).trim()
                    if (k === "profile") p = v
                    else if (k === "dimmed") d = v === "yes"
                    else if (k === "screen_off") so = v === "yes"
                    else if (k === "active session id") s = v
                    else if (k === "cpu freq") cpuFreq = parseInt(v)
                    else if (k === "dim in") { var td = root.parseTimeLeft(v); dimIn = td.sec; dimInh = td.inhibited }
                    else if (k === "screen off in") { var ts = root.parseTimeLeft(v); screenOffIn = ts.sec; screenOffInh = ts.inhibited }
                    else if (k === "sleep in") { var tl = root.parseTimeLeft(v); sleepIn = tl.sec; sleepInh = tl.inhibited }
                    else if (k === "lock in") { var tk = root.parseLockIn(v); lockIn = tk.sec; lockInh = tk.inhibited; lockOnSo = tk.onScreenOff }
                })
                root.profile = p
                root.dimmed = d
                root.screenOff = so
                root.activeSession = s
                root.dimInSec = dimIn
                root.screenOffInSec = screenOffIn
                root.sleepInSec = sleepIn
                root.lockInSec = lockIn
                root.dimInhibited = dimInh
                root.screenOffInhibited = screenOffInh
                root.sleepInhibited = sleepInh
                root.lockInhibited = lockInh
                root.lockOnScreenOff = lockOnSo
                root.inhibited = dimInh || screenOffInh || sleepInh || lockInh
                root.cpuFreqMhz = cpuFreq
                root.available = p !== ""
            } else {
                root.available = false
                root.profile = ""
                root.dimmed = false
                root.screenOff = false
                root.activeSession = ""
                root.dimInSec = -1
                root.screenOffInSec = -1
                root.sleepInSec = -1
                root.lockInSec = -1
                root.dimInhibited = false
                root.screenOffInhibited = false
                root.sleepInhibited = false
                root.lockInhibited = false
                root.lockOnScreenOff = false
                root.inhibited = false
                root.cpuFreqMhz = -1
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
                    var idx = line.indexOf(":")
                    if (idx === -1) return
                    var k = line.slice(0, idx).trim(), v = line.slice(idx + 1).trim()
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
        id: inhibitorsProcess
        command: ["sh", "-c", root.ctlPath + " list-inhibitors"]
        stdout: SplitParser {
            onRead: line => {
                var t = line.trim()
                if (t) root._inhibitorsOutput += t + "\n"
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                var list = root._inhibitorsOutput.split("\n").filter(l => l !== "" && l !== "none")
                root.inhibitors = list
                root.manualInhibitActive = list.some(l => l.indexOf("[manual]") === 0)
            }
            root._inhibitorsOutput = ""
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

    Process {
        id: lockProcess
        command: ["sh", "-c", root.ctlPath + " lock"]
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showNotice(pluginApi?.tr("toast.lock_failed") ?? "Failed to lock session")
            }
        }
    }

    Process {
        id: inhibitProcess
        command: ["sh", "-c", root.ctlPath + " inhibit"]
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showNotice(pluginApi?.tr("toast.inhibit_failed") ?? "Failed to inhibit idle")
            }
            root.refreshStatus()
        }
    }

    Process {
        id: uninhibitProcess
        command: ["sh", "-c", root.ctlPath + " uninhibit"]
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showNotice(pluginApi?.tr("toast.uninhibit_failed") ?? "Failed to remove idle inhibitor")
            }
            root.refreshStatus()
        }
    }

    Process {
        id: reloadConfigProcess
        command: ["sh", "-c", root.ctlPath + " reload-config"]
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showNotice(pluginApi?.tr("toast.reload_config") ?? "Configuration reloaded")
            } else {
                ToastService.showNotice(pluginApi?.tr("toast.reload_config_failed") ?? "Failed to reload configuration")
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
