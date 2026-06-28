import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property int valueRefreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 5000
    property bool valueCompactMode: cfg.compactMode ?? defaults.compactMode ?? false
    property string valueCtlPath: cfg.ctlPath ?? defaults.ctlPath ?? "draind-ctl"

    spacing: Style.marginM

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.refreshInterval = valueRefreshInterval
        pluginApi.pluginSettings.compactMode = valueCompactMode
        pluginApi.pluginSettings.ctlPath = valueCtlPath
        pluginApi.saveSettings()
    }

    NLabel {
        label: pluginApi?.tr("settings.refresh_interval.label") ?? "Refresh interval"
        description: (pluginApi?.tr("settings.refresh_interval.description") ?? "") + " (" + root.valueRefreshInterval + " ms)"
    }

    NSlider {
        Layout.fillWidth: true
        from: 1000
        to: 30000
        stepSize: 1000
        value: root.valueRefreshInterval
        onValueChanged: {
            root.valueRefreshInterval = value
            root.saveSettings()
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        Layout.bottomMargin: Style.marginM
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.compact_mode.label") ?? "Compact mode"
        description: pluginApi?.tr("settings.compact_mode.description") ?? ""
        checked: root.valueCompactMode
        onToggled: checked => {
            root.valueCompactMode = checked
            root.saveSettings()
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        Layout.bottomMargin: Style.marginM
    }

    NLabel {
        label: pluginApi?.tr("settings.ctl_path.label") ?? "draind-ctl path"
        description: pluginApi?.tr("settings.ctl_path.description") ?? ""
    }

    NTextInput {
        Layout.fillWidth: true
        text: root.valueCtlPath
        onEditingFinished: {
            root.valueCtlPath = text
            root.saveSettings()
        }
    }

    Item { Layout.fillHeight: true }
}
