import QtQuick
import QtQuick.Controls
import "AppText.js" as AppText

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

    primaryButtonText: AppText.t("commonDelete", dialog.textLanguage)
    secondaryButtonText: AppText.t("commonCancel", dialog.textLanguage)

    onSecondaryRequested: cancelConfirmed()
    onPrimaryRequested: {
        dialog.close()
        dialog.deleteRequested()
    }
}
