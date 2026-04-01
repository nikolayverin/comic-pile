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
        continueReadingComicId = nextComicId
        continueReadingSeriesKey = nextSeriesKey
        if (changed && persistState !== false && libraryModelRef
                && typeof libraryModelRef.writeContinueReadingState === "function") {
            libraryModelRef.writeContinueReadingState({
                comicId: continueReadingComicId,
                seriesKey: continueReadingSeriesKey
            })
        }
    }

    function setResolvedTarget(target) {
        resolvedContinueReadingTarget = ReadingTarget.forContinueReading(target, emptyStoredTargetMessage())
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

        if (storedComicId > 0 && typeof libraryModelRef.navigationTargetForComic === "function") {
            const rememberedTarget = ReadingTarget.forContinueReading(
                libraryModelRef.navigationTargetForComic(storedComicId) || ({}),
                invalidStoredTargetMessage()
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
        if (!Boolean(currentTarget.ok)) {
            return currentTarget
        }
        if (!libraryModelRef || typeof libraryModelRef.nextUnreadTarget !== "function") {
            return ReadingTarget.invalidTarget(emptyStoredTargetMessage())
        }
        return ReadingTarget.normalize(
            libraryModelRef.nextUnreadTarget(
                String(currentTarget.seriesKey || "").trim(),
                Number(currentTarget.anchorComicId || currentTarget.comicId || -1)
            ) || ({}),
            "No next unread issue is queued right now."
        )
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
