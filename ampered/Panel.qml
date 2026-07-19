import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 320 * Style.uiScaleRatio
    property real contentPreferredHeight: Math.min(600 * Style.uiScaleRatio, cardsColumn.implicitHeight + buttonRow.implicitHeight + Style.marginL * 2 + Style.marginM)
    readonly property bool allowAttach: true
    anchors.fill: parent

    readonly property var main: pluginApi?.mainInstance

    function idleText(sec) {
        if (sec < 0) return pluginApi?.tr("panel.disabled") ?? "Disabled"
        return Math.floor(sec / 60) + "m " + (sec % 60) + "s"
    }

    // Lock differs: a -1 lock timer can still mean "locks when the screen turns off"
    // (lock_on_screen_off) rather than lock-on-idle being off entirely.
    function lockText(sec, onScreenOff) {
        if (sec >= 0) return Math.floor(sec / 60) + "m " + (sec % 60) + "s"
        if (onScreenOff) return pluginApi?.tr("panel.with_screen_off") ?? "With screen off"
        return pluginApi?.tr("panel.disabled") ?? "Disabled"
    }

    // "[source] reason" for one inhibitor, tolerating missing fields.
    function inhibitorText(entry) {
        var src = (entry && entry.source) ? entry.source : "?"
        var reason = (entry && entry.reason) ? entry.reason : ""
        return "[" + src + "]" + (reason ? " " + reason : "")
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"
        radius: Style.radiusL

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    id: cardsColumn
                    width: parent.width
                    spacing: Style.marginM

                    // Battery card — headline percent + status. When the daemon is unreachable,
                    // this same card carries the connection error instead.
                    Card {
                        headerIcon: (main?.available ?? false)
                            ? ((main?.batteryStatus === "charging") ? "battery-charging" : "battery")
                            : "circle-x"
                        headerIconColor: {
                            if (!(main?.available ?? false)) return Color.mError
                            var pct = main?.batteryPercent ?? -1
                            var s = main?.batteryStatus ?? ""
                            if (pct >= 0 && pct <= 10 && s === "discharging") return Color.mError
                            return Color.mPrimary
                        }
                        title: {
                            if (!(main?.available ?? false)) return pluginApi?.tr("panel.unavailable") ?? "Daemon unavailable"
                            if (!(main?.batteryPresent ?? false)) return pluginApi?.tr("panel.battery") ?? "Battery"
                            var pct = main?.batteryPercent ?? -1
                            var label = pluginApi?.tr("panel.battery") ?? "Battery"
                            return pct >= 0 ? label + " — " + pct + "%" : label
                        }

                        NText {
                            visible: !(main?.available ?? false)
                            text: pluginApi?.tr("panel.no_daemon") ?? "Cannot connect to ampered. Make sure the daemon is running."
                            pointSize: Style.fontSizeXS
                            color: Color.mError
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        NText {
                            visible: (main?.available ?? false) && (main?.batteryPresent ?? false) && (main?.batteryStatus ?? "") !== ""
                            text: (pluginApi?.tr("panel.status") ?? "Status") + ": " + (main?.batteryStatus ?? "")
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        // Power source (ac | battery) — shown whenever the daemon reports it.
                        NText {
                            visible: (main?.available ?? false) && (main?.powerSource ?? "") !== ""
                            text: {
                                var ps = main?.powerSource ?? ""
                                var label = ps === "ac"
                                    ? (pluginApi?.tr("panel.power_ac") ?? "AC power")
                                    : ps === "battery"
                                        ? (pluginApi?.tr("panel.power_battery") ?? "On battery")
                                        : ps
                                return (pluginApi?.tr("panel.power_source") ?? "Power source") + ": " + label
                            }
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            visible: (main?.batteryTimeToEmpty ?? -1) >= 0
                            text: {
                                var t = main?.batteryTimeToEmpty ?? 0
                                var h = Math.floor(t / 60), m = t % 60
                                return (pluginApi?.tr("panel.battery_time_remaining") ?? "Time remaining") + ": " + h + "h " + m + "m"
                            }
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            visible: (main?.batteryTimeToFull ?? -1) >= 0
                            text: {
                                var t = main?.batteryTimeToFull ?? 0
                                var h = Math.floor(t / 60), m = t % 60
                                return (pluginApi?.tr("panel.battery_time_to_full") ?? "Time to full") + ": " + h + "h " + m + "m"
                            }
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }
                    }

                    // Idle timers card — seconds until each idle stage, or "Disabled".
                    // Header turns red while idle is inhibited (something is keeping the
                    // machine awake, so the countdowns won't actually fire).
                    Card {
                        visible: main?.available ?? false
                        headerIcon: (main?.inhibited ?? false) ? "hand" : "clock"
                        headerIconColor: (main?.inhibited ?? false) ? Color.mError : Color.mPrimary
                        title: pluginApi?.tr("panel.idle_timers") ?? "Idle Timers"

                        NText {
                            visible: main?.inhibited ?? false
                            text: pluginApi?.tr("panel.inhibited") ?? "Idle inhibited — countdowns paused"
                            pointSize: Style.fontSizeXS
                            color: Color.mError
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        NText {
                            text: (pluginApi?.tr("panel.dim_in") ?? "Dim in") + ": " + root.idleText(main?.dimInSec ?? -1)
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            text: (pluginApi?.tr("panel.screen_off_in") ?? "Screen off in") + ": " + root.idleText(main?.screenOffInSec ?? -1)
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            text: (pluginApi?.tr("panel.sleep_in") ?? "Sleep in") + ": " + root.idleText(main?.sleepInSec ?? -1)
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            text: (pluginApi?.tr("panel.lock_in") ?? "Lock in") + ": " + root.lockText(main?.lockInSec ?? -1, main?.lockOnScreenOff ?? false)
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }
                    }

                    // Inhibitors card — what is currently holding idle off (media, manual, etc.).
                    Card {
                        visible: (main?.available ?? false) && (main?.inhibitors?.length ?? 0) > 0
                        headerIcon: "hand"
                        headerIconColor: Color.mError
                        title: pluginApi?.tr("panel.inhibitors") ?? "Inhibitors"

                        Repeater {
                            model: main?.inhibitors ?? []
                            delegate: NText {
                                required property var modelData
                                text: root.inhibitorText(modelData)
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurface
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Profiles card — one button per profile; the active one is highlighted.
                    Card {
                        visible: (main?.available ?? false) && (main?.profiles?.length ?? 0) > 0
                        headerIcon: "bolt"
                        headerIconColor: Color.mPrimary
                        title: pluginApi?.tr("panel.profiles") ?? "Power Profiles"

                        Repeater {
                            model: main?.profiles ?? []
                            delegate: NButton {
                                required property string modelData
                                required property int index
                                Layout.fillWidth: true
                                text: modelData
                                icon: modelData.toLowerCase() === "performance" ? "bolt"
                                    : (modelData.toLowerCase() === "powersave" || modelData.toLowerCase() === "power-save") ? "leaf"
                                    : "battery"
                                backgroundColor: modelData === main?.profile ? Color.mPrimary : Color.mSurface
                                textColor: modelData === main?.profile ? Color.mOnPrimary : Color.mOnSurface
                                onClicked: main?.setProfile(modelData)
                            }
                        }
                    }
                }
            }

            RowLayout {
                id: buttonRow
                Layout.fillWidth: true
                spacing: Style.marginS

                // Manual idle-inhibit toggle — add a persistent "keep awake" or drop it.
                NButton {
                    Layout.fillWidth: true
                    visible: main?.available ?? false
                    text: (main?.manualInhibitActive ?? false)
                        ? (pluginApi?.tr("panel.uninhibit") ?? "Uninhibit")
                        : (pluginApi?.tr("panel.inhibit") ?? "Inhibit")
                    icon: "hand"
                    backgroundColor: (main?.manualInhibitActive ?? false) ? Color.mPrimary : Color.mSurface
                    textColor: (main?.manualInhibitActive ?? false) ? Color.mOnPrimary : Color.mOnSurface
                    onClicked: main?.toggleManualInhibit()
                }

                NButton {
                    Layout.fillWidth: true
                    visible: main?.available ?? false
                    text: pluginApi?.tr("panel.lock_now") ?? "Lock now"
                    icon: "lock"
                    onClicked: main?.lock()
                }

                NButton {
                    Layout.fillWidth: true
                    visible: main?.available ?? false
                    text: pluginApi?.tr("panel.reload_config") ?? "Reload config"
                    icon: "rotate"
                    onClicked: main?.reloadConfig()
                }
            }
        }
    }
}
