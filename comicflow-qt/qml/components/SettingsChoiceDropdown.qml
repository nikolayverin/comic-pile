import QtQuick
import QtQuick.Controls

Item {
    id: root

    ThemeColors { id: themeColors }
    PopupMenuStyle { id: popupMenuStyle }

    property var options: []
    property string currentText: ""
    property string uiFontFamily: Qt.application.font.family
    property int textPixelSize: 13
    property color textColor: themeColors.settingsChoiceTextColor
    property color fillColor: themeColors.settingsChoiceFillColor
    property int fieldHeight: 24
    property int fieldRadius: 12
    property int leftTextInset: 14
    property int textToArrowGap: 10
    property int rightInset: 10
    readonly property int arrowGlyphWidth: 11
    readonly property int arrowGlyphHeight: 5
    readonly property int computedWidth: Math.max(
        1,
        Math.ceil(maxOptionTextWidth) + leftTextInset + textToArrowGap + arrowGlyphWidth + rightInset
    )

    property real maxOptionTextWidth: 0

    signal activated(int index, string text)

    width: computedWidth
    height: fieldHeight

    function normalizedOptions() {
        const source = options
        if (!source) return []
        if (Array.isArray(source)) return source
        if (typeof source.length === "number") {
            const normalized = []
            for (let i = 0; i < source.length; i += 1) {
                normalized.push(source[i])
            }
            return normalized
        }
        return []
    }

    function refreshMaxOptionTextWidth() {
        let maxWidth = 0
        const source = normalizedOptions()
        for (let i = 0; i < source.length; i += 1) {
            widthMeasure.text = String(source[i] || "")
            maxWidth = Math.max(maxWidth, widthMeasure.width)
        }
        if (maxWidth < 1) {
            widthMeasure.text = String(currentText || "")
            maxWidth = Math.max(maxWidth, widthMeasure.width)
        }
        maxOptionTextWidth = maxWidth
    }

    function menuItems() {
        const source = normalizedOptions()
        return source.map(function(item) {
            const text = String(item || "")
            return {
                text: text,
                action: text,
                enabled: true,
                highlighted: text === String(root.currentText || "")
            }
        })
    }

    function openMenu() {
        dropdownPopup.openBelowItemCentered(root, root)
    }

    Component.onCompleted: refreshMaxOptionTextWidth()
    onOptionsChanged: refreshMaxOptionTextWidth()
    onUiFontFamilyChanged: refreshMaxOptionTextWidth()
    onTextPixelSizeChanged: refreshMaxOptionTextWidth()

    Rectangle {
        anchors.fill: parent
        radius: root.fieldRadius
        color: root.fillColor
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.leftTextInset
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentText
        color: root.textColor
        font.family: root.uiFontFamily
        font.pixelSize: root.textPixelSize
    }

    Canvas {
        id: indicatorGlyph
        width: root.arrowGlyphWidth
        height: root.arrowGlyphHeight
        anchors.right: parent.right
        anchors.rightMargin: root.rightInset
        anchors.verticalCenter: parent.verticalCenter
        contextType: "2d"

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.textColor
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width / 2, height)
            ctx.closePath()
            ctx.fill()
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openMenu()
    }

    ContextMenuPopup {
        id: dropdownPopup
        uiFontFamily: popupMenuStyle.uiFontFamily
        uiFontPixelSize: 13
        backgroundColor: popupMenuStyle.backgroundColor
        hoverColor: popupMenuStyle.hoverColor
        textColor: popupMenuStyle.textColor
        disabledTextColor: popupMenuStyle.disabledTextColor
        rowHeight: 24
        bodyRadius: popupMenuStyle.bodyRadius
        arrowWidth: popupMenuStyle.arrowWidth
        arrowHeight: popupMenuStyle.arrowHeight
        verticalOffset: popupMenuStyle.verticalOffset
        revealOffsetYHidden: popupMenuStyle.revealOffsetYHidden
        minWidth: root.width
        closeOnFocusLoss: false
        minBodyHeight: 40
        maxBodyHeight: 280
        menuItems: root.menuItems()

        onItemTriggered: function(index, action) {
            const selectedText = String(action || "")
            root.currentText = selectedText
            root.activated(index, selectedText)
        }
    }

    TextMetrics {
        id: widthMeasure
        font.family: root.uiFontFamily
        font.pixelSize: root.textPixelSize
    }
}
