import QtQuick
import "../components/PublisherCatalog.js" as PublisherCatalog
import "../components/AppText.js" as AppText

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var popupControllerRef: null
    property var startupControllerRef: null
    property var heroSeriesControllerRef: null

    property var editingComic: null
    property string editingSeriesKey: ""
    property var editingSeriesKeys: []
    property string editingSeriesDialogMode: "single"
    property string editingSeriesTitle: ""
    property var pendingSeriesMetadataSuggestion: ({})
    property var pendingIssueMetadataSuggestion: ({})

    function activeRoot() {
        return rootObject
    }

    function seriesMetaMonthNameFromNumber(monthNumber) {
        const root = activeRoot()
        const value = Number(monthNumber || 0)
        if (!root || value < 1 || value > 12) return ""
        return String(root.seriesMetaMonthOptions[value - 1] || "")
    }

    function seriesMetaMonthNumberFromName(monthName) {
        const root = activeRoot()
        const name = String(monthName || "").trim()
        if (!root || name.length < 1) return ""
        const idx = root.seriesMetaMonthOptions.indexOf(name)
        if (idx >= 0) return String(idx + 1)
        return ""
    }

    function openMetadataEditor(comic) {
        const root = activeRoot()
        if (!root || !libraryModelRef || !popupControllerRef) return

        let loaded = libraryModelRef.loadComicMetadata(comic.id)
        if (loaded && loaded.error) {
            libraryModelRef.reload()
            loaded = libraryModelRef.loadComicMetadata(comic.id)
        }
        if (loaded && loaded.error) {
            editingComic = null
            return
        }

        editingComic = comic
        const values = loaded || comic || {}
        popupControllerRef.closeAllManagedPopups(root.metadataDialog)
        root.metadataDialog.openForState(values)
    }

    function saveMetadata(draftState) {
        const root = activeRoot()
        if (!root || !libraryModelRef) return false
        if (!editingComic) {
            root.metadataDialog.errorText = AppText.metadataNothingSelected
            return false
        }

        const draft = draftState || root.metadataDialog.currentState()
        const result = libraryModelRef.updateComicMetadata(editingComic.id, draft)
        if (result.length > 0) {
            root.metadataDialog.errorText = result
            return false
        }

        root.metadataDialog.errorText = ""
        root.metadataDialog.markSaved(draft)
        return true
    }

    function buildIssueMetadataSuggestion(draftState) {
        const root = activeRoot()
        if (!root || !libraryModelRef || !editingComic) return null
        const draft = draftState || root.metadataDialog.currentState()
        const suggestion = libraryModelRef.issueMetadataSuggestion(draft, Number(editingComic.id || 0)) || {}
        return Object.keys(suggestion).length > 0 ? suggestion : null
    }

    function applyIssueMetadataSuggestionPatch(patch) {
        const root = activeRoot()
        if (!root || !patch || typeof patch !== "object") return
        const nextState = root.metadataDialog.currentState()
        const keys = Object.keys(patch)
        for (let i = 0; i < keys.length; i += 1) {
            const key = String(keys[i] || "")
            if (key.length < 1) continue
            if (String(nextState[key] || "").trim().length > 0) continue
            nextState[key] = patch[key]
        }
        root.metadataDialog.applyState(nextState)
    }

    function requestApplyIssueMetadataEdit(draftState) {
        const root = activeRoot()
        if (!root) return
        const draft = draftState || root.metadataDialog.currentState()
        const suggestion = buildIssueMetadataSuggestion(draft)
        if (suggestion) {
            pendingIssueMetadataSuggestion = suggestion
            const suggestionSeriesLabel = String(suggestion.displayTitle || draft.series || "this series")
            const suggestionIssueLabel = String(suggestion.issueNumber || draft.issueNumber || "")
            root.issueMetadataAutofillConfirmDialog.messageText = AppText.issueAutofillMessage(
                suggestionIssueLabel,
                suggestionSeriesLabel
            )
            root.issueMetadataAutofillConfirmDialog.open()
            return
        }

        pendingIssueMetadataSuggestion = ({})
        if (saveMetadata(draft)) {
            root.metadataDialog.close()
        }
    }

    function acceptIssueMetadataSuggestion() {
        const root = activeRoot()
        if (!root) return
        const suggestion = pendingIssueMetadataSuggestion || ({})
        pendingIssueMetadataSuggestion = ({})
        if (root.issueMetadataAutofillConfirmDialog.visible) {
            root.issueMetadataAutofillConfirmDialog.close()
        }
        applyIssueMetadataSuggestionPatch(suggestion.patch || {})
        if (saveMetadata(root.metadataDialog.currentState())) {
            root.metadataDialog.close()
        }
    }

    function skipIssueMetadataSuggestion() {
        const root = activeRoot()
        if (!root) return
        pendingIssueMetadataSuggestion = ({})
        if (root.issueMetadataAutofillConfirmDialog.visible) {
            root.issueMetadataAutofillConfirmDialog.close()
        }
        if (saveMetadata(root.metadataDialog.currentState())) {
            root.metadataDialog.close()
        }
    }

    function resetMetadataEditor() {
        const root = activeRoot()
        if (!root || !editingComic) return
        root.metadataDialog.resetToInitial()
    }

    function openSeriesMetadataDialog(seriesKey, seriesTitle, focusField, mode) {
        const root = activeRoot()
        if (!root || !libraryModelRef || !popupControllerRef) return

        const key = String(seriesKey || root.selectedSeriesKey || "").trim()
        if (key.length < 1) {
            popupControllerRef.showActionResult(AppText.metadataSelectSeriesFirst, true)
            return
        }

        const selectedKeys = Object.keys(root.selectedSeriesKeys).filter(function(k) {
            return root.selectedSeriesKeys[k] === true
        })
        const multiSelected = selectedKeys.length > 1 && selectedKeys.indexOf(key) >= 0
        const targetKeys = multiSelected ? selectedKeys : [key]
        const requestedMode = String(mode || "").trim().toLowerCase()
        const effectiveMode = multiSelected
            ? (requestedMode === "merge" ? "merge" : "bulk")
            : "single"
        editingSeriesKey = key
        editingSeriesKeys = targetKeys
        editingSeriesDialogMode = effectiveMode
        if (multiSelected) {
            editingSeriesTitle = String(targetKeys.length) + " series selected"
        } else {
            editingSeriesTitle = String(seriesTitle || root.selectedSeriesTitle || "").trim()
            if (editingSeriesTitle.length < 1) {
                editingSeriesTitle = String(libraryModelRef.groupTitleForKey(key) || "")
            }
        }

        const rows = libraryModelRef.issuesForSeries(key, "__all__", "all", "")
        const storedSeriesMetadata = multiSelected ? {} : (libraryModelRef.seriesMetadataForKey(key) || {})
        let seedSeries = ""
        let seedVolume = String(storedSeriesMetadata.volume || "").trim()
        let seedSeriesTitle = String(storedSeriesMetadata.seriesTitle || "").trim()
        let seedYear = String(storedSeriesMetadata.year || "").trim()
        let seedGenres = String(storedSeriesMetadata.genres || "").trim()
        let seedMonthName = seriesMetaMonthNameFromNumber(storedSeriesMetadata.month)
        let seedPublisher = String(storedSeriesMetadata.publisher || "").trim()
        let seedAgeRating = String(storedSeriesMetadata.ageRating || "").trim()
        const rowCount = Number(rows && rows.length ? rows.length : 0)
        if (rowCount > 0) {
            const firstRow = rows[0] || {}
            seedSeries = root.normalizeSeriesNameForSave(String(firstRow.series || "").trim(), String(firstRow.volume || "").trim())
            if (seedVolume.length < 1) {
                seedVolume = String(firstRow.volume || "").trim()
            }
            if (seedMonthName.length < 1) {
                seedMonthName = seriesMetaMonthNameFromNumber(firstRow.month)
            }
            if (seedAgeRating.length < 1) {
                seedAgeRating = String(firstRow.ageRating || "").trim()
            }
            let minYear = 0
            const publisherCounts = ({})
            const publisherLabel = ({})
            const genreSeedSeen = ({})
            const genreSeedList = []
            for (let i = 0; i < rows.length; i += 1) {
                const row = rows[i] || {}
                const y = Number(row.year || 0)
                if (y > 0 && (minYear < 1 || y < minYear)) minYear = y

                const p = root.displayPublisherName(row.publisher)
                if (p.length > 0) {
                    const pk = PublisherCatalog.normalizePublisherKey(p)
                    publisherCounts[pk] = Number(publisherCounts[pk] || 0) + 1
                    if (!publisherLabel[pk]) publisherLabel[pk] = p
                }

                if (seedGenres.length < 1) {
                    const rowGenres = heroSeriesControllerRef.splitGenres(row.genres)
                    for (let g = 0; g < rowGenres.length; g += 1) {
                        const token = rowGenres[g]
                        const tokenKey = token.toLowerCase()
                        if (genreSeedSeen[tokenKey] === true) continue
                        genreSeedSeen[tokenKey] = true
                        genreSeedList.push(token)
                    }
                }
            }
            if (seedYear.length < 1 && minYear > 0) seedYear = String(minYear)
            if (seedGenres.length < 1 && genreSeedList.length > 0) seedGenres = genreSeedList.join(" / ")
            let topPublisher = ""
            let topCount = -1
            const pKeys = Object.keys(publisherCounts)
            for (let p = 0; p < pKeys.length; p += 1) {
                const pk = pKeys[p]
                const cnt = Number(publisherCounts[pk] || 0)
                if (cnt > topCount) {
                    topCount = cnt
                    topPublisher = String(publisherLabel[pk] || "")
                }
            }
            if (seedPublisher.length < 1) {
                seedPublisher = topPublisher
            }
        }

        root.seriesMetaDialog.prepareDropdownState(seedYear, seedAgeRating, seedGenres, seedPublisher)
        root.seriesMetaSeriesField.text = seedSeries.length > 0
            ? seedSeries
            : root.normalizeSeriesNameForSave(String(editingSeriesTitle || ""), "")
        root.seriesMetaSummaryField.text = multiSelected ? "" : String(storedSeriesMetadata.summary || "")
        root.seriesMetaYearField.text = seedYear
        root.seriesMetaTitleField.text = seedSeriesTitle
        root.seriesMetaVolumeField.text = seedVolume.length > 0 ? seedVolume : ""
        root.seriesMetaGenresField.text = seedGenres
        root.seriesMetaPublisherField.text = seedPublisher
        root.seriesMetaMonthCombo.editText = seedMonthName
        root.seriesMetaAgeRatingCombo.editText = seedAgeRating
        if (root.seriesMetaSummaryField.text === "-") root.seriesMetaSummaryField.text = ""
        if (root.seriesMetaYearField.text === "-") root.seriesMetaYearField.text = ""
        if (root.seriesMetaVolumeField.text === "Multiple" || root.seriesMetaVolumeField.text === "-") root.seriesMetaVolumeField.text = ""
        if (root.seriesMetaGenresField.text === "-") root.seriesMetaGenresField.text = ""
        if (root.seriesMetaPublisherField.text === "-") root.seriesMetaPublisherField.text = ""
        startupControllerRef.startupLog(
            "seriesDialog open key=" + key
            + " mode=" + effectiveMode
            + " multi=" + String(multiSelected)
            + " targetKeys=" + String(targetKeys.length)
            + " rows=" + String(rowCount)
            + " seedSeries=\"" + String(root.seriesMetaSeriesField.text || "") + "\""
            + " seedSeriesTitle=\"" + String(root.seriesMetaTitleField.text || "") + "\""
            + " seedVolume=\"" + String(root.seriesMetaVolumeField.text || "") + "\""
            + " seedGenres=\"" + String(root.seriesMetaGenresField.text || "") + "\""
            + " seedPublisher=\"" + String(root.seriesMetaPublisherField.text || "") + "\""
            + " seedYear=\"" + String(root.seriesMetaYearField.text || "") + "\""
            + " seedMonth=\"" + String(root.seriesMetaMonthCombo.currentText || "") + "\""
            + " seedAge=\"" + String(root.seriesMetaAgeRatingCombo.currentText || "") + "\""
            + " seedSummaryLen=" + String(String(root.seriesMetaSummaryField.text || "").length)
        )
        root.seriesMetaDialog.pendingFocusField = String(focusField || "").trim()
        root.seriesMetaDialog.errorText = ""
        popupControllerRef.openExclusivePopup(root.seriesMetaDialog)
    }

    function openSeriesMergeDialog(seriesKey, seriesTitle) {
        openSeriesMetadataDialog(seriesKey, seriesTitle, "series", "merge")
    }

    function buildSeriesMetadataSuggestion() {
        const root = activeRoot()
        if (!root || !libraryModelRef) return null
        const currentKey = String(editingSeriesKey || "").trim()
        if (currentKey.length < 1) return null
        if (Array.isArray(editingSeriesKeys) && editingSeriesKeys.length > 1) return null

        const seriesRawValue = String(root.seriesMetaSeriesField.text || "").trim()
        const volumeValue = String(root.seriesMetaVolumeField.text || "").trim()
        const seriesValue = root.normalizeSeriesNameForSave(seriesRawValue, volumeValue)
        const suggestion = libraryModelRef.seriesMetadataSuggestion({
            series: seriesValue,
            seriesTitle: String(root.seriesMetaTitleField.text || "").trim(),
            summary: String(root.seriesMetaSummaryField.text || "").trim(),
            year: String(root.seriesMetaYearField.text || "").trim(),
            month: seriesMetaMonthNumberFromName(root.seriesMetaMonthCombo.currentText),
            genres: String(root.seriesMetaGenresField.text || "").trim(),
            volume: volumeValue,
            publisher: String(root.seriesMetaPublisherField.text || "").trim(),
            ageRating: String(root.seriesMetaAgeRatingCombo.currentText || "").trim()
        }, currentKey) || {}
        return Object.keys(suggestion).length > 0 ? suggestion : null
    }

    function applySeriesMetadataSuggestionPatch(patch) {
        const root = activeRoot()
        if (!root) return
        const values = patch || {}
        if (Object.prototype.hasOwnProperty.call(values, "seriesTitle")
                && String(root.seriesMetaTitleField.text || "").trim().length < 1) {
            root.seriesMetaTitleField.text = String(values.seriesTitle || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "summary")
                && String(root.seriesMetaSummaryField.text || "").trim().length < 1) {
            root.seriesMetaSummaryField.text = String(values.summary || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "year")
                && String(root.seriesMetaYearField.text || "").trim().length < 1) {
            root.seriesMetaYearField.text = String(values.year || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "month")
                && String(root.seriesMetaMonthCombo.currentText || "").trim().length < 1) {
            root.seriesMetaMonthCombo.editText = seriesMetaMonthNameFromNumber(values.month)
        }
        if (Object.prototype.hasOwnProperty.call(values, "genres")
                && String(root.seriesMetaGenresField.text || "").trim().length < 1) {
            root.seriesMetaGenresField.text = String(values.genres || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "volume")
                && String(root.seriesMetaVolumeField.text || "").trim().length < 1) {
            root.seriesMetaVolumeField.text = String(values.volume || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "publisher")
                && String(root.seriesMetaPublisherField.text || "").trim().length < 1) {
            root.seriesMetaPublisherField.text = String(values.publisher || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "ageRating")
                && String(root.seriesMetaAgeRatingCombo.currentText || "").trim().length < 1) {
            root.seriesMetaAgeRatingCombo.editText = String(values.ageRating || "").trim()
        }
    }

    function requestApplySeriesMetadataEdit() {
        const root = activeRoot()
        if (!root) return
        const suggestion = buildSeriesMetadataSuggestion()
        if (suggestion) {
            pendingSeriesMetadataSuggestion = suggestion
            const suggestionLabel = String(suggestion.displayTitle || root.seriesMetaSeriesField.text || "this series")
            root.seriesMetadataAutofillConfirmDialog.messageText = AppText.seriesAutofillMessage(
                suggestionLabel
            )
            root.seriesMetadataAutofillConfirmDialog.open()
            return
        }

        pendingSeriesMetadataSuggestion = ({})
        if (applySeriesMetadataEdit()) {
            root.seriesMetaDialog.close()
        }
    }

    function acceptSeriesMetadataSuggestion() {
        const root = activeRoot()
        if (!root) return
        const suggestion = pendingSeriesMetadataSuggestion || ({})
        pendingSeriesMetadataSuggestion = ({})
        if (root.seriesMetadataAutofillConfirmDialog.visible) {
            root.seriesMetadataAutofillConfirmDialog.close()
        }
        applySeriesMetadataSuggestionPatch(suggestion.patch || {})
        if (applySeriesMetadataEdit()) {
            root.seriesMetaDialog.close()
        }
    }

    function skipSeriesMetadataSuggestion() {
        const root = activeRoot()
        if (!root) return
        pendingSeriesMetadataSuggestion = ({})
        if (root.seriesMetadataAutofillConfirmDialog.visible) {
            root.seriesMetadataAutofillConfirmDialog.close()
        }
        if (applySeriesMetadataEdit()) {
            root.seriesMetaDialog.close()
        }
    }

    function findSeriesKeyForIssueId(issueId, fallbackKey) {
        const targetId = Number(issueId || 0)
        const fallback = String(fallbackKey || "").trim()
        if (!libraryModelRef || targetId < 1) return fallback

        const groups = libraryModelRef.seriesGroups()
        for (let i = 0; i < groups.length; i += 1) {
            const group = groups[i] || {}
            const groupKey = String(group.seriesKey || "").trim()
            if (groupKey.length < 1) continue
            const rows = libraryModelRef.issuesForSeries(groupKey, "__all__", "all", "")
            for (let j = 0; j < rows.length; j += 1) {
                const id = Number((rows[j] || {}).id || 0)
                if (id === targetId) {
                    return groupKey
                }
            }
        }
        return fallback
    }

    function applySeriesMetadataEdit() {
        const root = activeRoot()
        if (!root || !libraryModelRef || !heroSeriesControllerRef) return false

        const keys = Array.isArray(editingSeriesKeys) && editingSeriesKeys.length > 0
            ? editingSeriesKeys.slice(0)
            : [String(editingSeriesKey || "").trim()]
        const normalizedKeys = keys
            .map(function(k) { return String(k || "").trim() })
            .filter(function(k) { return k.length > 0 })
        if (normalizedKeys.length < 1) {
            root.seriesMetaDialog.errorText = AppText.metadataSeriesContextMissing
            return false
        }

        const key = normalizedKeys[0]
        const multiSelection = normalizedKeys.length > 1
        const editMode = String(editingSeriesDialogMode || "").trim().toLowerCase()
        const mergeMode = editMode === "merge" && multiSelection
        const bulkMode = editMode === "bulk" && multiSelection
        const ids = []
        const leadIssueByKey = ({})
        for (let k = 0; k < normalizedKeys.length; k += 1) {
            const seriesKey = normalizedKeys[k]
            const issues = libraryModelRef.issuesForSeries(seriesKey, "__all__", "all", "")
            for (let i = 0; i < issues.length; i += 1) {
                const id = Number((issues[i] || {}).id || 0)
                if (id > 0) {
                    ids.push(id)
                    if (!leadIssueByKey[seriesKey]) {
                        leadIssueByKey[seriesKey] = id
                    }
                }
            }
        }

        if (ids.length < 1) {
            root.seriesMetaDialog.errorText = AppText.metadataNoIssuesFound
            return false
        }
        const dedupMap = ({})
        const dedupIds = []
        for (let i = 0; i < ids.length; i += 1) {
            const id = Number(ids[i] || 0)
            if (id < 1 || dedupMap[id] === true) continue
            dedupMap[id] = true
            dedupIds.push(id)
        }

        const seriesRawValue = String(root.seriesMetaSeriesField.text || "").trim()
        const volumeValue = String(root.seriesMetaVolumeField.text || "").trim()
        const seriesValue = mergeMode
            ? String(seriesRawValue || "").trim()
            : root.normalizeSeriesNameForSave(seriesRawValue, volumeValue)
        const seriesTitleValue = String(root.seriesMetaTitleField.text || "").trim()
        const summaryValue = String(root.seriesMetaSummaryField.text || "").trim()
        const yearValue = String(root.seriesMetaYearField.text || "").trim()
        const monthValue = seriesMetaMonthNumberFromName(root.seriesMetaMonthCombo.currentText)
        const genresValue = String(root.seriesMetaGenresField.text || "").trim()
        const publisherValue = String(root.seriesMetaPublisherField.text || "").trim()
        const resolvedPublisherValue = root.displayPublisherName(publisherValue)
        const ageRatingValue = String(root.seriesMetaAgeRatingCombo.currentText || "").trim()
        startupControllerRef.startupLog(
            "seriesDialog save key=" + key
            + " keys=" + String(normalizedKeys.length)
            + " ids=" + String(dedupIds.length)
            + " mode=" + editMode
            + " multi=" + String(multiSelection)
            + " series=\"" + seriesValue + "\""
            + " seriesTitle=\"" + seriesTitleValue + "\""
            + " volume=\"" + volumeValue + "\""
            + " genres=\"" + genresValue + "\""
            + " publisher=\"" + publisherValue + "\""
            + " year=\"" + yearValue + "\""
            + " month=\"" + monthValue + "\""
            + " ageRating=\"" + ageRatingValue + "\""
            + " summaryLen=" + String(summaryValue.length)
        )

        const values = {}
        const applyMap = {}
        if (mergeMode) {
            if (seriesValue.length < 1) {
                root.seriesMetaDialog.errorText = AppText.metadataMergeTargetRequired
                return false
            }
            values.series = seriesValue
            applyMap.series = true
        } else if (bulkMode) {
            if (monthValue.length > 0) {
                values.month = monthValue
                applyMap.month = true
            }
            if (publisherValue.length > 0) {
                values.publisher = publisherValue
                applyMap.publisher = true
            }
            if (ageRatingValue.length > 0) {
                values.ageRating = ageRatingValue
                applyMap.ageRating = true
            }
            if (Object.keys(applyMap).length < 1
                    && summaryValue.length < 1
                    && seriesTitleValue.length < 1
                    && yearValue.length < 1
                    && genresValue.length < 1) {
                root.seriesMetaDialog.errorText = AppText.metadataBulkEditFieldRequired
                return false
            }
        } else {
            values.series = seriesValue
            values.month = monthValue
            values.volume = volumeValue
            values.publisher = publisherValue
            values.ageRating = ageRatingValue

            applyMap.series = true
            applyMap.month = true
            applyMap.volume = true
            applyMap.publisher = true
            applyMap.ageRating = true
        }

        const result = libraryModelRef.bulkUpdateMetadata(dedupIds, values, applyMap)
        if (result.length > 0) {
            startupControllerRef.startupLog("seriesDialog bulkUpdate error: " + result)
            root.seriesMetaDialog.errorText = result
            return false
        }

        if (!multiSelection) {
            const verifyId = Number(dedupIds[0] || 0)
            const verify = libraryModelRef.loadComicMetadata(verifyId)
            if (verify && verify.error) {
                startupControllerRef.startupLog("seriesDialog verify error: " + String(verify.error || "unknown"))
                root.seriesMetaDialog.errorText = String(verify.error || AppText.metadataSaveVerificationFailed)
                return false
            }

            const mismatched =
                String(verify.series || "").trim() !== seriesValue
                || String(verify.volume || "").trim() !== volumeValue
                || String(verify.publisher || "").trim() !== publisherValue
                || String(verify.ageRating || "").trim() !== ageRatingValue
                || Number(verify.month || 0) !== Number(monthValue || 0)
            if (mismatched) {
                startupControllerRef.startupLog(
                    "seriesDialog verify mismatch"
                    + " verifySeries=\"" + String(verify.series || "") + "\""
                    + " verifyVolume=\"" + String(verify.volume || "") + "\""
                    + " verifyPublisher=\"" + String(verify.publisher || "") + "\""
                    + " verifyYear=\"" + String(verify.year || "") + "\""
                    + " verifyMonth=\"" + String(verify.month || "") + "\""
                    + " verifyAgeRating=\"" + String(verify.ageRating || "") + "\""
                )
                root.seriesMetaDialog.errorText = AppText.metadataSaveMismatch
                root.scheduleModelReconcile(true)
                return false
            }

            const resolvedSeriesKey = findSeriesKeyForIssueId(verifyId, key)
            const resolvedSeriesTitle = String(libraryModelRef.groupTitleForKey(resolvedSeriesKey) || "").trim()
            const targetSeriesKey = String(resolvedSeriesKey || key).trim()
            const sourceSeriesMetadata = libraryModelRef.seriesMetadataForKey(key) || {}
            const seriesMetaSaveResult = libraryModelRef.setSeriesMetadataForKey(targetSeriesKey, {
                seriesTitle: seriesTitleValue,
                summary: summaryValue,
                year: yearValue,
                month: monthValue,
                genres: genresValue,
                volume: volumeValue,
                publisher: resolvedPublisherValue,
                ageRating: ageRatingValue
            })
            if (seriesMetaSaveResult.length > 0) {
                startupControllerRef.startupLog("seriesDialog series metadata save error: " + seriesMetaSaveResult)
                root.seriesMetaDialog.errorText = seriesMetaSaveResult
                return false
            }
            if (targetSeriesKey !== key) {
                const preserveHeaderError = heroSeriesControllerRef.preserveHeaderOverridesIfNeeded(targetSeriesKey, sourceSeriesMetadata)
                if (preserveHeaderError.length > 0) {
                    root.seriesMetaDialog.errorText = preserveHeaderError
                    return false
                }
                libraryModelRef.removeSeriesMetadataForKey(key)
            }
            startupControllerRef.startupLog("seriesDialog save success targetKey=" + targetSeriesKey)
            root.seriesMetaDialog.errorText = ""
            editingSeriesKey = ""
            editingSeriesKeys = []
            editingSeriesTitle = ""

            root.refreshSeriesList()
            const effectiveSeriesKey = String(resolvedSeriesKey || key).trim()
            if (effectiveSeriesKey.length > 0) {
                root.selectedSeriesTitle = resolvedSeriesTitle.length > 0
                    ? resolvedSeriesTitle
                    : String(libraryModelRef.groupTitleForKey(effectiveSeriesKey) || root.selectedSeriesTitle)
                root.selectedSeriesKey = effectiveSeriesKey
                const selection = {}
                selection[effectiveSeriesKey] = true
                root.selectedSeriesKeys = selection
                root.seriesSelectionAnchorIndex = root.indexForSeriesKey(effectiveSeriesKey)
                root.refreshVolumeList()
                heroSeriesControllerRef.resolveHeroMediaForSelectedSeries()
                heroSeriesControllerRef.applyDraftSeriesData(
                    String(root.selectedSeriesTitle || seriesValue || "-"),
                    summaryValue.length > 0 ? summaryValue : "-",
                    yearValue.length > 0 ? yearValue : "-",
                    volumeValue.length > 0 ? volumeValue : "-",
                    resolvedPublisherValue.length > 0 ? resolvedPublisherValue : "-",
                    genresValue.length > 0 ? genresValue : "-"
                )
                heroSeriesControllerRef.refreshSeriesData()
                root.refreshIssuesGridData()
            } else {
                root.scheduleModelReconcile(true)
            }
            startupControllerRef.requestSnapshotSave()
            return true
        }

        if (mergeMode) {
            const primaryLeadId = Number(leadIssueByKey[key] || 0)
            const primaryTargetSeriesKey = primaryLeadId > 0
                ? String(findSeriesKeyForIssueId(primaryLeadId, key) || key).trim()
                : key
            const primarySourceMetadata = libraryModelRef.seriesMetadataForKey(key) || {}
            if (primaryTargetSeriesKey !== key) {
                const preserveHeaderError = heroSeriesControllerRef.preserveHeaderOverridesIfNeeded(
                    primaryTargetSeriesKey,
                    primarySourceMetadata
                )
                if (preserveHeaderError.length > 0) {
                    root.seriesMetaDialog.errorText = preserveHeaderError
                    return false
                }
                const primarySeriesMetaSaveResult = libraryModelRef.setSeriesMetadataForKey(primaryTargetSeriesKey, {
                    seriesTitle: String(primarySourceMetadata.seriesTitle || "").trim(),
                    summary: String(primarySourceMetadata.summary || "").trim(),
                    year: String(primarySourceMetadata.year || "").trim(),
                    month: String(primarySourceMetadata.month || "").trim(),
                    genres: String(primarySourceMetadata.genres || "").trim(),
                    volume: String(primarySourceMetadata.volume || "").trim(),
                    publisher: String(primarySourceMetadata.publisher || "").trim(),
                    ageRating: String(primarySourceMetadata.ageRating || "").trim()
                })
                if (primarySeriesMetaSaveResult.length > 0) {
                    startupControllerRef.startupLog("seriesDialog merge metadata save error: " + primarySeriesMetaSaveResult)
                    root.seriesMetaDialog.errorText = primarySeriesMetaSaveResult
                    return false
                }
            }
            for (let i = 0; i < normalizedKeys.length; i += 1) {
                const sourceKey = normalizedKeys[i]
                if (sourceKey === primaryTargetSeriesKey) continue
                libraryModelRef.removeSeriesMetadataForKey(sourceKey)
            }
        } else if (summaryValue.length > 0
                || seriesTitleValue.length > 0
                || yearValue.length > 0
                || genresValue.length > 0) {
            for (let i = 0; i < normalizedKeys.length; i += 1) {
                const sourceKey = normalizedKeys[i]
                const leadId = Number(leadIssueByKey[sourceKey] || 0)
                const resolvedKey = leadId > 0 ? findSeriesKeyForIssueId(leadId, sourceKey) : sourceKey
                const targetSeriesKey = String(resolvedKey || sourceKey).trim()
                const sourceSeriesMetadata = libraryModelRef.seriesMetadataForKey(sourceKey) || {}
                const nextSeriesTitle = seriesTitleValue.length > 0
                    ? seriesTitleValue
                    : String(sourceSeriesMetadata.seriesTitle || "").trim()
                const nextSummary = summaryValue.length > 0
                    ? summaryValue
                    : String(sourceSeriesMetadata.summary || "").trim()
                const nextSeriesYear = yearValue.length > 0
                    ? yearValue
                    : String(sourceSeriesMetadata.year || "").trim()
                const nextSeriesMonth = monthValue.length > 0
                    ? monthValue
                    : String(sourceSeriesMetadata.month || "").trim()
                const nextSeriesGenres = genresValue.length > 0
                    ? genresValue
                    : String(sourceSeriesMetadata.genres || "").trim()
                const nextSeriesVolume = volumeValue.length > 0
                    ? volumeValue
                    : String(sourceSeriesMetadata.volume || "").trim()
                const nextSeriesPublisher = resolvedPublisherValue.length > 0
                    ? resolvedPublisherValue
                    : String(sourceSeriesMetadata.publisher || "").trim()
                const nextSeriesAgeRating = ageRatingValue.length > 0
                    ? ageRatingValue
                    : String(sourceSeriesMetadata.ageRating || "").trim()
                const seriesMetaValues = {}
                if (nextSeriesTitle.length > 0) seriesMetaValues.seriesTitle = nextSeriesTitle
                if (nextSummary.length > 0) seriesMetaValues.summary = nextSummary
                if (nextSeriesYear.length > 0) seriesMetaValues.year = nextSeriesYear
                if (nextSeriesMonth.length > 0) seriesMetaValues.month = nextSeriesMonth
                if (nextSeriesGenres.length > 0) seriesMetaValues.genres = nextSeriesGenres
                if (!bulkMode && nextSeriesVolume.length > 0) seriesMetaValues.volume = nextSeriesVolume
                if (nextSeriesPublisher.length > 0) seriesMetaValues.publisher = nextSeriesPublisher
                if (nextSeriesAgeRating.length > 0) seriesMetaValues.ageRating = nextSeriesAgeRating
                const seriesMetaSaveResult = libraryModelRef.setSeriesMetadataForKey(targetSeriesKey, seriesMetaValues)
                if (seriesMetaSaveResult.length > 0) {
                    startupControllerRef.startupLog("seriesDialog series metadata save error: " + seriesMetaSaveResult)
                    root.seriesMetaDialog.errorText = seriesMetaSaveResult
                    return false
                }
                if (targetSeriesKey !== sourceKey) {
                    const preserveHeaderError = heroSeriesControllerRef.preserveHeaderOverridesIfNeeded(targetSeriesKey, sourceSeriesMetadata)
                    if (preserveHeaderError.length > 0) {
                        root.seriesMetaDialog.errorText = preserveHeaderError
                        return false
                    }
                    libraryModelRef.removeSeriesMetadataForKey(sourceKey)
                }
            }
        }
        startupControllerRef.startupLog("seriesDialog bulk save success mode=" + editMode + " keys=" + String(normalizedKeys.length))

        root.seriesMetaDialog.errorText = ""
        editingSeriesKey = ""
        editingSeriesKeys = []
        editingSeriesTitle = ""
        editingSeriesDialogMode = "single"
        root.scheduleModelReconcile(true)
        startupControllerRef.requestSnapshotSave()
        return true
    }
}
