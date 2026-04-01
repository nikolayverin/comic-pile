.pragma library

.import "AppText.js" as AppText
.import "AppMessagePayload.js" as AppMessagePayload

function normalizedText(value) {
    return String(value || "").trim()
}

function defaultActionResultPayload(message, titleOverride, detailsText, buttonText, actionKey, filePath) {
    return AppMessagePayload.payload({
        title: normalizedText(titleOverride) || AppText.popupActionErrorTitle,
        body: normalizedText(message) || "Unknown error.",
        details: normalizedText(detailsText),
        actionLabel: normalizedText(buttonText),
        actionKey: normalizedText(actionKey),
        filePath: normalizedText(filePath),
        severity: "error"
    })
}

function lowerText(value) {
    return normalizedText(value).toLowerCase()
}

function isArchiveUnavailableMessage(message) {
    const text = lowerText(message)
    return text.indexOf("not found") >= 0
        || text.indexOf("no longer available") >= 0
        || text.indexOf("archive path is empty") >= 0
}

function readerActionDetails(message) {
    if (isArchiveUnavailableMessage(message)) {
        return "Close the reader, reload the library, and make sure the issue file is still available on disk."
    }

    return "Close the reader and try again. If the problem continues, reload the library and verify that the issue file is still available on disk."
}

function readerActionResult(message) {
    return defaultActionResultPayload(
        message,
        isArchiveUnavailableMessage(message)
            ? AppText.popupIssueArchiveUnavailableTitle
            : AppText.popupActionErrorTitle,
        readerActionDetails(message),
        "",
        "",
        ""
    )
}

function navigationResult(title, message) {
    return defaultActionResultPayload(
        message,
        title,
        "",
        "",
        "",
        ""
    )
}

function libraryLoadFailure(message) {
    return defaultActionResultPayload(
        message,
        "Library load failed",
        "Check the library data location in Settings and try reloading the library.",
        "Open Settings",
        "open_library_data_settings",
        ""
    )
}

function deleteReaderPageFailure(message) {
    return defaultActionResultPayload(
        message,
        "Couldn't delete page",
        "",
        "",
        "",
        ""
    )
}
