.pragma library

function cloneVariantMap(sourceValues) {
    const out = {}
    if (!sourceValues || typeof sourceValues !== "object") return out
    const keys = Object.keys(sourceValues)
    for (let i = 0; i < keys.length; i += 1) {
        const key = String(keys[i] || "")
        if (key.length < 1) continue
        out[key] = sourceValues[key]
    }
    return out
}

function fileNameFromPath(pathValue) {
    const normalized = String(pathValue || "").replace(/\\/g, "/").trim()
    if (normalized.length < 1) return ""
    const parts = normalized.split("/")
    return parts.length > 0 ? String(parts[parts.length - 1] || "") : normalized
}

function normalizeImportPath(rawPath) {
    const input = String(rawPath || "").trim()
    if (input.length < 1) return ""

    let normalized = input
    if (normalized.startsWith("file:///")) {
        normalized = normalized.substring("file:///".length)
    } else if (normalized.startsWith("file://")) {
        normalized = normalized.substring("file://".length)
    }

    try {
        normalized = decodeURIComponent(normalized)
    } catch (e) {
        // Keep original if URL decoding fails on malformed input.
    }
    if (/^[A-Za-z]:\//.test(normalized)) {
        return normalized.replace(/\//g, "\\")
    }
    if (normalized.startsWith("/")) {
        return normalized.substring(1).replace(/\//g, "\\")
    }
    return normalized.replace(/\//g, "\\")
}

function displaySeriesTitleForIssue(issue) {
    const row = issue || {}
    const series = String(row.series || "").trim()
    const volume = String(row.volume || "").trim()
    if (series.length < 1) return ""
    if (volume.length < 1) return series
    return series + " - Vol. " + volume
}

function archiveUnsupportedReason(libraryModelRef, pathValue) {
    if (!libraryModelRef || typeof libraryModelRef.importArchiveUnsupportedReason !== "function") return ""
    return String(libraryModelRef.importArchiveUnsupportedReason(String(pathValue || "")) || "")
}

function importErrorMatchesAny(lowerText, patterns) {
    const haystack = String(lowerText || "").trim().toLowerCase()
    if (haystack.length < 1 || !Array.isArray(patterns)) return false
    for (let i = 0; i < patterns.length; i += 1) {
        const pattern = String(patterns[i] || "").trim().toLowerCase()
        if (pattern.length > 0 && haystack.indexOf(pattern) >= 0) {
            return true
        }
    }
    return false
}

function classifyImportError(pathValue, rawErrorText, rawErrorCode) {
    const raw = String(rawErrorText || "").trim()
    const lower = raw.toLowerCase()
    const code = String(rawErrorCode || "").trim().toLowerCase()
    const timedOutCodes = [
        "timeout",
        "timed_out"
    ]
    const accessCodes = [
        "file_not_found",
        "library_dir_create_failed",
        "series_dir_create_failed",
        "temp_dir_create_failed"
    ]
    const unreadableCodes = [
        "archive_normalize_failed"
    ]
    const timedOutPatterns = [
        "timed out",
        "timeout"
    ]
    const accessPatterns = [
        "archive file not found",
        "archive not found",
        "file not found",
        "source path no longer resolves",
        "no longer resolves to a single importable item",
        "failed to copy archive",
        "failed to move extracted page",
        "failed to create library folder",
        "failed to create target directory",
        "failed to create temporary directory",
        "failed to create output directory",
        "failed to create temp extraction folder",
        "failed to create target folder",
        "access is denied",
        "permission denied",
        "is denied",
        "locked"
    ]
    const unreadablePatterns = [
        "archive normalize failed",
        "process failed",
        "exited with code",
        "invalid .cbz archive",
        "archive conversion produced an invalid .cbz archive",
        "cannot be normalized to .cbz",
        "archive is invalid",
        "corrupt",
        "unreadable",
        "no image pages found in archive"
    ]

    let reason = "Unknown error"

    if (importErrorMatchesAny(code, timedOutCodes) || importErrorMatchesAny(lower, timedOutPatterns)) {
        reason = "Import timed out"
    } else if (importErrorMatchesAny(code, accessCodes) || importErrorMatchesAny(lower, accessPatterns)) {
        reason = "Access denied or file locked"
    } else if (importErrorMatchesAny(code, unreadableCodes) || importErrorMatchesAny(lower, unreadablePatterns)) {
        reason = "Corrupted or unreadable archive"
    }

    return {
        reason: reason
    }
}
