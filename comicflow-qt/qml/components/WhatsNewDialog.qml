import QtQuick
import QtQuick.Controls

PopupDialogWindow {
    id: dialog

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    debugName: "whats-new-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    title: "What's new"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: 434
    height: 620

    onCloseRequested: close()
}
