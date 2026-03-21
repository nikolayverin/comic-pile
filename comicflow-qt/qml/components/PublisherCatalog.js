.pragma library

// Logo integration workflow:
// - keep the source logo filename suffix descriptive on the design side (for example `-wide`, `-tall`, `-round`)
// - when adding the logo to the app, set `logoLayoutKind` explicitly here
// - the app should not guess the display class from the publisher name

var majorPublisherEntries = [
    { name: "Marvel Comics", logoTokenKey: "publisherLogoMarvelComics", logoLayoutKind: "wide" },
    { name: "DC Comics", logoTokenKey: "publisherLogoDcComics", logoLayoutKind: "round" },
    { name: "Image Comics", logoTokenKey: "publisherLogoImageComics", logoLayoutKind: "tall" },
    { name: "Dark Horse Comics", logoTokenKey: "publisherLogoDarkHorseComics", logoLayoutKind: "tall" },
    { name: "IDW Publishing", logoTokenKey: "publisherLogoIdwPublishing", logoLayoutKind: "wide" },
    { name: "Boom! Studios", logoTokenKey: "publisherLogoBoomStudios", logoLayoutKind: "standard" },
    { name: "Dynamite Entertainment", logoTokenKey: "publisherLogoDynamiteEntertainment", logoLayoutKind: "wide" },
    { name: "Valiant Comics", logoTokenKey: "publisherLogoValiantComics", logoLayoutKind: "tall" },
    { name: "AfterShock Comics", logoTokenKey: "publisherLogoAfterShockComics", logoLayoutKind: "standard" },
    { name: "AWA Studios", logoTokenKey: "publisherLogoAwaStudios", logoLayoutKind: "standard" },
    { name: "Oni Press", logoTokenKey: "publisherLogoOniPress", logoLayoutKind: "standard" },
    { name: "Top Cow Productions", logoTokenKey: "publisherLogoTopCowProductions", logoLayoutKind: "wide" },
    { name: "Aspen Comics", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Archie Comics", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Shueisha", logoTokenKey: "publisherLogoShueisha", logoLayoutKind: "standard" },
    { name: "Kodansha", logoTokenKey: "", logoLayoutKind: "tall" },
    { name: "Shogakukan", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Kadokawa Corporation", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Square Enix", logoTokenKey: "", logoLayoutKind: "tall" },
    { name: "Hakusensha", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Dargaud", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Dupuis", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Glenat", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Casterman", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Delcourt", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Panini Comics", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Titan Comics", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Rebellion Developments", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Humanoids", logoTokenKey: "", logoLayoutKind: "standard" },
    { name: "Viz Media", logoTokenKey: "", logoLayoutKind: "standard" }
]

var publisherAliasToName = {
    "marvel": "Marvel Comics",
    "marvel comics": "Marvel Comics",
    "dc": "DC Comics",
    "dc comics": "DC Comics",
    "image": "Image Comics",
    "image comics": "Image Comics",
    "dark horse": "Dark Horse Comics",
    "dark horse comics": "Dark Horse Comics",
    "idw": "IDW Publishing",
    "idw publishing": "IDW Publishing",
    "boom": "Boom! Studios",
    "boom studio": "Boom! Studios",
    "boom studios": "Boom! Studios",
    "dynamite": "Dynamite Entertainment",
    "dynamite entertainment": "Dynamite Entertainment",
    "valiant": "Valiant Comics",
    "valiant comics": "Valiant Comics",
    "aftershock": "AfterShock Comics",
    "aftershock comics": "AfterShock Comics",
    "awa": "AWA Studios",
    "awa studios": "AWA Studios",
    "oni": "Oni Press",
    "oni press": "Oni Press",
    "top cow": "Top Cow Productions",
    "top cow productions": "Top Cow Productions",
    "aspen": "Aspen Comics",
    "aspen comics": "Aspen Comics",
    "archie": "Archie Comics",
    "archie comics": "Archie Comics",
    "shueisha": "Shueisha",
    "kodansha": "Kodansha",
    "shogakukan": "Shogakukan",
    "kadokawa": "Kadokawa Corporation",
    "kadokawa corporation": "Kadokawa Corporation",
    "square enix": "Square Enix",
    "hakusensha": "Hakusensha",
    "dargaud": "Dargaud",
    "dupuis": "Dupuis",
    "glenat": "Glenat",
    "casterman": "Casterman",
    "delcourt": "Delcourt",
    "panini": "Panini Comics",
    "panini comics": "Panini Comics",
    "titan": "Titan Comics",
    "titan comics": "Titan Comics",
    "rebellion": "Rebellion Developments",
    "rebellion developments": "Rebellion Developments",
    "humanoids": "Humanoids",
    "humanoids inc": "Humanoids",
    "viz": "Viz Media",
    "viz media": "Viz Media"
}

function normalizePublisherKey(value) {
    let normalized = String(value || "").toLowerCase().trim()
    if (normalized.length < 1)
        return ""
    normalized = normalized.replace(/&/g, " and ")
    normalized = normalized.replace(/[^a-z0-9]+/g, " ")
    normalized = normalized.replace(/\s+/g, " ").trim()
    return normalized
}

function canonicalPublisherName(value) {
    const normalizedKey = normalizePublisherKey(value)
    if (normalizedKey.length < 1)
        return ""
    return String(publisherAliasToName[normalizedKey] || "")
}

function displayPublisherName(value) {
    const raw = String(value || "").trim()
    if (raw.length < 1)
        return ""
    const canonical = canonicalPublisherName(raw)
    return canonical.length > 0 ? canonical : raw
}

function logoTokenKeyForPublisher(value) {
    const canonical = canonicalPublisherName(value)
    if (canonical.length < 1)
        return ""
    for (let i = 0; i < majorPublisherEntries.length; i += 1) {
        const entry = majorPublisherEntries[i] || {}
        if (String(entry.name || "") === canonical)
            return String(entry.logoTokenKey || "")
    }
    return ""
}

function publisherEntryForPublisher(value) {
    const canonical = canonicalPublisherName(value)
    if (canonical.length < 1)
        return null
    for (let i = 0; i < majorPublisherEntries.length; i += 1) {
        const entry = majorPublisherEntries[i] || {}
        if (String(entry.name || "") === canonical)
            return entry
    }
    return null
}

function logoLayoutForPublisher(value) {
    const entry = publisherEntryForPublisher(value)
    const kind = entry ? String(entry.logoLayoutKind || "standard") : "standard"

    if (kind === "round") {
        return {
            kind: "round",
            maxWidth: 99,
            maxHeight: 99
        }
    }

    if (kind === "wide") {
        return {
            kind: "wide",
            maxWidth: 162,
            maxHeight: 68
        }
    }

    if (kind === "tall") {
        return {
            kind: "tall",
            maxWidth: 90,
            maxHeight: 126
        }
    }

    return {
        kind: "standard",
        maxWidth: 126,
        maxHeight: 99
    }
}

function majorPublisherNames() {
    const names = []
    for (let i = 0; i < majorPublisherEntries.length; i += 1) {
        const entry = majorPublisherEntries[i] || {}
        const name = String(entry.name || "")
        if (name.length > 0)
            names.push(name)
    }
    return names
}
