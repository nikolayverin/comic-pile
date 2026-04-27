.pragma library

var fallbackLanguageCode = "en"

var languageOptions = [
    { code: "en", label: "English", ready: true },
    { code: "es", label: "Spanish", ready: false },
    { code: "de", label: "German", ready: false },
    { code: "fr", label: "French", ready: false },
    { code: "ja", label: "Japanese", ready: false },
    { code: "ko", label: "Korean", ready: false },
    { code: "zh-Hans", label: "Chinese Simplified", ready: false },
    { code: "zh-Hant", label: "Chinese Traditional", ready: false }
]

function allLanguages() {
    return languageOptions.slice(0)
}

function visibleLanguages() {
    const result = []
    for (let i = 0; i < languageOptions.length; i += 1) {
        const option = languageOptions[i] || {}
        if (option.ready === true) {
            result.push(option)
        }
    }
    return result
}

function languageCodes(includeHidden) {
    const source = includeHidden === true ? allLanguages() : visibleLanguages()
    const result = []
    for (let i = 0; i < source.length; i += 1) {
        result.push(String((source[i] || {}).code || ""))
    }
    return result
}

function languageLabels(includeHidden) {
    const source = includeHidden === true ? allLanguages() : visibleLanguages()
    const result = []
    for (let i = 0; i < source.length; i += 1) {
        result.push(String((source[i] || {}).label || ""))
    }
    return result
}

function languageForCode(code) {
    const normalized = String(code || "").trim()
    for (let i = 0; i < languageOptions.length; i += 1) {
        const option = languageOptions[i] || {}
        if (String(option.code || "") === normalized) {
            return option
        }
    }
    return null
}

function normalizeLanguageCode(code) {
    const option = languageForCode(code)
    return option ? String(option.code || fallbackLanguageCode) : fallbackLanguageCode
}

function isLanguageAvailable(code, includeHidden) {
    const option = languageForCode(code)
    return option !== null && (includeHidden === true || option.ready === true)
}

function mappedLanguageCodeForLocale(localeName) {
    const locale = String(localeName || "").trim().replace(/_/g, "-").toLowerCase()
    if (locale.length < 1) {
        return fallbackLanguageCode
    }

    if (locale.indexOf("zh") === 0) {
        if (locale.indexOf("hant") >= 0
                || locale.indexOf("zh-tw") === 0
                || locale.indexOf("zh-hk") === 0
                || locale.indexOf("zh-mo") === 0) {
            return "zh-Hant"
        }
        if (locale.indexOf("hans") >= 0
                || locale.indexOf("zh-cn") === 0
                || locale.indexOf("zh-sg") === 0) {
            return "zh-Hans"
        }
        return fallbackLanguageCode
    }

    const primary = locale.split("-")[0]
    if (primary === "es") return "es"
    if (primary === "de") return "de"
    if (primary === "fr") return "fr"
    if (primary === "ja") return "ja"
    if (primary === "ko") return "ko"
    return fallbackLanguageCode
}

function languageCodeForLocale(localeName, includeHidden) {
    const mapped = mappedLanguageCodeForLocale(localeName)
    return isLanguageAvailable(mapped, includeHidden) ? mapped : fallbackLanguageCode
}

function labelForCode(code) {
    const option = languageForCode(normalizeLanguageCode(code))
    return option ? String(option.label || "English") : "English"
}

function codeForLabel(label) {
    const normalized = String(label || "").trim()
    for (let i = 0; i < languageOptions.length; i += 1) {
        const option = languageOptions[i] || {}
        if (String(option.label || "") === normalized) {
            return String(option.code || fallbackLanguageCode)
        }
    }
    return fallbackLanguageCode
}
