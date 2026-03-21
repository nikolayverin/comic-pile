import QtQuick
import QtQuick.Controls

PopupConfirmDialog {
    id: dialog

    property string questionText: ""

    signal cancelConfirmed()
    signal deleteRequested()

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    title: "Delete Series Files"
    dialogWidth: styleTokens.seriesDeleteWidth
    minimumDialogHeight: styleTokens.seriesDeleteHeight
    messageText: dialog.questionText
    messageTextFormat: Text.RichText

    primaryButtonText: "Delete"
    secondaryButtonText: "Cancel"

    onSecondaryRequested: cancelConfirmed()
    onPrimaryRequested: {
        dialog.close()
        dialog.deleteRequested()
    }
}
