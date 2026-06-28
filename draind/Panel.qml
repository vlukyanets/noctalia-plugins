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

            // Profiles card
            Card {
                visible: (main?.available ?? false) && (main?.profiles?.length ?? 0) > 0
                headerIcon: "zap-off"
                headerIconColor: Color.mPrimary
                title: pluginApi?.tr("panel.profiles") ?? "Power Profiles"

                Repeater {
                    model: main?.profiles ?? []
                    delegate: NButton {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        text: modelData
                        icon: modelData.toLowerCase() === "performance" ? "zap"
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
