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

    property int valueHeartbeatInterval: cfg.heartbeatInterval ?? defaults.heartbeatInterval ?? 20000
    property string valueCtlPath: cfg.ctlPath ?? defaults.ctlPath ?? "ampered-ctl"

    spacing: Style.marginM

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.heartbeatInterval = valueHeartbeatInterval
        pluginApi.pluginSettings.ctlPath = valueCtlPath
        pluginApi.saveSettings()
    }

    NLabel {
        label: pluginApi?.tr("settings.heartbeat_interval.label") ?? "Heartbeat interval"
        description: (pluginApi?.tr("settings.heartbeat_interval.description") ?? "") + " (" + root.valueHeartbeatInterval + " ms)"
    }

    NSlider {
        Layout.fillWidth: true
        from: 5000
        to: 60000
        stepSize: 5000
        value: root.valueHeartbeatInterval
        onValueChanged: {
            root.valueHeartbeatInterval = value
            root.saveSettings()
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginM
        Layout.bottomMargin: Style.marginM
    }

    NLabel {
        label: pluginApi?.tr("settings.ctl_path.label") ?? "ampered-ctl path"
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
