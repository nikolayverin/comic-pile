import QtQuick
import QtQuick.Controls
import "AppText.js" as AppText

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

    primaryButtonText: AppText.t("commonDelete", dialog.textLanguage)
    secondaryButtonText: AppText.t("commonCancel", dialog.textLanguage)

    onSecondaryRequested: close()
    onPrimaryRequested: {
        dialog.close()
        dialog.deleteRequested()
    }
}
