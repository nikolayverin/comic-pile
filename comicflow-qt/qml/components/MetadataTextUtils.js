.pragma library

var _smallWords = {
    "a": true,
    "an": true,
    "and": true,
    "as": true,
    "at": true,
    "but": true,
    "by": true,
    "en": true,
    "for": true,
    "if": true,
    "in": true,
    "of": true,
    "on": true,
    "or": true,
    "per": true,
    "the": true,
    "to": true,
    "v": true,
    "via": true,
    "vs": true,
    "with": true
}

function trimAndCollapseWhitespace(text) {
    return String(text || "").replace(/\s+/g, " ").trim()
}

function normalizePreserveCaseText(text) {
    return trimAndCollapseWhitespace(text)
}

function normalizeYearText(text) {
    return trimAndCollapseWhitespace(text).replace(/[^\d]/g, "").slice(0, 4)
}

function _isRomanNumeral(word) {
    return /^[ivxlcdm]+$/i.test(String(word || ""))
}

function _normalizeSingleWord(word, preserveUppercase, forceCapitalize) {
    const source = String(word || "")
    if (source.length < 1) return ""
    if (!/[A-Za-z]/.test(source)) return source
    if (preserveUppercase && /^[A-Z0-9]+$/.test(source) && source.length <= 3) {
        return source.toUpperCase()
    }
    if (_isRomanNumeral(source)) {
        return source.toUpperCase()
    }

    const lower = source.toLowerCase()
    if (!forceCapitalize && _smallWords[lower]) {
        return lower
    }

    return lower.replace(/[A-Za-z]+/g, function(segment) {
        return segment.charAt(0).toUpperCase() + segment.slice(1)
    })
}

function normalizeTitleText(text) {
    const cleaned = trimAndCollapseWhitespace(text)
    if (cleaned.length < 1) return ""

    const words = cleaned.split(" ")
    return words.map(function(word, index) {
        const parts = word.split(/([\-\/&])/)
        return parts.map(function(part, partIndex) {
            if (/^[\-\/&]$/.test(part)) return part
            return _normalizeSingleWord(
                part,
                /^[A-Z0-9]+$/.test(part),
                index === 0 || partIndex > 0
            )
        }).join("")
    }).join(" ")
}

function normalizeNameListText(text) {
    const rawLines = String(text || "").split(/\r?\n/)
    const normalizedLines = rawLines.map(function(line) {
        const segments = line.split(",").map(function(item) {
            return normalizeTitleText(item)
        }).filter(function(item) {
            return item.length > 0
        })
        return segments.join(", ")
    }).filter(function(line) {
        return line.length > 0
    })
    return normalizedLines.join("\n")
}

function normalizeSentenceText(text) {
    const paragraphs = String(text || "").split(/\r?\n/)
    const normalized = paragraphs.map(function(paragraph) {
        const cleaned = trimAndCollapseWhitespace(paragraph)
        if (cleaned.length < 1) return ""
        return cleaned.replace(/(^|[.!?]\s+)([a-zа-яё])/g, function(_, prefix, letter) {
            return prefix + letter.toUpperCase()
        })
    }).filter(function(paragraph) {
        return paragraph.length > 0
    })
    return normalized.join("\n")
}

function _levenshtein(a, b) {
    const left = String(a || "")
    const right = String(b || "")
    const rows = left.length + 1
    const cols = right.length + 1
    const table = new Array(rows)

    for (let row = 0; row < rows; row += 1) {
        table[row] = new Array(cols)
        table[row][0] = row
    }
    for (let col = 0; col < cols; col += 1) {
        table[0][col] = col
    }

    for (let row = 1; row < rows; row += 1) {
        for (let col = 1; col < cols; col += 1) {
            const cost = left.charAt(row - 1) === right.charAt(col - 1) ? 0 : 1
            table[row][col] = Math.min(
                table[row - 1][col] + 1,
                table[row][col - 1] + 1,
                table[row - 1][col - 1] + cost
            )
        }
    }

    return table[rows - 1][cols - 1]
}

function normalizeMonthName(text, monthOptions) {
    const cleaned = trimAndCollapseWhitespace(text)
    if (cleaned.length < 1) return ""

    const options = Array.isArray(monthOptions) ? monthOptions.filter(function(item) {
        return String(item || "").trim().length > 0
    }) : []
    const lower = cleaned.toLowerCase()

    for (let i = 0; i < options.length; i += 1) {
        const option = String(options[i] || "").trim()
        if (option.toLowerCase() === lower) {
            return option
        }
    }

    const prefixMatches = options.filter(function(option) {
        return String(option).toLowerCase().indexOf(lower) === 0
    })
    if (prefixMatches.length === 1) {
        return prefixMatches[0]
    }

    if (lower.length >= 3) {
        const shortPrefixMatches = options.filter(function(option) {
            return String(option).toLowerCase().indexOf(lower.slice(0, 3)) === 0
        })
        if (shortPrefixMatches.length === 1) {
            return shortPrefixMatches[0]
        }
    }

    let bestMatch = ""
    let bestDistance = Number.MAX_SAFE_INTEGER
    let bestCount = 0
    for (let i = 0; i < options.length; i += 1) {
        const option = String(options[i] || "").trim()
        const distance = _levenshtein(lower, option.toLowerCase())
        if (distance < bestDistance) {
            bestDistance = distance
            bestMatch = option
            bestCount = 1
        } else if (distance === bestDistance) {
            bestCount += 1
        }
    }

    if (bestCount === 1 && bestDistance <= 2) {
        return bestMatch
    }

    return normalizeTitleText(cleaned)
}

function normalizeChoiceText(text, options) {
    const cleaned = trimAndCollapseWhitespace(text)
    if (cleaned.length < 1) return ""

    const sourceOptions = Array.isArray(options) ? options.filter(function(item) {
        return String(item || "").trim().length > 0
    }) : []
    const lower = cleaned.toLowerCase()

    for (let i = 0; i < sourceOptions.length; i += 1) {
        const option = String(sourceOptions[i] || "").trim()
        if (option.toLowerCase() === lower) {
            return option
        }
    }

    const prefixMatches = sourceOptions.filter(function(option) {
        return String(option).toLowerCase().indexOf(lower) === 0
    })
    if (prefixMatches.length === 1) {
        return String(prefixMatches[0] || "")
    }

    return cleaned
}
