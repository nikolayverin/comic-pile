.pragma library

function normalizedInt(value, fallbackValue) {
    const parsed = Number(value)
    return isNaN(parsed) ? Number(fallbackValue || 0) : Math.round(parsed)
}

function normalizedText(value) {
    return String(value || "").trim()
}

function invalidTarget(message) {
    return {
        ok: false,
        comicId: -1,
        anchorComicId: -1,
        seriesKey: "",
        seriesTitle: "",
        title: "",
        displayTitle: "",
        readStatus: "unread",
        currentPage: 0,
        bookmarkPage: 0,
        hasBookmark: false,
        hasProgress: false,
        startPageIndex: 0,
        message: normalizedText(message)
    }
}

function normalize(target, fallbackMessage) {
    const raw = target && typeof target === "object" ? target : {}
    const comicId = normalizedInt(raw.comicId, -1)
    const seriesKey = normalizedText(raw.seriesKey)
    const title = normalizedText(raw.title)
    const displayTitle = normalizedText(raw.displayTitle || raw.title)
    const bookmarkPage = Math.max(0, normalizedInt(raw.bookmarkPage, 0))
    const currentPage = Math.max(0, normalizedInt(raw.currentPage, 0))
    const readStatus = normalizedText(raw.readStatus || "unread") || "unread"
    const hasBookmark = raw.hasBookmark === true || bookmarkPage > 0
    const hasProgress = raw.hasProgress === true || (currentPage > 0 && readStatus !== "read")
    const fallbackStartPageIndex = hasBookmark
        ? Math.max(0, bookmarkPage - 1)
        : (hasProgress ? Math.max(0, currentPage - 1) : 0)
    const startPageIndex = Math.max(0, normalizedInt(raw.startPageIndex, fallbackStartPageIndex))
    const ok = Boolean(raw.ok) && comicId > 0 && seriesKey.length > 0

    if (!ok) {
        return invalidTarget(raw.message || fallbackMessage)
    }

    return {
        ok: true,
        comicId: comicId,
        anchorComicId: Math.max(1, normalizedInt(raw.anchorComicId, comicId)),
        seriesKey: seriesKey,
        seriesTitle: normalizedText(raw.seriesTitle),
        title: title,
        displayTitle: displayTitle.length > 0 ? displayTitle : ("Issue #" + String(comicId)),
        readStatus: readStatus,
        currentPage: currentPage,
        bookmarkPage: bookmarkPage,
        hasBookmark: hasBookmark,
        hasProgress: hasProgress,
        startPageIndex: startPageIndex,
        message: normalizedText(raw.message || "")
    }
}

function forContinueReading(target, fallbackMessage) {
    const normalized = normalize(target, fallbackMessage)
    if (!normalized.ok) {
        return normalized
    }

    if (normalized.hasProgress && normalized.currentPage > 0) {
        normalized.startPageIndex = Math.max(0, normalized.currentPage - 1)
        return normalized
    }

    if (normalized.hasBookmark && normalized.bookmarkPage > 0) {
        normalized.startPageIndex = Math.max(0, normalized.bookmarkPage - 1)
    }

    return normalized
}
