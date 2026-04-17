.pragma library

function formatDisplayIssueNumber(value) {
    const text = String(value || "").trim()
    if (text.length < 1) return ""
    const numericMatch = text.match(/^0*([0-9]+)(?:\.([0-9]+))?$/)
    if (numericMatch) {
        const integerPart = numericMatch[1] && numericMatch[1].length > 0 ? numericMatch[1] : "0"
        const decimalPart = numericMatch[2] || ""
        return decimalPart.length > 0 ? (integerPart + "." + decimalPart) : integerPart
    }

    let match = text.match(/^(.*?)(\s+#?\s*)(0*([0-9]+))(?:\.([0-9]+))?$/i)
    if (match && String(match[1] || "").trim().length > 0) {
        const prefix = String(match[1] || "").trim()
        const separator = String(match[2] || "").indexOf("#") >= 0 ? " #" : " "
        const integerPart = match[4] && match[4].length > 0 ? match[4] : "0"
        const decimalPart = match[5] || ""
        return decimalPart.length > 0
            ? (prefix + separator + integerPart + "." + decimalPart)
            : (prefix + separator + integerPart)
    }

    match = text.match(/^(.*?)(#\s*)(0*([0-9]+))(?:\.([0-9]+))?$/i)
    if (match && String(match[1] || "").trim().length > 0) {
        const prefix = String(match[1] || "").trim()
        const integerPart = match[4] && match[4].length > 0 ? match[4] : "0"
        const decimalPart = match[5] || ""
        return decimalPart.length > 0
            ? (prefix + "#" + integerPart + "." + decimalPart)
            : (prefix + "#" + integerPart)
    }

    return text
}
