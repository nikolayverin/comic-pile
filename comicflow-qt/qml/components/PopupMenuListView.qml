import QtQuick
import QtQuick.Controls

Item {
    id: root

    PopupMenuStyle { id: popupMenuStyle }

    property var menuItems: []
    property string uiFontFamily: popupMenuStyle.uiFontFamily
    property int uiFontPixelSize: popupMenuStyle.uiFontPixelSize
    property color hoverColor: popupMenuStyle.hoverColor
    property color textColor: popupMenuStyle.textColor
    property color disabledTextColor: popupMenuStyle.disabledTextColor
    property int rowHeight: popupMenuStyle.rowHeight
    property int bodyRadius: popupMenuStyle.bodyRadius
    property int textHorizontalPadding: popupMenuStyle.textHorizontalPadding
    property int contentHorizontalPadding: popupMenuStyle.contentHorizontalPadding
    property bool centerText: false
    property int textWidthSafetyPadding: 4
    property int highlightInset: 1
    property bool reserveScrollGutter: false
    property int scrollGutterWidth: popupMenuStyle.scrollGutterWidth
    property int scrollThumbWidth: popupMenuStyle.scrollThumbWidth
    property int scrollThumbMinHeight: popupMenuStyle.scrollThumbMinHeight
    property color scrollThumbColor: popupMenuStyle.scrollThumbColor
    property int scrollThumbInset: popupMenuStyle.scrollThumbInset

    readonly property var visibleMenuItems: buildVisibleMenuItems()
    readonly property int visibleItemCount: visibleMenuItems.length
    property real computedTextWidth: 0
    readonly property real textBlockWidth: root.centerText
        ? Math.ceil(root.computedTextWidth + root.textWidthSafetyPadding)
        : Math.ceil(root.computedTextWidth + root.textWidthSafetyPadding) + (root.textHorizontalPadding * 2)
    readonly property real contentHeight: listView.contentHeight
    readonly property bool showsVerticalScrollThumb: reserveScrollGutter
        && listView.contentHeight > listView.height + 0.5
    readonly property real textBlockCenterOffset: reserveScrollGutter ? -Math.round(scrollGutterWidth / 2) : 0

    signal itemTriggered(int index, var item)

    Component.onCompleted: refreshComputedTextWidth()
    onVisibleMenuItemsChanged: refreshComputedTextWidth()
    onUiFontFamilyChanged: refreshComputedTextWidth()
    onUiFontPixelSizeChanged: refreshComputedTextWidth()

    function buildVisibleMenuItems() {
        const source = Array.isArray(menuItems) ? menuItems : []
        const filtered = []
        for (let i = 0; i < source.length; i += 1) {
            const item = source[i] || {}
            if (item.visible === false) continue
            filtered.push(item)
        }
        return filtered
    }

    function refreshComputedTextWidth() {
        let maxWidth = 0
        const source = visibleMenuItems
        for (let i = 0; i < source.length; i += 1) {
            textMeasure.text = String((source[i] || {}).text || "")
            maxWidth = Math.max(maxWidth, textMeasure.width)
        }
        computedTextWidth = maxWidth
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        model: root.visibleMenuItems
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: menuRow
            required property int index
            required property var modelData

            readonly property bool itemEnabled: modelData.enabled !== false
            readonly property bool firstVisibleRow: index === 0
            readonly property bool lastVisibleRow: index === root.visibleItemCount - 1
            readonly property bool singleVisibleRow: root.visibleItemCount === 1
            readonly property bool itemHighlighted: modelData.highlighted === true

            width: listView.width
            height: root.rowHeight
            color: "transparent"

            Canvas {
                anchors.fill: parent
                visible: itemMouseArea.containsMouse || menuRow.itemHighlighted
                onPaint: {
                    const ctx = getContext("2d")
                    const inset = Math.max(0, root.highlightInset)
                    const leftInset = inset
                    const rightInset = inset
                    const topInset = (menuRow.singleVisibleRow || menuRow.firstVisibleRow) ? inset : 0
                    const bottomInset = (menuRow.singleVisibleRow || menuRow.lastVisibleRow) ? inset : 0
                    const x0 = leftInset
                    const y0 = topInset
                    const w = Math.max(0, width - leftInset - rightInset)
                    const h = Math.max(0, height - topInset - bottomInset)
                    const radius = Math.min(Math.max(0, root.bodyRadius - inset), w / 2, h / 2)
                    const roundTopLeft = menuRow.singleVisibleRow || menuRow.firstVisibleRow
                    const roundTopRight = menuRow.singleVisibleRow || menuRow.firstVisibleRow
                    const roundBottomRight = menuRow.singleVisibleRow || menuRow.lastVisibleRow
                    const roundBottomLeft = menuRow.singleVisibleRow || menuRow.lastVisibleRow

                    ctx.reset()
                    ctx.beginPath()
                    ctx.moveTo(x0 + (roundTopLeft ? radius : 0), y0)
                    ctx.lineTo(x0 + w - (roundTopRight ? radius : 0), y0)
                    if (roundTopRight) ctx.quadraticCurveTo(x0 + w, y0, x0 + w, y0 + radius)
                    else ctx.lineTo(x0 + w, y0)
                    ctx.lineTo(x0 + w, y0 + h - (roundBottomRight ? radius : 0))
                    if (roundBottomRight) ctx.quadraticCurveTo(x0 + w, y0 + h, x0 + w - radius, y0 + h)
                    else ctx.lineTo(x0 + w, y0 + h)
                    ctx.lineTo(x0 + (roundBottomLeft ? radius : 0), y0 + h)
                    if (roundBottomLeft) ctx.quadraticCurveTo(x0, y0 + h, x0, y0 + h - radius)
                    else ctx.lineTo(x0, y0 + h)
                    ctx.lineTo(x0, y0 + (roundTopLeft ? radius : 0))
                    if (roundTopLeft) ctx.quadraticCurveTo(x0, y0, x0 + radius, y0)
                    else ctx.lineTo(x0, y0)
                    ctx.closePath()
                    ctx.fillStyle = root.hoverColor
                    ctx.fill()
                }
            }

            Item {
                width: Math.max(1, root.textBlockWidth)
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.textBlockCenterOffset
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: root.centerText ? 0 : root.textHorizontalPadding
                    anchors.rightMargin: root.centerText ? 0 : root.textHorizontalPadding
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(menuRow.modelData.text || "")
                    color: menuRow.itemEnabled ? root.textColor : root.disabledTextColor
                    font.family: root.uiFontFamily
                    font.pixelSize: root.uiFontPixelSize
                    horizontalAlignment: root.centerText ? Text.AlignHCenter : Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: parent.itemEnabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.itemTriggered(index, parent.modelData)
            }
        }
    }

    VerticalScrollThumb {
        id: scrollLayer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: root.scrollThumbInset
        anchors.bottomMargin: root.scrollThumbInset
        anchors.rightMargin: root.scrollThumbInset
        width: root.scrollGutterWidth
        visible: root.showsVerticalScrollThumb
        z: 2
        flickable: listView
        thumbWidth: root.scrollThumbWidth
        thumbMinHeight: root.scrollThumbMinHeight
        thumbInset: root.scrollThumbInset
        thumbColor: root.scrollThumbColor
    }

    TextMetrics {
        id: textMeasure
        font.family: root.uiFontFamily
        font.pixelSize: root.uiFontPixelSize
    }
}
