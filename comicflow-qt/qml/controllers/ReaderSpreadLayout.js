.pragma library

function listLength(value) {
    if (Array.isArray(value)) {
        return value.length
    }
    if (value && typeof value.length === "number") {
        return Math.max(0, Number(value.length))
    }
    return 0
}

function listValueAt(value, index) {
    const normalizedIndex = Number(index || 0)
    const count = listLength(value)
    if (normalizedIndex < 0 || normalizedIndex >= count) {
        return undefined
    }
    return value[normalizedIndex]
}

function metricAt(metrics, pageIndex) {
    const normalizedIndex = Number(pageIndex || 0)
    if (normalizedIndex < 0 || normalizedIndex >= listLength(metrics)) {
        return { "width": 0, "height": 0, "entryName": "" }
    }
    const metric = listValueAt(metrics, normalizedIndex) || {}
    return {
        "width": Math.max(0, Number(metric.width || 0)),
        "height": Math.max(0, Number(metric.height || 0)),
        "entryName": String(metric.entryName || "")
    }
}

function normalizePageMetrics(rawMetrics, totalCount) {
    const total = Math.max(0, Number(totalCount || 0))
    const normalized = []
    for (let i = 0; i < total; i += 1) {
        normalized.push(metricAt(rawMetrics, i))
    }
    return normalized
}

function medianWidth(widths) {
    if (!Array.isArray(widths) || widths.length < 1) return 0
    const sorted = widths.slice(0).sort(function(left, right) { return left - right })
    const middleIndex = Math.floor(sorted.length / 2)
    if (sorted.length % 2 === 1) {
        return Number(sorted[middleIndex] || 0)
    }
    return (Number(sorted[middleIndex - 1] || 0) + Number(sorted[middleIndex] || 0)) / 2
}

function typicalPageWidth(metrics) {
    const widthsWithoutCover = []
    for (let i = 1; i < metrics.length; i += 1) {
        const width = Number((metrics[i] || {}).width || 0)
        if (width > 0) {
            widthsWithoutCover.push(width)
        }
    }
    if (widthsWithoutCover.length > 0) {
        return medianWidth(widthsWithoutCover)
    }

    const widths = []
    for (let i = 0; i < metrics.length; i += 1) {
        const width = Number((metrics[i] || {}).width || 0)
        if (width > 0) {
            widths.push(width)
        }
    }
    return medianWidth(widths)
}

function buildWideFlags(metrics, ordinaryWidth, thresholdFactor) {
    const flags = []
    const widthThreshold = Math.max(0, Number(ordinaryWidth || 0)) * Math.max(1, Number(thresholdFactor || 1))
    for (let i = 0; i < metrics.length; i += 1) {
        const metric = metrics[i] || {}
        const width = Number(metric.width || 0)
        const height = Number(metric.height || 0)
        const wideByWidth = widthThreshold > 0 && width > widthThreshold
        const wideByAspect = width > 0 && height > 0 && width > (height * 1.05)
        const wideByName = looksLikeMergedSpreadEntry(metric.entryName)
        flags.push(i > 0 && (wideByWidth || wideByAspect || wideByName))
    }
    return flags
}

function looksLikeMergedSpreadEntry(entryName) {
    const normalizedName = String(entryName || "").replace(/\\/g, "/")
    if (normalizedName.length < 1) return false

    const leafName = normalizedName.slice(normalizedName.lastIndexOf("/") + 1)
    const baseName = leafName.replace(/\.[^.]+$/, "")
    const numericGroups = baseName.match(/\d+/g) || []
    if (numericGroups.length < 3) return false

    const lastToken = String(numericGroups[numericGroups.length - 1] || "")
    const previousToken = String(numericGroups[numericGroups.length - 2] || "")
    if (lastToken.length < 2 || previousToken.length < 2) return false

    const lastNumber = Number(lastToken)
    const previousNumber = Number(previousToken)
    if (!isFinite(lastNumber) || !isFinite(previousNumber)) {
        return false
    }

    return Math.abs(lastNumber - previousNumber) === 1
}

function buildSpread(pageIndexes, kind) {
    const pages = Array.isArray(pageIndexes) ? pageIndexes.slice(0) : []
    return {
        "pageIndexes": pages,
        "kind": String(kind || ""),
        "anchorPageIndex": pages.length > 0 ? Number(pages[pages.length - 1]) : -1
    }
}

