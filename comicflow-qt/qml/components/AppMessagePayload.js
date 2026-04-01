.pragma library

.import "AppText.js" as AppText

function normalizedText(value) {
    return String(value || "").trim()
}

function normalizedSeverity(value) {
    const normalized = normalizedText(value).toLowerCase()
    if (normalized === "info" || normalized === "warning" || normalized === "success") {
        return normalized
    }
    return "error"
}

function payload(input) {
    const source = input && typeof input === "object" ? input : {}
    const title = normalizedText(source.title) || AppText.popupActionErrorTitle
    const body = normalizedText(source.body || source.message) || "Unknown error."
    const details = normalizedText(source.details || source.detailsText)
    const systemText = normalizedText(source.systemText)
    const actionKey = normalizedText(source.actionKey)
    const filePath = normalizedText(source.filePath)
    const primaryPath = normalizedText(source.primaryPath || filePath)
    const actionLabel = (actionKey.length > 0 || filePath.length > 0)
        ? normalizedText(source.actionLabel || source.buttonText)
        : ""

    return {
        title: title,
        body: body,
        details: details,
        systemText: systemText,
        severity: normalizedSeverity(source.severity),
        actionLabel: actionLabel,
        actionKey: actionKey,
        filePath: filePath,
        primaryPath: primaryPath,
        rawText: normalizedText(source.rawText),

        // Compatibility fields for existing popup surfaces.
        message: body,
        detailsText: details,
        buttonText: actionLabel
    }
}
