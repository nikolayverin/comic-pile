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
    title: AppText.t("deleteArchiveTitle", dialog.textLanguage)
    dialogWidth: styleTokens.deleteConfirmWidth
    minimumDialogHeight: styleTokens.deleteConfirmMinHeight
    messageText: AppText.t("deleteArchiveMessage", dialog.textLanguage)

    primaryButtonText: AppText.t("commonDelete", dialog.textLanguage)
    secondaryButtonText: AppText.t("commonCancel", dialog.textLanguage)

    onSecondaryRequested: close()
    onPrimaryRequested: {
        dialog.close()
        dialog.deleteRequested()
    }
}
