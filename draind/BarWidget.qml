import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
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
    readonly property bool compactMode: cfg.compactMode ?? defaults.compactMode ?? false

    function profileIcon(p) {
        if (!p || p === "") return "battery"
        var n = p.toLowerCase()
        if (n === "performance") return "zap"
        if (n === "powersave" || n === "power-save") return "leaf"
        return "battery"
    }

    icon: main?.available
        ? (main.dimmed ? "moon" : profileIcon(main.profile))
        : "battery-warning"

    tooltipText: main?.available
        ? (main.dimmed ? pluginApi?.tr("panel.dimmed") : main.profile)
        : pluginApi?.tr("panel.unavailable")
    tooltipDirection: BarService.getTooltipDirection(screen?.name)

    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    customRadius: Style.radiusL
    colorBg: Style.capsuleColor
    colorFg: Color.mOnSurface
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    onClicked: {
        if (pluginApi) pluginApi.openPanel(root.screen, this)
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

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen)
    }
}
