import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: styleTokens.comicVineApiKeyWidth
    readonly property int availableDialogHeight: hostHeight > 0
        ? hostHeight - 80
        : styleTokens.comicVineApiKeyMinHeight
    height: Math.min(
        availableDialogHeight,
        Math.max(styleTokens.comicVineApiKeyMinHeight, comicVineLayout.implicitHeight)
    )

    property var libraryModelRef: null
    property int validationRequestId: -1
    property bool checking: false
    property string verifiedKey: ""
    property string statusText: ""
    property string statusKind: ""
    property bool previewMode: false

    readonly property bool checkPending: statusKind === "pending"
    readonly property bool verifiedCurrentValue: verifiedKey.length > 0
        && verifiedKey === String(apiKeyField.text || "").trim()
    readonly property bool canSave: verifiedCurrentValue && !checkPending

    PopupStyle { id: styleTokens }

    popupStyle: styleTokens
    title: "Configure ComicVine API Key"

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: dialog.visible
        onActivated: dialog.close()
    }

    function resetValidationState(preserveStatus) {
        checking = false
        verifiedKey = ""
        validationRequestId = -1
        validationTimeout.stop()
        statusKind = preserveStatus ? statusKind : ""
        statusText = preserveStatus ? statusText : ""
    }

    function openDialog() {
        previewMode = false
        const existingKey = libraryModelRef && typeof libraryModelRef.configuredComicVineApiKey === "function"
            ? String(libraryModelRef.configuredComicVineApiKey() || "")
            : ""
        apiKeyField.text = existingKey
        checking = false
        validationRequestId = -1
        verifiedKey = ""
        validationTimeout.stop()
        statusKind = ""
        statusText = ""
        open()
    }

    function openPreview() {
        previewMode = true
        apiKeyField.text = "0123456789abcdef-preview"
        checking = false
        validationRequestId = -1
        verifiedKey = String(apiKeyField.text || "").trim()
        validationTimeout.stop()
        statusKind = "success"
        statusText = "ComicVine API key verified."
        open()
    }

    function requestCheck() {
        if (previewMode) {
            checking = false
            validationRequestId = -1
            verifiedKey = String(apiKeyField.text || "").trim()
            statusKind = "success"
            statusText = "ComicVine API key verified."
            return
        }
        const candidate = String(apiKeyField.text || "").trim()
        if (candidate.length < 1) {
            resetValidationState(false)
            statusKind = "error"
            statusText = "Enter a ComicVine API key."
            return
        }
        if (!libraryModelRef || typeof libraryModelRef.requestComicVineApiKeyValidationAsync !== "function") {
            resetValidationState(false)
            statusKind = "error"
            statusText = "ComicVine service is unavailable."
            return
        }
        checking = true
        verifiedKey = ""
        statusKind = "pending"
        statusText = "Checking ComicVine API key..."
        validationRequestId = Number(libraryModelRef.requestComicVineApiKeyValidationAsync(candidate) || 0)
        validationTimeout.restart()
    }

    function saveCurrentKey() {
        if (previewMode) {
            close()
            return
        }
        if (!canSave) return
        if (!libraryModelRef || typeof libraryModelRef.saveComicVineApiKey !== "function") {
            statusKind = "error"
            statusText = "ComicVine service is unavailable."
            return
        }
        const saveError = String(libraryModelRef.saveComicVineApiKey(String(apiKeyField.text || "").trim()) || "")
        if (saveError.length > 0) {
            statusKind = "error"
            statusText = saveError
            return
        }
        close()
    }

    function handleValidationResult(requestId, result) {
        if (Number(requestId) !== validationRequestId) return
        checking = false
        validationRequestId = -1
        validationTimeout.stop()
        const ok = Boolean(result && result.ok)
        if (ok) {
            verifiedKey = String(apiKeyField.text || "").trim()
            statusKind = "success"
            statusText = String(result.message || "ComicVine API key verified.")
            return
        }
        verifiedKey = ""
        statusKind = "error"
        statusText = String((result && result.error) || "ComicVine API key verification failed.")
    }

    onCloseRequested: dialog.close()

    onClosed: {
        previewMode = false
    }

    Timer {
        id: validationTimeout
        interval: 22000
        repeat: false
        onTriggered: {
            dialog.checking = false
            dialog.validationRequestId = -1
            dialog.verifiedKey = ""
            dialog.statusKind = "error"
            dialog.statusText = "ComicVine API key validation timed out."
        }
    }

    PopupBodyColumn {
        id: comicVineLayout
        popupStyle: styleTokens
        spacing: styleTokens.dialogContentSpacing

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: styleTokens.textColor
            font.pixelSize: styleTokens.dialogBodyFontSize
            text: "Enter your ComicVine API key below to enable metadata auto-fill."
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: styleTokens.dialogControlRowSpacing

            PopupTextField {
                id: apiKeyField
                Layout.fillWidth: true
                Layout.preferredHeight: styleTokens.fieldHeight
                leftPadding: styleTokens.fieldPadX
                rightPadding: styleTokens.fieldPadX
                font.pixelSize: styleTokens.dialogBodyFontSize
                color: styleTokens.textColor
                echoMode: TextInput.Password
                verticalAlignment: TextInput.AlignVCenter
                placeholderText: "Paste ComicVine API key"
                cornerRadius: styleTokens.fieldRadius
                fillColor: styleTokens.fieldFillColor
                onTextChanged: {
                    const normalized = String(text || "").trim()
                    if (normalized !== dialog.verifiedKey) {
                        dialog.checking = false
                        dialog.validationRequestId = -1
                        dialog.validationTimeout.stop()
                        dialog.verifiedKey = ""
                        dialog.statusKind = ""
                        dialog.statusText = ""
                    }
                }
            }

            Rectangle {
                id: checkButton
                Layout.preferredWidth: styleTokens.comicVineCheckButtonWidth
                Layout.preferredHeight: styleTokens.footerButtonHeight
                radius: styleTokens.footerButtonRadius
                color: dialog.checkPending ? styleTokens.footerButtonHoverColor : styleTokens.footerButtonIdleColor
                border.width: 0

                BusyIndicator {
                    anchors.centerIn: parent
                    width: styleTokens.comicVineStatusIndicatorSize
                    height: styleTokens.comicVineStatusIndicatorSize
                    running: dialog.checkPending
                    visible: dialog.checkPending
                }

                Text {
                    anchors.centerIn: parent
                    visible: dialog.checkPending
                    text: "..."
                    color: styleTokens.textColor
                    font.pixelSize: styleTokens.footerButtonTextSize
                }

                Text {
                    anchors.centerIn: parent
                    visible: !dialog.checkPending && !dialog.verifiedCurrentValue
                    text: "Check"
                    color: styleTokens.textColor
                    font.pixelSize: styleTokens.footerButtonTextSize
                }

                Text {
                    anchors.centerIn: parent
                    visible: !dialog.checkPending && dialog.verifiedCurrentValue
                    text: "\u2713"
                    color: "#44c267"
                    font.pixelSize: styleTokens.comicVineVerifiedGlyphSize
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !dialog.checkPending
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: checkButton.color = styleTokens.footerButtonHoverColor
                    onExited: checkButton.color = styleTokens.footerButtonIdleColor
                    onClicked: dialog.requestCheck()
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: dialog.statusText.length > 0
            wrapMode: Text.WordWrap
            color: dialog.statusKind === "success"
                ? "#44c267"
                : dialog.statusKind === "error"
                    ? "#b91c1c"
                    : styleTokens.hintTextColor
            font.pixelSize: styleTokens.dialogHintFontSize
            text: dialog.statusText
        }

        PopupFooterRow {
            Layout.fillWidth: true
            horizontalPadding: styleTokens.footerSideMargin
            spacing: styleTokens.footerButtonSpacing

            PopupActionButton {
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: "Save"
                enabled: dialog.canSave
                onClicked: dialog.saveCurrentKey()
            }

            PopupActionButton {
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: "Cancel"
                onClicked: dialog.close()
            }
        }
    }
}


