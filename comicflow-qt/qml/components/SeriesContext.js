.pragma library

function normalizedVolumeKey(volumeKey) {
    const key = String(volumeKey || "").trim()
    return key.length > 0 ? key : "__all__"
}

function normalizedVolumeTitle(volumeTitle, allVolumesTitle) {
    const title = String(volumeTitle || "").trim()
    if (title.length > 0) return title
    return String(allVolumesTitle || "All volumes")
}

function selectedContext(seriesKey, seriesTitle, volumeKey, volumeTitle, allVolumesTitle) {
    const normalizedSeriesKey = String(seriesKey || "").trim()
    const normalizedSeriesTitle = String(seriesTitle || "").trim()
    const normalizedVolume = normalizedVolumeKey(volumeKey)
    const normalizedVolumeLabel = normalizedVolumeTitle(volumeTitle, allVolumesTitle)
    return {
        seriesKey: normalizedSeriesKey,
        seriesTitle: normalizedSeriesTitle,
        volumeKey: normalizedVolume,
        volumeTitle: normalizedVolumeLabel,
        hasSeries: normalizedSeriesKey.length > 0,
        hasSpecificVolume: normalizedVolume !== "__all__"
    }
}
