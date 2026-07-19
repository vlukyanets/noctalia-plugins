import QtQuick
import Quickshell.Io
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null

    readonly property string ctlPath: pluginApi?.pluginSettings?.ctlPath
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.ctlPath
        ?? "ampered-ctl"

    // Repurposed from a poll rate: updates are event-driven over the `watch` stream, so this is
    // only the base cadence for reconnecting a dropped stream (and sizing the liveness window).
    readonly property int reconnectInterval: pluginApi?.pluginSettings?.refreshInterval
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.refreshInterval
        ?? 5000

    // Live connection to the daemon: true once a snapshot has arrived over the stream; false
    // whenever the `ampered-ctl watch` process is down (crash, missing binary, or hung pipe).
    property bool available: false

    property string profile: ""
    property var profiles: []
    property string powerSource: ""
    property bool dimmed: false
    property bool screenOff: false
    property bool locked: false
    property bool inhibited: false

    // Inhibitor list carried inline in each snapshot: [{ source, scope, reason }, ...].
    // `manualInhibitActive` is true when a user-held (source == "manual") entry exists.
    property var inhibitors: []
    property bool manualInhibitActive: false

    // Seconds until each idle stage, or -1 when disabled / no agent.
    property int dimInSec: -1
    property int screenOffInSec: -1
    property int sleepInSec: -1
    property int lockInSec: -1
    property bool lockOnScreenOff: false

    property bool batteryPresent: false
    property string batteryStatus: ""
    property int batteryPercent: -1
    property int batteryTimeToEmpty: -1   // minutes, -1 = unknown
    property int batteryTimeToFull: -1    // minutes, -1 = unknown

    property string _targetProfile: ""
    property int _reconnectDelay: 0       // grows on consecutive failures, reset on a good snapshot

    // ── Commands (still one-shot; their effect comes back over the stream) ────────────────
    function setProfile(name) {
        if (!available || name === "" || name === profile) return
        _targetProfile = name
        setProfileProcess.running = true
    }

    function lock() {
        if (available) lockProcess.running = true
    }

    function reloadConfig() {
        if (available) reloadConfigProcess.running = true
    }

    // No reason passed on removal: the daemon drops the sole manual inhibitor when exactly one
    // is held, which is what this single toggle button relies on.
    function toggleManualInhibit() {
        if (!available) return
        if (manualInhibitActive) uninhibitProcess.running = true
        else inhibitProcess.running = true
    }

    // Force an immediate reconnect of the stream (used by the `refresh` IPC).
    function reconnect() {
        _reconnectDelay = 0
        reconnectTimer.stop()
        if (watchProcess.running) watchProcess.running = false   // onExited schedules the restart
        else _startWatch()
    }

    function _startWatch() {
        if (!watchProcess.running) watchProcess.running = true
        livenessTimer.restart()
    }

    function _clearState() {
        available = false
        profile = ""
        profiles = []
        powerSource = ""
        dimmed = false
        screenOff = false
        locked = false
        inhibited = false
        inhibitors = []
        manualInhibitActive = false
        dimInSec = -1
        screenOffInSec = -1
        sleepInSec = -1
        lockInSec = -1
        lockOnScreenOff = false
        batteryPresent = false
        batteryStatus = ""
        batteryPercent = -1
        batteryTimeToEmpty = -1
        batteryTimeToFull = -1
    }

    // Apply one full snapshot object from the stream. Heartbeat/partial lines are ignored so a
    // liveness ping can't wipe live state — every real snapshot carries `active_profile`.
    function applySnapshot(s) {
        if (!s || typeof s !== "object") return
        if (s.heartbeat !== undefined) return            // liveness-only ping, handled by caller
        if (typeof s.active_profile !== "string") return // not a full snapshot

        profile = s.active_profile
        profiles = Array.isArray(s.profiles) ? s.profiles : []
        powerSource = s.power_source ?? ""
        dimmed = s.dimmed === true
        screenOff = s.screen_off === true
        locked = s.locked === true
        inhibited = s.inhibited === true
        lockOnScreenOff = s.lock_on_screen_off === true
        dimInSec = (typeof s.dim_in_sec === "number") ? s.dim_in_sec : -1
        screenOffInSec = (typeof s.screen_off_in_sec === "number") ? s.screen_off_in_sec : -1
        sleepInSec = (typeof s.sleep_in_sec === "number") ? s.sleep_in_sec : -1
        lockInSec = (typeof s.lock_in_sec === "number") ? s.lock_in_sec : -1

        var b = s.battery ?? {}
        batteryPresent = b.present === true
        batteryStatus = b.status ?? ""
        batteryPercent = (typeof b.percent === "number") ? b.percent : -1
        batteryTimeToEmpty = (typeof b.time_to_empty_min === "number") ? b.time_to_empty_min : -1
        batteryTimeToFull = (typeof b.time_to_full_min === "number") ? b.time_to_full_min : -1

        var inh = Array.isArray(s.inhibitors) ? s.inhibitors : []
        inhibitors = inh
        manualInhibitActive = inh.some(i => (i.source ?? "") === "manual")

        available = profile !== ""
        _reconnectDelay = 0   // healthy stream: reset the backoff
    }

    function _nextReconnectDelay() {
        // Ramp 1s → 2s → 4s … capped at the configured interval, so a missing daemon settles
        // into steady retries at `reconnectInterval` rather than a spin loop.
        var cap = Math.max(reconnectInterval, 1000)
        var d = _reconnectDelay <= 0 ? Math.min(1000, cap) : Math.min(_reconnectDelay * 2, cap)
        _reconnectDelay = d
        return d
    }

    // Long-lived stream: `ampered-ctl watch --json` prints one compact JSON object per line — a
    // full snapshot on connect and on every change, plus periodic heartbeat lines for liveness.
    Process {
        id: watchProcess
        command: ["sh", "-c", root.ctlPath + " watch --json"]
        stdout: SplitParser {
            onRead: line => {
                var t = line.trim()
                if (t === "") return
                livenessTimer.restart()   // any line proves the stream is alive
                var obj
                try {
                    obj = JSON.parse(t)
                } catch (e) {
                    return
                }
                root.applySnapshot(obj)
            }
        }
        onExited: exitCode => {
            root._clearState()
            livenessTimer.stop()
            reconnectTimer.interval = root._nextReconnectDelay()
            reconnectTimer.restart()
        }
    }

    // Reconnect after the stream drops, backing off up to the configured interval.
    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: root._startWatch()
    }

    // Liveness watchdog: restarted by every incoming line. If nothing arrives — not even a
    // heartbeat — within the window, assume the pipe is hung and force a reconnect.
    Timer {
        id: livenessTimer
        interval: Math.max(root.reconnectInterval * 2, 15000)
        repeat: false
        onTriggered: {
            if (watchProcess.running) watchProcess.running = false   // -> onExited -> reconnect
        }
    }

    // ── Mutating commands ────────────────────────────────────────────────────────────────
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
        id: reloadConfigProcess
        command: ["sh", "-c", root.ctlPath + " reload-config"]
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showNotice(pluginApi?.tr("toast.reload_config") ?? "Configuration reloaded")
            } else {
                ToastService.showNotice(pluginApi?.tr("toast.reload_config_failed") ?? "Failed to reload configuration")
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
        }
    }

    Process {
        id: uninhibitProcess
        command: ["sh", "-c", root.ctlPath + " uninhibit"]
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showNotice(pluginApi?.tr("toast.uninhibit_failed") ?? "Failed to remove idle inhibitor")
            }
        }
    }

    IpcHandler {
        target: "plugin:" + (pluginApi?.manifest?.id ?? "ampered")
        function toggle() {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen))
            }
        }
        function refresh() {
            root.reconnect()
        }
    }

    Component.onCompleted: Qt.callLater(root._startWatch)
}
