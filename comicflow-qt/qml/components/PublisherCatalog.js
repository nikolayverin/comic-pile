.pragma library

var majorPublisherEntries = [
    { name: "Marvel Comics", logoTokenKey: "publisherLogoMarvelComics" },
    { name: "DC Comics", logoTokenKey: "publisherLogoDcComics" },
    { name: "Image Comics", logoTokenKey: "publisherLogoImageComics" },
    { name: "Dark Horse Comics", logoTokenKey: "publisherLogoDarkHorseComics" },
    { name: "IDW Publishing", logoTokenKey: "publisherLogoIdwPublishing" },
    { name: "Boom! Studios", logoTokenKey: "publisherLogoBoomStudios" },
    { name: "Dynamite Entertainment", logoTokenKey: "publisherLogoDynamiteEntertainment" },
    { name: "Valiant Comics", logoTokenKey: "publisherLogoValiantComics" },
    { name: "AfterShock Comics", logoTokenKey: "publisherLogoAfterShockComics" },
    { name: "AWA Studios", logoTokenKey: "publisherLogoAwaStudios" },
    { name: "Oni Press", logoTokenKey: "publisherLogoOniPress" },
    { name: "Top Cow Productions", logoTokenKey: "publisherLogoTopCowProductions" },
    { name: "Aspen Comics", logoTokenKey: "" },
    { name: "Archie Comics", logoTokenKey: "" },
    { name: "Shueisha", logoTokenKey: "publisherLogoShueisha" },
    { name: "Kodansha", logoTokenKey: "" },
    { name: "Shogakukan", logoTokenKey: "" },
    { name: "Kadokawa Corporation", logoTokenKey: "" },
    { name: "Square Enix", logoTokenKey: "" },
    { name: "Hakusensha", logoTokenKey: "" },
    { name: "Dargaud", logoTokenKey: "" },
    { name: "Dupuis", logoTokenKey: "" },
    { name: "Glenat", logoTokenKey: "" },
    { name: "Casterman", logoTokenKey: "" },
    { name: "Delcourt", logoTokenKey: "" },
    { name: "Panini Comics", logoTokenKey: "" },
    { name: "Titan Comics", logoTokenKey: "" },
    { name: "Rebellion Developments", logoTokenKey: "" },
    { name: "Humanoids", logoTokenKey: "" },
    { name: "Viz Media", logoTokenKey: "" }
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
