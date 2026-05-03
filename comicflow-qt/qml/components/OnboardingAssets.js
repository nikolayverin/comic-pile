.pragma library
.import "AppLanguageCatalog.js" as AppLanguageCatalog

var fallbackLanguageCode = AppLanguageCatalog.fallbackLanguageCode
var basePath = "qrc:/qt/qml/ComicPile/assets/ui/onboarding/"

var assetFiles = {
    back: "back.png",
    close: "close.png",
    next: "next.png",
    slash: "slash.png",
    step1: "step-1.png",
    step2: "step-2.png",
    step3: "step-3.png",
    step4: "step-4.png",
    step5Top: "step-5-1.png",
    step5Bottom: "step-5-2.png"
}

var localizedAssetKeysByLanguage = {
    de: { back: true, close: true, next: true, step1: true },
    es: { back: true, close: true, next: true, step1: true },
    fr: { back: true, close: true, next: true, step1: true },
    ja: { back: true, close: true, next: true, step1: true },
    ko: { back: true, close: true, next: true, step1: true },
    "zh-Hans": { back: true, close: true, next: true, step1: true }
}

function assetFile(assetKey) {
    const key = String(assetKey || "").trim()
    return String(assetFiles[key] || "")
}

function hasLocalizedAsset(languageCode, assetKey) {
    const languageAssets = localizedAssetKeysByLanguage[languageCode] || {}
    return languageAssets[String(assetKey || "").trim()] === true
}

function normalizedOnboardingLanguage(language) {
    const code = AppLanguageCatalog.normalizeLanguageCode(language)
    return AppLanguageCatalog.isOnboardingReady(code) ? code : fallbackLanguageCode
}

function sourceFor(assetKey, language) {
    const fileName = assetFile(assetKey)
    if (fileName.length < 1) {
        return ""
    }
    if (String(assetKey || "").trim() === "slash") {
        return basePath + fileName
    }

    const key = String(assetKey || "").trim()
    const languageCode = normalizedOnboardingLanguage(language)
    if (languageCode === fallbackLanguageCode || !hasLocalizedAsset(languageCode, key)) {
        return basePath + fileName
    }
    return basePath + languageCode + "/" + fileName
}
