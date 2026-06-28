import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    default property alias content: contentArea.children
    property string headerIcon: ""
    property color headerIconColor: Color.mPrimary
    property string title: ""

    Layout.fillWidth: true
    implicitHeight: outerCol.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant
    radius: Style.radiusM

    data: [
        ColumnLayout {
            id: outerCol
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                margins: Style.marginM
            }
            spacing: Style.marginS

            RowLayout {
                spacing: Style.marginS

                NIcon {
                    visible: root.headerIcon !== ""
                    icon: root.headerIcon
                    color: root.headerIconColor
                    pointSize: Style.fontSizeS
                }

                NText {
                    text: root.title
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                id: contentArea
                Layout.fillWidth: true
                width: outerCol.width
                spacing: Style.marginXS
            }
        }
    ]
}
