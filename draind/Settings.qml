import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null

    readonly property var main: pluginApi?.mainInstance

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property int valueRefreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 5000
    property string valueCtlPath: cfg.ctlPath ?? defaults.ctlPath ?? "draind-ctl"

    spacing: Style.marginM

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.refreshInterval = valueRefreshInterval
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

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        Layout.bottomMargin: Style.marginM
    }

    NButton {
        Layout.fillWidth: true
        text: pluginApi?.tr("panel.reload_config") ?? "Reload config"
        icon: "rotate"
        onClicked: root.main?.reloadConfig()
    }

    Item { Layout.fillHeight: true }
}