function buildPairSpread(leftPageIndex, rightPageIndex, kind, rtl) {
    if (Boolean(rtl)) {
        return buildSpread([rightPageIndex, leftPageIndex], kind)
    }
    return buildSpread([leftPageIndex, rightPageIndex], kind)
}

function buildTwoPageLayout(rawMetrics, totalCount, thresholdFactor, options) {
    const metrics = normalizePageMetrics(rawMetrics, totalCount)
    const pageCount = metrics.length
    const ordinaryWidth = typicalPageWidth(metrics)
    const wideFlags = buildWideFlags(metrics, ordinaryWidth, thresholdFactor)
    const spreads = []
    const rtl = Boolean(options && options.rtl)
    const spreadOffset = Boolean(options && options.spreadOffset)

    if (pageCount > 0) {
        spreads.push(buildSpread([0], "cover"))
    }

    let cursor = 1
    if (rtl && !spreadOffset && cursor < pageCount) {
        if (wideFlags[cursor]) {
            spreads.push(buildSpread([cursor], "wide"))
            cursor += 1
        } else {
            spreads.push(buildSpread([cursor], "offset_single_start"))
            cursor += 1
        }
    }

    while (cursor < pageCount) {
        if (wideFlags[cursor]) {
            spreads.push(buildSpread([cursor], "wide"))
            cursor += 1
            continue
        }

        if (cursor + 1 >= pageCount) {
            spreads.push(buildSpread([cursor], "tail"))
            cursor += 1
            continue
        }

        if (wideFlags[cursor + 1]) {
            spreads.push(buildSpread([cursor], "single_before_wide"))
            cursor += 1
            continue
        }

        spreads.push(buildPairSpread(cursor, cursor + 1, "pair", rtl))

        const bridgePageIndex = cursor + 2
        const wideAfterBridgeIndex = cursor + 3
        const canBridgeBeforeWide = bridgePageIndex < pageCount
            && wideAfterBridgeIndex < pageCount
            && !wideFlags[bridgePageIndex]
            && wideFlags[wideAfterBridgeIndex]

        if (canBridgeBeforeWide) {
            spreads.push(buildPairSpread(cursor + 1, cursor + 2, "bridge_before_wide", rtl))
            spreads.push(buildSpread([cursor + 3], "wide"))
            cursor += 4
            continue
        }

        cursor += 2
    }

    return {
        "ordinaryWidth": ordinaryWidth,
        "wideFlags": wideFlags,
        "spreads": spreads,
        "metrics": metrics
    }
}

function spreadIndexForPage(spreads, pageIndex) {
    const needle = Number(pageIndex || 0)
    const source = Array.isArray(spreads) ? spreads : []
    for (let i = 0; i < source.length; i += 1) {
        const spread = source[i] || {}
        const pageIndexes = Array.isArray(spread.pageIndexes) ? spread.pageIndexes : []
        for (let pageCursor = 0; pageCursor < pageIndexes.length; pageCursor += 1) {
            if (Number(pageIndexes[pageCursor]) === needle) {
                return i
            }
        }
    }
    return -1
}

function pageIndexesForPage(spreads, pageIndex) {
    const spreadIndex = spreadIndexForPage(spreads, pageIndex)
    if (spreadIndex < 0) return []
    const spread = spreads[spreadIndex] || {}
    return Array.isArray(spread.pageIndexes) ? spread.pageIndexes.slice(0) : []
}

function targetAnchorForOffset(spreads, pageIndex, offset) {
    const spreadIndex = spreadIndexForPage(spreads, pageIndex)
    if (spreadIndex < 0) return -1
    const targetSpread = spreads[spreadIndex + Number(offset || 0)] || {}
    if (!targetSpread || typeof targetSpread.anchorPageIndex === "undefined" || targetSpread.anchorPageIndex === null) {
        return -1
    }
    const anchorPageIndex = Number(targetSpread.anchorPageIndex)
    return isNaN(anchorPageIndex) ? -1 : anchorPageIndex
}

function canNavigate(spreads, pageIndex, offset) {
    return targetAnchorForOffset(spreads, pageIndex, offset) >= 0
}
