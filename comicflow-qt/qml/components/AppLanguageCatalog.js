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
