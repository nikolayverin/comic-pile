import QtQuick
import "../components/ReadingTarget.js" as ReadingTarget

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null

    property int continueReadingComicId: -1
    property string continueReadingSeriesKey: ""
    property var resolvedContinueReadingTarget: ReadingTarget.invalidTarget(emptyStoredTargetMessage())

    readonly property bool continueReadingAvailable: Boolean(resolvedContinueReadingTarget.ok)

    function traceContinueReading(message) {
        const root = rootObject
        if (root && typeof root.runtimeDebugLog === "function") {
            root.runtimeDebugLog("continue-reading", String(message || ""))
            return
        }
        if (!libraryModelRef || typeof libraryModelRef.appendStartupDebugLog !== "function") {
            return
        }
        libraryModelRef.appendStartupDebugLog("[continue-reading] " + String(message || ""))
    }

    function invalidStoredTargetMessage() {
        return "The last reading issue is no longer available."
    }

    function emptyStoredTargetMessage() {
        return "No active reading session is available yet."
    }

    function currentStoredState() {
        return {
            comicId: Number(continueReadingComicId || -1),
            seriesKey: String(continueReadingSeriesKey || "").trim()
        }
    }

    function resolvedSeriesKeyForStoredTarget(comicId, fallbackSeriesKey) {
        const normalizedComicId = Number(comicId || 0)
        const normalizedFallbackSeriesKey = String(fallbackSeriesKey || "").trim()
        if (!libraryModelRef || normalizedComicId < 1
                || typeof libraryModelRef.navigationTargetForComic !== "function") {
            return normalizedFallbackSeriesKey
        }

        const target = libraryModelRef.navigationTargetForComic(normalizedComicId) || ({})
        const resolvedSeriesKey = String(target.seriesKey || "").trim()
        if (Boolean(target.ok) && resolvedSeriesKey.length > 0) {
            return resolvedSeriesKey
        }
        return normalizedFallbackSeriesKey
    }

    function rememberContinueReadingTarget(comicId, seriesKey, displayTitle, persistState) {
        const normalizedComicId = Number(comicId || 0)
        const nextComicId = normalizedComicId > 0 ? normalizedComicId : -1
        const nextSeriesKey = nextComicId > 0
            ? resolvedSeriesKeyForStoredTarget(nextComicId, seriesKey)
            : ""
        const changed = continueReadingComicId !== nextComicId
            || continueReadingSeriesKey !== nextSeriesKey
        traceContinueReading(
            "remember target"
            + " comicId=" + String(nextComicId)
            + " seriesKey=" + nextSeriesKey
            + " changed=" + String(changed)
            + " persist=" + String(persistState !== false)
        )
        continueReadingComicId = nextComicId
        continueReadingSeriesKey = nextSeriesKey
        if (changed && persistState !== false && libraryModelRef
                && typeof libraryModelRef.writeContinueReadingState === "function") {
            libraryModelRef.writeContinueReadingState({
                comicId: continueReadingComicId,
                seriesKey: continueReadingSeriesKey
            })
        }
        resolveContinueReadingTarget()
    }

    function setResolvedTarget(target) {
        resolvedContinueReadingTarget = ReadingTarget.forContinueReading(target, emptyStoredTargetMessage())
        traceContinueReading(
            "resolved target"
            + " ok=" + String(Boolean(resolvedContinueReadingTarget.ok))
            + " comicId=" + String(resolvedContinueReadingTarget.comicId || -1)
            + " seriesKey=" + String(resolvedContinueReadingTarget.seriesKey || "")
            + " startPageIndex=" + String(resolvedContinueReadingTarget.startPageIndex || 0)
            + " currentPage=" + String(resolvedContinueReadingTarget.currentPage || 0)
            + " bookmarkPage=" + String(resolvedContinueReadingTarget.bookmarkPage || 0)
            + " message=" + String(resolvedContinueReadingTarget.message || "")
        )
        return resolvedContinueReadingTarget
    }

    function fallbackContinueReadingTarget() {
        if (!libraryModelRef || typeof libraryModelRef.continueReadingTarget !== "function") {
            return ReadingTarget.invalidTarget(emptyStoredTargetMessage())
        }
        return ReadingTarget.forContinueReading(
            libraryModelRef.continueReadingTarget() || ({}),
            emptyStoredTargetMessage()
        )
    }

    function resolveContinueReadingTarget() {
        if (!libraryModelRef) {
            return setResolvedTarget(ReadingTarget.invalidTarget(emptyStoredTargetMessage()))
        }

        const storedComicId = Number(continueReadingComicId || -1)
        const storedSeriesKey = String(continueReadingSeriesKey || "").trim()
        let hadStoredTarget = storedComicId > 0
        traceContinueReading(
            "resolve request"
            + " storedComicId=" + String(storedComicId)
            + " storedSeriesKey=" + storedSeriesKey
        )

        if (storedComicId > 0 && typeof libraryModelRef.navigationTargetForComic === "function") {
            const rememberedTarget = ReadingTarget.forContinueReading(
                libraryModelRef.navigationTargetForComic(storedComicId) || ({}),
                invalidStoredTargetMessage()
            )
            traceContinueReading(
                "resolve stored candidate"
                + " ok=" + String(Boolean(rememberedTarget.ok))
                + " comicId=" + String(rememberedTarget.comicId || -1)
                + " seriesKey=" + String(rememberedTarget.seriesKey || "")
                + " currentPage=" + String(rememberedTarget.currentPage || 0)
                + " bookmarkPage=" + String(rememberedTarget.bookmarkPage || 0)
            )
            if (Boolean(rememberedTarget.ok)) {
                const resolvedSeriesKey = String(rememberedTarget.seriesKey || "").trim()
                if (resolvedSeriesKey !== storedSeriesKey || storedComicId !== Number(rememberedTarget.comicId || storedComicId)) {
                    rememberContinueReadingTarget(
                        Number(rememberedTarget.comicId || storedComicId),
                        resolvedSeriesKey,
                        String(rememberedTarget.displayTitle || rememberedTarget.title || "").trim()
                    )
                }
                return setResolvedTarget(rememberedTarget)
            }
        }

        const fallbackTarget = fallbackContinueReadingTarget()
        traceContinueReading(
            "resolve fallback candidate"
            + " ok=" + String(Boolean(fallbackTarget.ok))
            + " comicId=" + String(fallbackTarget.comicId || -1)
            + " seriesKey=" + String(fallbackTarget.seriesKey || "")
            + " currentPage=" + String(fallbackTarget.currentPage || 0)
            + " bookmarkPage=" + String(fallbackTarget.bookmarkPage || 0)
        )
        if (Boolean(fallbackTarget.ok)) {
            rememberContinueReadingTarget(
                Number(fallbackTarget.comicId || -1),
                String(fallbackTarget.seriesKey || "").trim(),
                String(fallbackTarget.displayTitle || fallbackTarget.title || "").trim()
            )
            return setResolvedTarget(fallbackTarget)
        }

        return setResolvedTarget(ReadingTarget.invalidTarget(
            hadStoredTarget
                ? invalidStoredTargetMessage()
                : emptyStoredTargetMessage()
        ))
    }

    function nextUnreadTarget() {
        const currentTarget = resolveContinueReadingTarget() || ({})
        traceContinueReading(
            "next unread request"
            + " continueOk=" + String(Boolean(currentTarget.ok))
            + " anchorComicId=" + String(currentTarget.anchorComicId || currentTarget.comicId || -1)
            + " seriesKey=" + String(currentTarget.seriesKey || "")
        )
        if (!Boolean(currentTarget.ok)) {
            return currentTarget
        }
        if (!libraryModelRef || typeof libraryModelRef.nextUnreadTarget !== "function") {
            return ReadingTarget.invalidTarget(emptyStoredTargetMessage())
        }
        const nextTarget = ReadingTarget.normalize(
            libraryModelRef.nextUnreadTarget(
                String(currentTarget.seriesKey || "").trim(),
                Number(currentTarget.anchorComicId || currentTarget.comicId || -1)
            ) || ({}),
            "No next unread issue is queued right now."
        )
        traceContinueReading(
            "next unread result"
            + " ok=" + String(Boolean(nextTarget.ok))
            + " comicId=" + String(nextTarget.comicId || -1)
            + " seriesKey=" + String(nextTarget.seriesKey || "")
            + " startPageIndex=" + String(nextTarget.startPageIndex || 0)
            + " message=" + String(nextTarget.message || "")
        )
        return nextTarget
    }

    function loadPersistedContinueReadingTarget() {
        if (!libraryModelRef || typeof libraryModelRef.readContinueReadingState !== "function") {
            resolveContinueReadingTarget()
            return
        }

        const persistedState = libraryModelRef.readContinueReadingState() || ({})
        rememberContinueReadingTarget(
            Number(persistedState.comicId || -1),
            String(persistedState.seriesKey || ""),
            "",
            false
        )
        resolveContinueReadingTarget()
    }

    Connections {
        target: libraryModelRef

        function onStatusChanged() {
            controller.resolveContinueReadingTarget()
        }
    }

    Component.onCompleted: loadPersistedContinueReadingTarget()
}
