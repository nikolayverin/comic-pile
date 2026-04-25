.pragma library

function pageCounterText(pageCount, pageIndex, displayPages) {
    const total = Math.max(0, Number(pageCount || 0))
    if (total < 1) return ""

    const pages = Array.isArray(displayPages) ? displayPages : []
    const indexes = []
    for (let i = 0; i < pages.length; i += 1) {
        const page = pages[i] || {}
        const index = Number(page.pageIndex)
        if (index < 0 || index >= total) continue
        if (indexes.indexOf(index) >= 0) continue
        indexes.push(index)
    }

    indexes.sort(function(left, right) { return left - right })

    if (indexes.length > 1) {
        return String(indexes[0] + 1) + "-" + String(indexes[indexes.length - 1] + 1) + "/" + String(total)
    }

    if (indexes.length === 1) {
        return String(indexes[0] + 1) + "/" + String(total)
    }

    return String(Number(pageIndex || 0) + 1) + "/" + String(total)
}

function pageListMenuItems(pageCount, pageIndex) {
    const total = Math.max(0, Number(pageCount || 0))
    const items = []
    for (let i = 0; i < total; i += 1) {
        items.push({
            text: String(i + 1),
            pageIndex: i,
            highlighted: i === Number(pageIndex || 0)
        })
    }
    return items
}

function hasDisplayContent(displayPages, imageSource) {
    const pages = Array.isArray(displayPages) ? displayPages : []
    for (let i = 0; i < pages.length; i += 1) {
        if (String((pages[i] || {}).imageSource || "").length > 0) {
            return true
        }
    }
    return String(imageSource || "").length > 0
}
