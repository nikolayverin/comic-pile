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

function assetFile(assetKey) {
    const key = String(assetKey || "").trim()
    return String(assetFiles[key] || "")
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

    const languageCode = normalizedOnboardingLanguage(language)
    if (languageCode === fallbackLanguageCode) {
        return basePath + fileName
    }
    return basePath + languageCode + "/" + fileName
}
