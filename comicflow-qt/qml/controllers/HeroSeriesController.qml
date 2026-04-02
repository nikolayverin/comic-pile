import QtQuick
import "../components/PublisherCatalog.js" as PublisherCatalog

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var readerCoverControllerRef: null
    property var startupControllerRef: null
    property var uiTokensRef: null

    function root() {
        return rootObject
    }

    function emptyHeroSeriesData(seriesTitle) {
        return {
            seriesTitle: String(seriesTitle || ""),
            summary: "-",
            year: "-",
            volume: "-",
            publisher: "-",
            genres: "-",
            logoSource: ""
        }
    }

    function heroSeriesDataValue() {
        const rootRef = root()
        return rootRef ? (rootRef.heroSeriesData || emptyHeroSeriesData("")) : emptyHeroSeriesData("")
    }

    function setHeroSeriesData(value) {
        const rootRef = root()
        if (!rootRef) return

        const source = value || {}
        rootRef.heroSeriesData = {
            seriesTitle: String(source.seriesTitle || ""),
            summary: String(source.summary || "-"),
            year: String(source.year || "-"),
            volume: String(source.volume || "-"),
            publisher: String(source.publisher || "-"),
            genres: String(source.genres || "-"),
            logoSource: String(source.logoSource || "")
        }
    }

    function displayPublisherName(publisherName) {
        const rootRef = root()
        return rootRef && typeof rootRef.displayPublisherName === "function"
            ? rootRef.displayPublisherName(publisherName)
            : ""
    }

    function coverSourceForComic(comicId) {
        const rootRef = root()
        return rootRef && typeof rootRef.coverSourceForComic === "function"
            ? String(rootRef.coverSourceForComic(comicId) || "")
            : ""
    }

    function issuesGridMatchesSelectedSeries() {
        const rootRef = root()
        return rootRef && typeof rootRef.issuesGridMatchesSelectedSeries === "function"
            ? Boolean(rootRef.issuesGridMatchesSelectedSeries())
            : false
    }

    function findSeriesKeyForIssueId(issueId, fallbackKey) {
        const rootRef = root()
        return rootRef && typeof rootRef.findSeriesKeyForIssueId === "function"
            ? String(rootRef.findSeriesKeyForIssueId(issueId, fallbackKey) || "")
            : String(fallbackKey || "")
    }

    function heroLogoSourceForPublisher(publisherName) {
        const logoTokenKey = PublisherCatalog.logoTokenKeyForPublisher(publisherName)
        if (logoTokenKey.length < 1 || !uiTokensRef) return ""
        return String(uiTokensRef[logoTokenKey] || "")
    }

    function splitGenres(value) {
        const raw = String(value || "").trim()
        if (raw.length < 1) return []

        const tokens = raw.split(/[;,/|]+/)
        const unique = []
        const seen = ({})
        for (let i = 0; i < tokens.length; i += 1) {
            const token = String(tokens[i] || "").trim()
            if (token.length < 1) continue
            const key = token.toLowerCase()
            if (seen[key] === true) continue
            seen[key] = true
            unique.push(token)
        }
        return unique
    }

    function heroFieldHasValue(value) {
        const text = String(value || "").trim()
        return text.length > 0 && text !== "-"
    }

    function automaticHeroCoverSource() {
        const rootRef = root()
        return rootRef ? coverSourceForComic(rootRef.heroCoverComicId) : ""
    }

    function automaticHeroBackgroundSource() {
        const rootRef = root()
        return rootRef ? String(rootRef.heroBackgroundSource || "") : ""
    }

    function stripSourceRevision(source) {
        return String(source || "").trim().replace(/[?#].*$/, "")
    }

    function cacheBustedSource(source) {
        const text = String(source || "").trim()
        if (text.length < 1) return ""
        const separator = text.indexOf("?") >= 0 ? "&" : "?"
        return text + separator + "v=" + String(Date.now())
    }

    function preserveRefreshedCustomSource(existingSource, storedSource) {
        const existingBase = stripSourceRevision(existingSource)
        const storedBase = stripSourceRevision(storedSource)
        if (storedBase.length < 1) return ""
        if (existingBase.length > 0 && existingBase === storedBase) {
            return existingSource
        }
        return cacheBustedSource(storedSource)
    }

    function currentHeroCoverSource() {
        const rootRef = root()
        const customSource = rootRef ? String(rootRef.heroCustomCoverSource || "").trim() : ""
        if (customSource.length > 0) return customSource
        return automaticHeroCoverSource()
    }

    function currentHeroBackgroundSource() {
        const rootRef = root()
        const customSource = rootRef ? String(rootRef.heroCustomBackgroundSource || "").trim() : ""
        if (customSource.length > 0) return customSource
        return automaticHeroBackgroundSource()
    }

    function resolveHeroMediaForSelectedSeries() {
        if (!readerCoverControllerRef) return
        if (typeof readerCoverControllerRef.resolveHeroCoverForSelectedSeries === "function") {
            readerCoverControllerRef.resolveHeroCoverForSelectedSeries()
        }
        if (typeof readerCoverControllerRef.resolveHeroBackgroundForSelectedSeries === "function") {
            readerCoverControllerRef.resolveHeroBackgroundForSelectedSeries()
        }
    }

    function resolveHeroBackgroundForSelectedSeries() {
        if (!readerCoverControllerRef || typeof readerCoverControllerRef.resolveHeroBackgroundForSelectedSeries !== "function") {
            return
        }
        readerCoverControllerRef.resolveHeroBackgroundForSelectedSeries()
    }

    function preserveHeaderOverridesIfNeeded(targetSeriesKey, sourceSeriesMetadata) {
        if (!libraryModelRef || typeof libraryModelRef.seriesMetadataForKey !== "function") return ""

        const targetKey = String(targetSeriesKey || "").trim()
        if (targetKey.length < 1) return ""

        const sourceMetadata = sourceSeriesMetadata || {}
        const sourceCoverPath = String(sourceMetadata.headerCoverPath || "").trim()
        const sourceBackgroundPath = String(sourceMetadata.headerBackgroundPath || "").trim()
        if (sourceCoverPath.length < 1 && sourceBackgroundPath.length < 1) {
            return ""
        }

        const targetMetadata = libraryModelRef.seriesMetadataForKey(targetKey) || {}
        const targetCoverPath = String(targetMetadata.headerCoverPath || "").trim()
        const targetBackgroundPath = String(targetMetadata.headerBackgroundPath || "").trim()
        if (targetCoverPath.length > 0 || targetBackgroundPath.length > 0) {
            return ""
        }

        const carryResult = libraryModelRef.saveSeriesHeaderImages(
            targetKey,
            sourceCoverPath,
            sourceBackgroundPath
        ) || {}
        if (Boolean(carryResult.ok)) return ""
        return String(carryResult.error || "Failed to move series header images.")
    }

    function applyDraftSeriesData(seriesTitle, summary, year, volume, publisher, genres) {
        setHeroSeriesData({
            seriesTitle: String(seriesTitle || "-"),
            summary: String(summary || "-"),
            year: String(year || "-"),
            volume: String(volume || "-"),
            publisher: String(publisher || "-"),
            genres: String(genres || "-"),
            logoSource: heroLogoSourceForPublisher(publisher)
        })
    }

    function refreshSeriesData() {
        const rootRef = root()
        if (!rootRef || !libraryModelRef) return

        const context = typeof rootRef.currentSelectedSeriesContext === "function"
            ? rootRef.currentSelectedSeriesContext()
            : (rootRef.selectedSeriesContext || ({}))
        const key = String(context.seriesKey || "")
        if (!Boolean(context.hasSeries)) {
            rootRef.heroCustomCoverSource = ""
            rootRef.heroCustomBackgroundSource = ""
            setHeroSeriesData(emptyHeroSeriesData(""))
            return
        }

        let rows = libraryModelRef.issuesForSeries(key, "__all__", "all", "")
        let seriesTitle = String(context.seriesTitle || "")
        if (seriesTitle.length < 1) {
            seriesTitle = String(libraryModelRef.groupTitleForKey(key) || "")
        }

        if ((!rows || rows.length < 1) && issuesGridMatchesSelectedSeries()) {
            rows = rootRef.issuesGridData.slice(0)
        }

        const rowCount = Number(rows && rows.length ? rows.length : 0)
        if (rowCount < 1) {
            if (startupControllerRef && typeof startupControllerRef.startupLog === "function") {
                startupControllerRef.startupLog("heroData empty rows for key=" + key)
            }
            const currentTitle = String((heroSeriesDataValue() || {}).seriesTitle || "").trim()
            if (currentTitle === seriesTitle && currentTitle.length > 0) {
                return
            }
            setHeroSeriesData(emptyHeroSeriesData(seriesTitle))
            return
        }

        let startYear = 0
        const storedSeriesMetadata = libraryModelRef.seriesMetadataForKey(key) || {}
        rootRef.heroCustomCoverSource = preserveRefreshedCustomSource(
            rootRef.heroCustomCoverSource,
            String(storedSeriesMetadata.headerCoverPath || "").trim()
        )
        rootRef.heroCustomBackgroundSource = preserveRefreshedCustomSource(
            rootRef.heroCustomBackgroundSource,
            String(storedSeriesMetadata.headerBackgroundPath || "").trim()
        )
        const storedSeriesYear = String(storedSeriesMetadata.year || "").trim()
        const storedSeriesGenres = String(storedSeriesMetadata.genres || "").trim()
        const volumeOrder = []
        const volumeSeen = ({})
        const publisherCounts = ({})
        const publisherLabel = ({})
        const genresSeen = ({})
        const genres = []

        for (let i = 0; i < rows.length; i += 1) {
            const row = rows[i] || {}

            const year = Number(row.year || 0)
            if (year > 0 && (startYear < 1 || year < startYear)) {
                startYear = year
            }

            const volume = String(row.volume || "").trim()
            if (volume.length > 0) {
                const volumeKey = volume.toLowerCase()
                if (volumeSeen[volumeKey] !== true) {
                    volumeSeen[volumeKey] = true
                    volumeOrder.push(volume)
                }
            }

            const publisher = displayPublisherName(row.publisher)
            if (publisher.length > 0) {
                const publisherKey = PublisherCatalog.normalizePublisherKey(publisher)
                publisherCounts[publisherKey] = Number(publisherCounts[publisherKey] || 0) + 1
                if (!publisherLabel[publisherKey]) {
                    publisherLabel[publisherKey] = publisher
                }
            }

            const rowGenres = splitGenres(row.genres)
            for (let g = 0; g < rowGenres.length; g += 1) {
                const token = rowGenres[g]
                const tokenKey = token.toLowerCase()
                if (genresSeen[tokenKey] === true) continue
                genresSeen[tokenKey] = true
                genres.push(token)
            }
        }

        let seriesSummary = String(libraryModelRef.seriesSummaryForKey(key) || "").trim()
        if (seriesSummary.length < 1 && rowCount > 0) {
            const firstId = Number((rows[0] || {}).id || 0)
            const fallbackKey = findSeriesKeyForIssueId(firstId, key)
            if (fallbackKey.length > 0 && fallbackKey !== key) {
                seriesSummary = String(libraryModelRef.seriesSummaryForKey(fallbackKey) || "").trim()
            }
        }

        let publisherResolved = "-"
        let publisherTopCount = -1
        const publisherKeys = Object.keys(publisherCounts)
        for (let i = 0; i < publisherKeys.length; i += 1) {
            const pKey = publisherKeys[i]
            const count = Number(publisherCounts[pKey] || 0)
            if (count > publisherTopCount) {
                publisherTopCount = count
                publisherResolved = String(publisherLabel[pKey] || "-")
            }
        }

        let volumeResolved = "-"
        if (Boolean(context.hasSpecificVolume)) {
            const selectedVolume = String(context.volumeTitle || "").trim()
            if (selectedVolume.length > 0) {
                volumeResolved = selectedVolume
            }
        } else if (volumeOrder.length === 1) {
            volumeResolved = volumeOrder[0]
        } else if (volumeOrder.length > 1) {
            volumeResolved = "Multiple"
        }

        setHeroSeriesData({
            seriesTitle: seriesTitle,
            summary: seriesSummary.length > 0 ? seriesSummary : "-",
            year: storedSeriesYear.length > 0 ? storedSeriesYear : (startYear > 0 ? String(startYear) : "-"),
            volume: volumeResolved,
            publisher: publisherResolved,
            genres: storedSeriesGenres.length > 0 ? storedSeriesGenres : (genres.length > 0 ? genres.join(" / ") : "-"),
            logoSource: heroLogoSourceForPublisher(publisherResolved)
        })

        if (startupControllerRef && typeof startupControllerRef.startupLog === "function") {
            const heroData = heroSeriesDataValue()
            startupControllerRef.startupLog(
                "heroData key=" + key
                + " rows=" + String(rowCount)
                + " title=\"" + String(heroData.seriesTitle || "") + "\""
                + " year=\"" + String(heroData.year || "") + "\""
                + " volume=\"" + String(heroData.volume || "") + "\""
                + " publisher=\"" + String(heroData.publisher || "") + "\""
                + " genres=\"" + String(heroData.genres || "") + "\""
                + " summaryLen=" + String(String(heroData.summary || "").length)
            )
        }
    }
}
