import QtQuick
import QtQuick.Controls

QtObject {
    id: root

    property int closePolicy: Popup.NoAutoClose

    readonly property bool closeOnEscape: Boolean(closePolicy & Popup.CloseOnEscape)
    readonly property bool closeOnOutside: Boolean(closePolicy & Popup.CloseOnPressOutside)
        || Boolean(closePolicy & Popup.CloseOnPressOutsideParent)
}
