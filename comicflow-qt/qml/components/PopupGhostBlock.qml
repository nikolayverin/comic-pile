import QtQuick
import QtQuick.Layouts

Item {
    id: root

    ThemeColors { id: themeColors }

    property real contentOpacity: 0.3
    property real spacing: 0
    property color fadeColor: themeColors.popupFillColor
    default property alias contentData: contentColumn.data

    implicitWidth: contentColumn.implicitWidth
    implicitHeight: contentColumn.implicitHeight
    clip: true

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: root.spacing
        opacity: root.contentOpacity
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0.0)
            }
            GradientStop {
                position: 1.0
                color: root.fadeColor
            }
        }
    }
}
