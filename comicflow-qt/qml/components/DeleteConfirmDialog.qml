import QtQuick
import QtQuick.Controls

PopupConfirmDialog {
    id: dialog

    signal deleteRequested()

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    title: "Delete Archive File"
    dialogWidth: styleTokens.deleteConfirmWidth
    minimumDialogHeight: styleTokens.deleteConfirmMinHeight
    messageText: "Delete archive file from database?"

    primaryButtonText: "Delete"
    secondaryButtonText: "Cancel"

    onSecondaryRequested: close()
    onPrimaryRequested: {
        dialog.close()
        dialog.deleteRequested()
    }
}
