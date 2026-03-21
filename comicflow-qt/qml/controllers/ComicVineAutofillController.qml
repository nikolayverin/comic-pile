import QtQuick

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var libraryModelRef: null
    property var metadataDialog: null
    property var seriesMetadataDialog: null
    property var seriesMetaSeriesField: null
    property var seriesMetaTitleField: null
    property var seriesMetaVolumeField: null
    property var seriesMetaPublisherField: null
    property var seriesMetaYearField: null
    property var seriesMetaMonthCombo: null
    property var seriesMetaAgeRatingCombo: null
    property var seriesMetaSummaryField: null
    property var seriesMetaMonthOptions: []
    property var seriesMetaAgeRatingOptions: []
    property var editingComic: null
    property var editingSeriesKeys: []
    property bool importInProgress: false

    property int cooldownSeconds: 60
    property int cooldownRemaining: 0
    property bool busy: false
    property string scope: ""
    property int requestId: -1
    property int targetComicId: -1
    property int leadIssueId: -1
    property string targetSeriesKey: ""
    property bool seriesBlockedByData: false
    property string seriesBlockedReason: ""
    property string issueAutofillAttemptSeed: ""
    property string seriesAutofillAttemptSeed: ""

    readonly property bool coolingDown: cooldownRemaining > 0
    readonly property string statusText: busy
        ? "Metadata API: requesting..."
        : (coolingDown ? "Metadata API: cooldown" : "")

    signal issuesGridRefreshRequested(bool preserveSelection)

    function startCooldown() {
        const seconds = Math.max(0, Number(cooldownSeconds || 0))
        if (seconds < 1) return
        cooldownRemaining = seconds
        cooldownTimer.restart()
    }

    function canRun() {
        return !busy && cooldownRemaining < 1
    }

    function isFilledText(value) {
        return String(value || "").trim().length > 0
    }

    function isPositiveNumber(value) {
        return Number(value || 0) > 0
    }

    function isIssueMetadataCoreComplete(data) {
        const src = data || {}
        return isFilledText(src.series)
            && isFilledText(src.issueNumber || src.issue)
            && isFilledText(src.title)
            && isFilledText(src.publisher)
            && isPositiveNumber(src.year)
            && isPositiveNumber(src.month)
    }

    function issueBlockedByData() {
        return metadataDialog ? isIssueMetadataCoreComplete(metadataDialog.currentState()) : false
    }

    function issueHasMinimumAutofillSeed(data) {
        const src = data || {}
        return isFilledText(src.series)
            && isFilledText(src.issueNumber || src.issue)
            && isPositiveNumber(src.year)
    }

    function issueAutofillSeedSignature(data) {
        const src = data || {}
        return String(src.series || "").trim().toLowerCase()
            + "|"
            + String(src.issueNumber || src.issue || "").trim().toLowerCase()
            + "|"
            + String(src.year || "").trim()
    }

    function issueManualLookupHint() {
        return "For manual metadata lookup, check ComicVine, League of Comic Geeks, Grand Comics Database, or publisher pages."
    }

    function issueCanRequestAutofill() {
        const draft = metadataDialog ? metadataDialog.currentState() : {}
        return !importInProgress
            && !busy
            && !coolingDown
            && !issueBlockedByData()
            && issueHasMinimumAutofillSeed(draft)
    }

    function seriesHasMinimumAutofillSeed() {
        return isFilledText(seriesMetaSeriesField ? seriesMetaSeriesField.text : "")
            && isPositiveNumber(seriesMetaYearField ? seriesMetaYearField.text : "")
    }

    function seriesAutofillSeedSignature() {
        return String(seriesMetaSeriesField ? seriesMetaSeriesField.text : "").trim().toLowerCase()
            + "|"
            + String(seriesMetaYearField ? seriesMetaYearField.text : "").trim()
    }

    function seriesCanRequestAutofill() {
        return !importInProgress
            && !busy
            && !coolingDown
            && !seriesBlockedByData
            && seriesHasMinimumAutofillSeed()
    }

    function issueLockReason() {
        if (importInProgress) return "Auto-fill is disabled while import is running."
        if (busy) return "Another metadata request is in progress."
        if (coolingDown) return "Auto-fill is temporarily disabled to protect API limits."
        if (issueBlockedByData()) return "This issue already has core metadata in the library."
        return "To use auto-fill, add the minimum metadata: series, issue, year."
    }

    function recomputeSeriesAutofillBlockState() {
        const keys = Array.isArray(editingSeriesKeys) ? editingSeriesKeys.filter(function(k) {
            return String(k || "").trim().length > 0
        }) : []
        if (keys.length !== 1) {
            seriesBlockedByData = true
            seriesBlockedReason = "Auto-fill is available only for one series at a time."
            return
        }

        if (!libraryModelRef || typeof libraryModelRef.issuesForSeries !== "function") {
            seriesBlockedByData = true
            seriesBlockedReason = "Library model is unavailable."
            return
        }

        const rows = libraryModelRef.issuesForSeries(String(keys[0] || ""), "__all__", "all", "")
        if (!rows || rows.length < 1) {
            seriesBlockedByData = true
            seriesBlockedReason = "No issues found for this series."
            return
        }

        let allComplete = true
        for (let i = 0; i < rows.length; i += 1) {
            if (!isIssueMetadataCoreComplete(rows[i] || {})) {
                allComplete = false
                break
            }
        }
        seriesBlockedByData = allComplete
        seriesBlockedReason = allComplete
            ? "All issues in this series already have core metadata."
            : ""
    }

    function clearSeriesAutofillBlockState() {
        seriesBlockedByData = false
        seriesBlockedReason = ""
    }

    function seriesLockReason() {
        if (importInProgress) return "Auto-fill is disabled while import is running."
        if (busy) return "Another metadata request is in progress."
        if (coolingDown) return "Auto-fill is temporarily disabled to protect API limits."
        if (seriesBlockedReason.length > 0) return seriesBlockedReason
        return "To use auto-fill, add the minimum metadata: series, year."
    }

    function issueButtonLabel() {
        if (busy && scope === "issue") return "Auto-fill..."
        if (coolingDown) return "Auto-fill (wait)"
        const currentDraft = metadataDialog ? metadataDialog.currentState() : {}
        if (issueAutofillAttemptSeed.length > 0
            && issueAutofillSeedSignature(currentDraft) === issueAutofillAttemptSeed) {
            return "Retry auto-fill"
        }
        return "Auto-fill"
    }

    function seriesButtonLabel() {
        if (busy && scope === "series") return "Auto-fill..."
        if (coolingDown) return "Auto-fill (wait)"
        if (seriesAutofillAttemptSeed.length > 0
            && seriesAutofillSeedSignature() === seriesAutofillAttemptSeed) {
            return "Retry auto-fill"
        }
        return "Auto-fill"
    }

    function monthNameFromNumber(monthNumber) {
        const month = Math.max(0, Number(monthNumber || 0))
        if (month < 1 || month > seriesMetaMonthOptions.length) return ""
        return String(seriesMetaMonthOptions[month - 1] || "")
    }

    function monthNumberFromName(monthName) {
        const target = String(monthName || "").trim()
        const index = Array.isArray(seriesMetaMonthOptions)
            ? seriesMetaMonthOptions.indexOf(target)
            : -1
        return index >= 0 ? index + 1 : 0
    }

    function resetRequestState() {
        busy = false
        scope = ""
        requestId = -1
        targetComicId = -1
        leadIssueId = -1
        targetSeriesKey = ""
    }

    function clearIssueAutofillAttemptState() {
        issueAutofillAttemptSeed = ""
    }

    function clearSeriesAutofillAttemptState() {
        seriesAutofillAttemptSeed = ""
    }

    function requestIssueAutofill(draftState) {
        if (!editingComic) {
            if (metadataDialog) metadataDialog.errorText = "Nothing selected."
            return
        }
        if (issueBlockedByData()) {
            if (metadataDialog) metadataDialog.errorText = "This issue already has core metadata."
            return
        }
        if (!canRun()) {
            if (metadataDialog) metadataDialog.errorText = "Metadata API cooldown is active. Try again in a moment."
            return
        }

        const draft = draftState || (metadataDialog ? metadataDialog.currentState() : {})
        const series = String(draft.series || "").trim()
        const issue = String(draft.issueNumber || draft.issue || "").trim()
        const yearValue = Number(draft.year || 0)
        if (series.length < 1 || issue.length < 1 || yearValue < 1) {
            if (metadataDialog) {
                metadataDialog.errorText = ""
                metadataDialog.setAutofillStatus("To use auto-fill, add the minimum metadata: series, issue, year.", "hint")
            }
            return
        }
        if (!libraryModelRef || typeof libraryModelRef.requestComicVineAutofillAsync !== "function") {
            if (metadataDialog) metadataDialog.errorText = "Library model is unavailable."
            return
        }

        if (metadataDialog) {
            metadataDialog.errorText = ""
            metadataDialog.setAutofillStatus("Requesting metadata from ComicVine...", "pending")
        }
        busy = true
        scope = "issue"
        targetComicId = Number((editingComic || {}).id || 0)
        leadIssueId = -1
        targetSeriesKey = ""
        issueAutofillAttemptSeed = issueAutofillSeedSignature(draft)
        startCooldown()
        requestId = Number(libraryModelRef.requestComicVineAutofillAsync(draft) || 0)
    }

    function requestSeriesAutofill() {
        if (seriesBlockedByData) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = ""
                seriesMetadataDialog.setAutofillStatus(
                    seriesBlockedReason.length > 0
                        ? seriesBlockedReason
                        : "Series metadata is already complete.",
                    "hint"
                )
            }
            return
        }
        if (!canRun()) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = ""
                seriesMetadataDialog.setAutofillStatus("Metadata API cooldown is active. Try again in a moment.", "hint")
            }
            return
        }

        const keys = Array.isArray(editingSeriesKeys) ? editingSeriesKeys.filter(function(k) {
            return String(k || "").trim().length > 0
        }) : []
        if (keys.length !== 1) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = ""
                seriesMetadataDialog.setAutofillStatus("Auto-fill is available only for one series at a time.", "hint")
            }
            return
        }
        if (!libraryModelRef || typeof libraryModelRef.issuesForSeries !== "function") {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = "Library model is unavailable."
            }
            return
        }

        const targetKey = String(keys[0] || "")
        const rows = libraryModelRef.issuesForSeries(targetKey, "__all__", "all", "")
        if (!rows || rows.length < 1) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = ""
                seriesMetadataDialog.setAutofillStatus("No issues found for selected series.", "error")
            }
            return
        }

        const leadId = Number((rows[0] || {}).id || 0)
        if (leadId < 1) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = "Lead issue is unavailable for metadata sync."
            }
            return
        }

        const leadIssueNumber = String((rows[0] || {}).issueNumber || "").trim()
        if (leadIssueNumber.length < 1) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = ""
                seriesMetadataDialog.setAutofillStatus("Series auto-fill requires at least one issue with a valid issue number.", "hint")
            }
            return
        }

        const seed = {
            series: String(seriesMetaSeriesField ? seriesMetaSeriesField.text : "").trim(),
            issueNumber: leadIssueNumber,
            publisher: String(seriesMetaPublisherField ? seriesMetaPublisherField.text : "").trim(),
            year: String(seriesMetaYearField ? seriesMetaYearField.text : "").trim(),
            month: monthNumberFromName(seriesMetaMonthCombo ? seriesMetaMonthCombo.currentText : ""),
            summary: String(seriesMetaSummaryField ? seriesMetaSummaryField.text : "").trim()
        }

        if (seed.series.length < 1 || Number(seed.year || 0) < 1) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = ""
                seriesMetadataDialog.setAutofillStatus("To use auto-fill, add the minimum metadata: series, year.", "hint")
            }
            return
        }

        if (seriesMetadataDialog) {
            seriesMetadataDialog.errorText = ""
            seriesMetadataDialog.setAutofillStatus("Requesting metadata from ComicVine...", "pending")
        }
        busy = true
        scope = "series"
        targetComicId = -1
        leadIssueId = leadId
        targetSeriesKey = targetKey
        seriesAutofillAttemptSeed = seriesAutofillSeedSignature()
        startCooldown()
        requestId = Number(libraryModelRef.requestComicVineAutofillAsync(seed) || 0)
    }

    function applyIssueResult(result) {
        const comicId = Number(targetComicId || 0)
        const requestError = String((result || {}).error || "").trim()
        if (requestError.length > 0) {
            if (metadataDialog) {
                metadataDialog.errorText = ""
                metadataDialog.setAutofillStatus(requestError, "error")
            }
            return
        }

        const patch = (result && typeof result.values === "object" && result.values) ? result.values : {}
        if (Object.keys(patch).length < 1) {
            if (metadataDialog) {
                metadataDialog.errorText = ""
                metadataDialog.setAutofillStatus(
                    "No metadata match found for this series/issue/year.\n"
                    + issueManualLookupHint(),
                    "error"
                )
            }
            return
        }

        const saveError = String(libraryModelRef.updateComicMetadata(comicId, patch) || "").trim()
        if (saveError.length > 0) {
            if (metadataDialog) metadataDialog.errorText = saveError
            return
        }

        const refreshed = libraryModelRef.loadComicMetadata(comicId)
        if (refreshed && refreshed.error) {
            if (metadataDialog) metadataDialog.errorText = String(refreshed.error || "Failed to reload metadata.")
            return
        }

        if (metadataDialog) {
            metadataDialog.applyState(refreshed || {})
            metadataDialog.markSaved(metadataDialog.currentState())
            metadataDialog.errorText = ""
            metadataDialog.setAutofillStatus("Metadata auto-fill completed. Review and save changes.", "success")
        }
        issuesGridRefreshRequested(true)
    }

    function applySeriesResult(result) {
        const requestError = String((result || {}).error || "").trim()
        if (requestError.length > 0) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = ""
                seriesMetadataDialog.setAutofillStatus(requestError, "error")
            }
            return
        }

        const patch = (result && typeof result.values === "object" && result.values) ? result.values : {}
        if (Object.keys(patch).length < 1) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = ""
                seriesMetadataDialog.setAutofillStatus(
                    "No metadata match found for this series/issue/year.\n"
                    + issueManualLookupHint(),
                    "error"
                )
            }
            return
        }

        const issuePatch = {}
        const allowedIssueKeys = ["series", "publisher", "year", "month", "ageRating", "volume"]
        for (let i = 0; i < allowedIssueKeys.length; i += 1) {
            const key = allowedIssueKeys[i]
            if (Object.prototype.hasOwnProperty.call(patch, key)) {
                issuePatch[key] = patch[key]
            }
        }

        if (Object.keys(issuePatch).length > 0) {
            const saveError = String(libraryModelRef.updateComicMetadata(Number(leadIssueId || 0), issuePatch) || "").trim()
            if (saveError.length > 0) {
                if (seriesMetadataDialog) {
                    seriesMetadataDialog.errorText = saveError
                }
                return
            }
        }

        if (typeof patch.summary === "string" && String(patch.summary || "").trim().length > 0) {
            const seriesMetaError = String(libraryModelRef.setSeriesMetadataForKey(String(targetSeriesKey || ""), {
                summary: String(patch.summary || "").trim()
            }) || "").trim()
            if (seriesMetaError.length > 0) {
                if (seriesMetadataDialog) {
                    seriesMetadataDialog.errorText = seriesMetaError
                }
                return
            }
        }

        const refreshed = libraryModelRef.loadComicMetadata(Number(leadIssueId || 0))
        if (refreshed && refreshed.error) {
            if (seriesMetadataDialog) {
                seriesMetadataDialog.errorText = String(refreshed.error || "Failed to reload metadata.")
            }
            return
        }

        const nextState = refreshed || {}
        if (seriesMetaSeriesField) seriesMetaSeriesField.text = String(nextState.series || "")
        if (seriesMetaVolumeField) seriesMetaVolumeField.text = String(nextState.volume || "")
        if (seriesMetaPublisherField) seriesMetaPublisherField.text = String(nextState.publisher || "")
        if (seriesMetaYearField) seriesMetaYearField.text = Number(nextState.year || 0) > 0 ? String(nextState.year) : ""
        if (seriesMetaMonthCombo) {
            const nextMonthName = monthNameFromNumber(nextState.month)
            seriesMetaMonthCombo.currentIndex = seriesMetaMonthOptions.indexOf(nextMonthName)
            seriesMetaMonthCombo.editText = nextMonthName
        }
        if (seriesMetaAgeRatingCombo) {
            const nextAgeRating = String(nextState.ageRating || "").trim()
            seriesMetaAgeRatingCombo.currentIndex = seriesMetaAgeRatingOptions.indexOf(nextAgeRating)
            seriesMetaAgeRatingCombo.editText = nextAgeRating
        }
        const seriesMetadata = libraryModelRef.seriesMetadataForKey(String(targetSeriesKey || "")) || {}
        if (seriesMetaTitleField) {
            seriesMetaTitleField.text = String(seriesMetadata.seriesTitle || "")
        }
        if (seriesMetaSummaryField) {
            seriesMetaSummaryField.text = String(seriesMetadata.summary || "")
        }

        if (seriesMetadataDialog) {
            seriesMetadataDialog.errorText = ""
            seriesMetadataDialog.setAutofillStatus("Metadata auto-fill completed. Review and save changes.", "success")
        }
        recomputeSeriesAutofillBlockState()
    }

    function handleAutofillFinished(finishedRequestId, result) {
        if (finishedRequestId !== requestId) return

        const currentScope = String(scope || "")
        try {
            if (currentScope === "issue") {
                applyIssueResult(result)
            } else if (currentScope === "series") {
                applySeriesResult(result)
            }
        } finally {
            resetRequestState()
        }
    }

    Connections {
        target: controller.libraryModelRef

        function onComicVineAutofillFinished(finishedRequestId, result) {
            controller.handleAutofillFinished(finishedRequestId, result)
        }
    }

    Timer {
        id: cooldownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            const next = Math.max(0, Number(controller.cooldownRemaining || 0) - 1)
            controller.cooldownRemaining = next
            if (next < 1) {
                cooldownTimer.stop()
            }
        }
    }
}
