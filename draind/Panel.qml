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

    function timeLeftText(sec, inhibitedField) {
        if (inhibitedField) return pluginApi?.tr("panel.prevented_by_inhibitor") ?? "Prevented by inhibitor"
        if (sec < 0) return pluginApi?.tr("panel.disabled") ?? "Disabled"
        return Math.floor(sec / 60) + "m " + (sec % 60) + "s"
    }

    // "lock in" differs from the other idle timers: absent lock_timeout can still mean
    // locking is active via lock_on_screen_off, so it needs its own "disabled" fallback.
    function lockInText(sec, inhibitedField, onScreenOff) {
        if (inhibitedField) return pluginApi?.tr("panel.prevented_by_inhibitor") ?? "Prevented by inhibitor"
        if (sec >= 0) return Math.floor(sec / 60) + "m " + (sec % 60) + "s"
        if (onScreenOff) return pluginApi?.tr("panel.with_screen_off") ?? "With screen off"
        return pluginApi?.tr("panel.disabled") ?? "Disabled"
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"
        radius: Style.radiusL

        ColumnLayout {
            id: mainColumn
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            // Cards scroll independently of the button row below, so the row stays
            // reachable no matter how many cards (or inhibitors/profiles) are visible.
            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    id: cardsColumn
                    width: parent.width
                    spacing: Style.marginM

                    // Status card
                    Card {
                        headerIcon: (main?.available ?? false)
                            ? (main.dimmed ? "moon" : "circle-check")
                            : "circle-x"
                        headerIconColor: (main?.available ?? false) ? Color.mPrimary : Color.mError
                        title: (pluginApi?.tr("panel.title") ?? "Power Management") + ": " + (
                            (main?.available ?? false)
                                ? (main.dimmed ? pluginApi?.tr("panel.dimmed") : pluginApi?.tr("panel.active"))
                                : pluginApi?.tr("panel.unavailable")
                        )

                        NText {
                            visible: !(main?.available ?? false)
                            text: pluginApi?.tr("panel.no_daemon") ?? "Cannot connect to draind. Make sure the daemon is running."
                            pointSize: Style.fontSizeXS
                            color: Color.mError
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        NText {
                            visible: (main?.available ?? false) && (main?.activeSession ?? "") !== ""
                            text: (pluginApi?.tr("panel.active_session") ?? "Active session ID") + ": " + (main?.activeSession ?? "")
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            visible: (main?.available ?? false) && (main?.screenOff ?? false)
                            text: pluginApi?.tr("panel.screen_off") ?? "Screen off"
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            visible: (main?.available ?? false) && (main?.cpuFreqMhz ?? -1) >= 0
                            text: (pluginApi?.tr("panel.cpu_freq") ?? "CPU freq") + ": " + (main?.cpuFreqMhz ?? 0) + " MHz"
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }
                    }

                    // Battery card
                    Card {
                        visible: main?.batteryPresent ?? false
                        headerIcon: (main?.batteryStatus === "charging") ? "battery-charging" : "battery"
                        headerIconColor: {
                            var pct = main?.batteryPercent ?? -1
                            var s = main?.batteryStatus ?? ""
                            if (s === "charging" || s === "full") return Color.mPrimary
                            if (pct >= 0 && pct <= 10) return Color.mError
                            return Color.mPrimary
                        }
                        title: {
                            var pct = main?.batteryPercent ?? -1
                            var s = main?.batteryStatus ?? ""
                            var label = pluginApi?.tr("panel.battery") ?? "Battery"
                            if (pct >= 0) label += " — " + pct + "%"
                            return label
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

                    // Idle timers card
                    Card {
                        visible: main?.available ?? false
                        headerIcon: "clock"
                        headerIconColor: (main?.inhibited ?? false) ? Color.mError : Color.mPrimary
                        title: pluginApi?.tr("panel.idle_timers") ?? "Idle Timers"

                        NText {
                            text: (pluginApi?.tr("panel.dim_in") ?? "Dim in") + ": " + root.timeLeftText(main?.dimInSec ?? -1, main?.dimInhibited ?? false)
                            pointSize: Style.fontSizeXS
                            color: (main?.dimInhibited ?? false) ? Color.mError : Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            text: (pluginApi?.tr("panel.screen_off_in") ?? "Screen off in") + ": " + root.timeLeftText(main?.screenOffInSec ?? -1, main?.screenOffInhibited ?? false)
                            pointSize: Style.fontSizeXS
                            color: (main?.screenOffInhibited ?? false) ? Color.mError : Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            text: (pluginApi?.tr("panel.sleep_in") ?? "Sleep in") + ": " + root.timeLeftText(main?.sleepInSec ?? -1, main?.sleepInhibited ?? false)
                            pointSize: Style.fontSizeXS
                            color: (main?.sleepInhibited ?? false) ? Color.mError : Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            text: (pluginApi?.tr("panel.lock_in") ?? "Lock in") + ": " + root.lockInText(main?.lockInSec ?? -1, main?.lockInhibited ?? false, main?.lockOnScreenOff ?? false)
                            pointSize: Style.fontSizeXS
                            color: (main?.lockInhibited ?? false) ? Color.mError : Color.mOnSurface
                            Layout.fillWidth: true
                        }
                    }

                    // Inhibitors card
                    Card {
                        visible: (main?.available ?? false) && (main?.inhibitors?.length ?? 0) > 0
                        headerIcon: "hand"
                        headerIconColor: Color.mError
                        title: pluginApi?.tr("panel.inhibitors") ?? "Inhibitors"

                        Repeater {
                            model: main?.inhibitors ?? []
                            delegate: NText {
                                required property string modelData
                                text: modelData
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurface
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Profiles card
                    Card {
                        visible: (main?.available ?? false) && (main?.profiles?.length ?? 0) > 0
                        headerIcon: "bolt-off"
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

                // Manual inhibit toggle
                NButton {
                    Layout.fillWidth: true
                    visible: main?.available ?? false
                    text: (main?.manualInhibitActive ?? false)
                        ? (pluginApi?.tr("panel.uninhibit") ?? "Uninhibit")
                        : (pluginApi?.tr("panel.inhibit") ?? "Inhibit")
                    icon: "hand"
                    backgroundColor: (main?.manualInhibitActive ?? false) ? Color.mError : Color.mSurface
                    textColor: (main?.manualInhibitActive ?? false) ? Color.mOnError : Color.mOnSurface
                    onClicked: main?.toggleManualInhibit()
                }

                // Lock now button
                NButton {
                    Layout.fillWidth: true
                    visible: main?.available ?? false
                    text: pluginApi?.tr("panel.lock_now") ?? "Lock now"
                    icon: "lock"
                    onClicked: main?.lock()
                }

                // Refresh button
                NButton {
                    Layout.fillWidth: true
                    text: pluginApi?.tr("panel.refresh") ?? "Refresh"
                    icon: "rotate"
                    onClicked: main?.refreshStatus()
                }
            }
        }
    }
}
