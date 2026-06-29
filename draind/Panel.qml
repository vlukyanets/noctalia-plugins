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
    property real contentPreferredHeight: 380 * Style.uiScaleRatio
    readonly property bool allowAttach: true
    anchors.fill: parent

    readonly property var main: pluginApi?.mainInstance

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

            Item { Layout.fillHeight: true }

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
