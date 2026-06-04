.pragma library
.import "AppLanguageCatalog.js" as AppLanguageCatalog

var fallbackLanguageCode = AppLanguageCatalog.fallbackLanguageCode
var localizedSectionsCache = ({})

var emergencySections = [
    {
        key: "getting_started",
        label: "Help",
        iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-popup-info.svg",
        leadHtml: "Help content could not be loaded.",
        subsections: [
            {
                key: "help_unavailable",
                label: "Help content is unavailable",
                bodyHtml: "Comic Pile could not load the built-in Help files. Restart the app or reinstall the current release package."
            }
        ]
    }
]

function cloneValue(value) {
    if (Array.isArray(value)) {
        const result = []
        for (let i = 0; i < value.length; i += 1) {
            result.push(cloneValue(value[i]))
        }
        return result
    }
    if (value && typeof value === "object") {
        const objectResult = ({})
        const keys = Object.keys(value)
        for (let i = 0; i < keys.length; i += 1) {
            const key = keys[i]
            objectResult[key] = cloneValue(value[key])
        }
        return objectResult
    }
    return value
}

function normalizedLanguageCode(language) {
    return AppLanguageCatalog.normalizeLanguageCode(language)
}

function helpContentUrls(language) {
    const fileName = "help." + normalizedLanguageCode(language) + ".json"
    return [
        "qrc:/qt/qml/ComicPile/content/help/" + fileName,
        "qrc:///qt/qml/ComicPile/content/help/" + fileName,
        ":/qt/qml/ComicPile/content/help/" + fileName
    ]
}

function sectionsFromJsonText(rawText) {
    const text = String(rawText || "").trim()
    if (!text.length) {
        return null
    }

    const parsed = JSON.parse(text)
    if (parsed && Array.isArray(parsed.sections)) {
        return parsed.sections
    }
    return null
}

function readBundledSections(language, bundledContentByLanguage) {
    if (!bundledContentByLanguage || typeof bundledContentByLanguage !== "object") {
        return null
    }

    const normalized = normalizedLanguageCode(language)
    if (bundledContentByLanguage[normalized] !== undefined) {
        return sectionsFromJsonText(bundledContentByLanguage[normalized])
    }

    if (bundledContentByLanguage[fallbackLanguageCode] !== undefined) {
        return sectionsFromJsonText(bundledContentByLanguage[fallbackLanguageCode])
    }

    return null
}

function readLocalizedSections(language, bundledContentByLanguage) {
    const normalized = normalizedLanguageCode(language)
    if (localizedSectionsCache[normalized] !== undefined) {
        return localizedSectionsCache[normalized]
    }

    let parsedSections = null
    try {
        parsedSections = readBundledSections(normalized, bundledContentByLanguage)
    } catch (error) {
        parsedSections = null
    }

    if (parsedSections) {
        localizedSectionsCache[normalized] = parsedSections
        return parsedSections
    }

    const urls = helpContentUrls(normalized)
    for (let i = 0; i < urls.length; i += 1) {
        const url = String(urls[i] || "")
        if (!url.length) {
            continue
        }
        try {
            const request = new XMLHttpRequest()
            request.open("GET", url, false)
            request.send()
            const responseText = String(request.responseText || "").trim()
            if ((request.status === 0 || request.status === 200) && responseText.length > 0) {
                parsedSections = sectionsFromJsonText(responseText)
                if (parsedSections) {
                    break
                }
            }
        } catch (error) {
            parsedSections = null
        }
    }

    if (!parsedSections) {
        console.warn("Comic Pile Help content could not be loaded for language", normalized)
    }

    localizedSectionsCache[normalized] = parsedSections
    return parsedSections
}

function mergeObject(baseObject, localizedObject) {
    const result = cloneValue(baseObject || ({}))
    if (!localizedObject || typeof localizedObject !== "object") {
        return result
    }

    const keys = Object.keys(localizedObject)
    for (let i = 0; i < keys.length; i += 1) {
        const key = keys[i]
        if (key === "subsections" && Array.isArray(result.subsections) && Array.isArray(localizedObject.subsections)) {
            result.subsections = mergeByKey(result.subsections, localizedObject.subsections)
            continue
        }
        result[key] = cloneValue(localizedObject[key])
    }
    return result
}

function mergeByKey(baseList, localizedList) {
    const result = []
    const localizedByKey = ({})
    for (let i = 0; i < localizedList.length; i += 1) {
        const entry = localizedList[i] || {}
        const key = String(entry.key || "").trim()
        if (key.length > 0) {
            localizedByKey[key] = entry
        }
    }

    for (let i = 0; i < baseList.length; i += 1) {
        const baseEntry = baseList[i] || {}
        const key = String(baseEntry.key || "").trim()
        result.push(mergeObject(baseEntry, localizedByKey[key]))
    }
    return result
}

function helpSections(language, bundledContentByLanguage) {
    const fallbackSections = readLocalizedSections(fallbackLanguageCode, bundledContentByLanguage) || emergencySections
    const normalized = normalizedLanguageCode(language)
    if (normalized === fallbackLanguageCode) {
        return cloneValue(fallbackSections)
    }

    const localizedSections = readLocalizedSections(normalized, bundledContentByLanguage)
    if (!localizedSections) {
        return cloneValue(fallbackSections)
    }

    return mergeByKey(fallbackSections, localizedSections)
}
