import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property var main: pluginApi?.mainInstance

    function levelIcon(pct, status) {
        if (status === "charging") return "battery-charging"
        if (pct < 0) return "battery"
        if (pct <= 10) return "battery-exclamation"
        if (pct <= 35) return "battery-1"
        if (pct <= 60) return "battery-2"
        if (pct <= 80) return "battery-3"
        return "battery-4"
    }

    readonly property bool batteryAvailable: (main?.available ?? false) && (main?.batteryPresent ?? false)
    readonly property string _levelIcon:  batteryAvailable
        ? levelIcon(main.batteryPercent, main.batteryStatus)
        : (main?.available ?? false) ? "bolt" : "alert-circle-off"

    readonly property real iconSize: Style.getCapsuleHeightForScreen(screen?.name)

    implicitWidth:  iconSize
    implicitHeight: iconSize

    Rectangle {
        id: capsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width:  parent.implicitWidth
        height: parent.implicitHeight
        color:  mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius: Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        Behavior on color {
            enabled: !Color.isTransitioning
            ColorAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
        }

        NIcon {
            anchors.centerIn: parent
            icon: root._levelIcon
            pointSize: Style.toOdd(root.iconSize * 0.48)
            applyUiScale: false
            color: {
                if (mouseArea.containsMouse) return Color.mOnHover
                var s = main?.batteryStatus ?? ""
                if (s === "charging") return Color.mPrimary
                if (s === "discharging" && (main?.batteryPercent ?? 100) <= 10) return Color.mError
                return Color.mOnSurface
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: {
            var tip = barTooltip()
            if (tip) TooltipService.show(root, tip, BarService.getTooltipDirection(screen?.name))
        }
        onExited: TooltipService.hide(root)

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (pluginApi) pluginApi.openPanel(root.screen, root)
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen)
            }
        }
    }

    function barTooltip() {
        if (!main?.available) return pluginApi?.tr("panel.unavailable") ?? "Daemon unavailable"
        if (main.dimmed) return pluginApi?.tr("panel.dimmed") ?? "Dimmed"
        if (main.batteryPresent) {
            var s = main.batteryStatus
            var pct = main.batteryPercent >= 0 ? " " + main.batteryPercent + "%" : ""
            if (main.batteryTimeToEmpty >= 0) {
                var h = Math.floor(main.batteryTimeToEmpty / 60)
                var m = main.batteryTimeToEmpty % 60
                return s + pct + " — " + h + "h " + m + "m remaining"
            }
            if (main.batteryTimeToFull >= 0) {
                var h2 = Math.floor(main.batteryTimeToFull / 60)
                var m2 = main.batteryTimeToFull % 60
                return s + pct + " — " + h2 + "h " + m2 + "m to full"
            }
            return s + pct
        }
        return main.profile
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            {
                "label": pluginApi?.tr("context.settings") ?? "Settings",
                "action": "settings",
                "icon": "settings"
            }
        ]
        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "settings") {
                BarService.openPluginSettings(root.screen, pluginApi.manifest)
            }
        }
    }
}
