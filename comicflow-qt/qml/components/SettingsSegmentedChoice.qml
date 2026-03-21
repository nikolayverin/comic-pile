import QtQuick

Item {
    id: root

    ThemeColors { id: themeColors }

    property var options: []
    property int currentIndex: -1
    property string currentText: ""
    property string uiFontFamily: Qt.application.font.family
    property int textPixelSize: 13
    property color trackColor: themeColors.settingsSegmentedTrackColor
    property color selectedFillColor: themeColors.settingsSegmentedSelectedFillColor
    property color selectedTextColor: themeColors.settingsSegmentedSelectedTextColor
    property color idleTextColor: themeColors.settingsSegmentedIdleTextColor
    property int selectionTransitionDuration: 180
    property int textTransitionDuration: 110
    readonly property int horizontalTextPadding: 12
    readonly property int outerInset: 2
    readonly property int buttonHeight: 20
    readonly property int trackHeight: buttonHeight + (outerInset * 2)
    readonly property int buttonRadius: Math.round(buttonHeight / 2)
    readonly property int trackRadius: Math.round(trackHeight / 2)
    readonly property var normalizedOptions: buildNormalizedOptions()
    readonly property var segmentWidths: buildSegmentWidths()
    readonly property int resolvedCurrentIndex: resolveCurrentIndex()
    readonly property int totalButtonsWidth: sumSegmentWidths()

    signal activated(int index, string text)

    width: totalButtonsWidth + (outerInset * 2)
    height: trackHeight

    function buildNormalizedOptions() {
        const source = options
        if (!source) return []
        if (Array.isArray(source)) {
            return source.map(function(item) { return String(item || "") })
        }
        if (typeof source.length === "number") {
            const normalized = []
            for (let i = 0; i < source.length; i += 1) {
                normalized.push(String(source[i] || ""))
            }
            return normalized
        }
        return []
    }

    function buildSegmentWidths() {
        const widths = []
        const source = normalizedOptions
        for (let i = 0; i < source.length; i += 1) {
            widthMeasure.text = String(source[i] || "")
            widths.push(Math.ceil(widthMeasure.width) + (horizontalTextPadding * 2))
        }
        return widths
    }

    function sumSegmentWidths() {
        let total = 0
        const source = segmentWidths
        for (let i = 0; i < source.length; i += 1) {
            total += Number(source[i] || 0)
        }
        return total
    }

    function segmentXAt(index) {
        let x = outerInset
        for (let i = 0; i < index; i += 1) {
            x += Number(segmentWidths[i] || 0)
        }
        return x
    }

    function indexOfCurrentText() {
        const target = String(currentText || "")
        const source = normalizedOptions
        for (let i = 0; i < source.length; i += 1) {
            if (String(source[i] || "") === target) {
                return i
            }
        }
        return -1
    }

    function resolveCurrentIndex() {
        const explicitIndex = Number(currentIndex)
        if (explicitIndex >= 0 && explicitIndex < normalizedOptions.length) {
            return explicitIndex
        }
        return indexOfCurrentText()
    }

    Rectangle {
        anchors.fill: parent
        radius: root.trackRadius
        color: root.trackColor
    }

    Rectangle {
        x: root.resolvedCurrentIndex >= 0 ? root.segmentXAt(root.resolvedCurrentIndex) : root.outerInset
        y: root.outerInset
        width: root.resolvedCurrentIndex >= 0
            ? Number(root.segmentWidths[root.resolvedCurrentIndex] || 0)
            : 0
        height: root.buttonHeight
        radius: root.buttonRadius
        color: root.selectedFillColor
        visible: width > 0

        Behavior on x {
            NumberAnimation {
                duration: root.selectionTransitionDuration
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: root.selectionTransitionDuration
                easing.type: Easing.InOutCubic
            }
        }
    }

    Repeater {
        model: root.normalizedOptions

        delegate: Item {
            required property int index
            required property string modelData

            x: root.segmentXAt(index)
            y: root.outerInset
            width: Number(root.segmentWidths[index] || 0)
            height: root.buttonHeight

            readonly property bool selected: index === root.resolvedCurrentIndex

            Text {
                anchors.centerIn: parent
                text: parent.modelData
                color: parent.selected ? root.selectedTextColor : root.idleTextColor
                font.family: root.uiFontFamily
                font.pixelSize: root.textPixelSize

                Behavior on color {
                    ColorAnimation {
                        duration: root.textTransitionDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.currentIndex = index
                    root.currentText = parent.modelData
                    root.activated(index, parent.modelData)
                }
            }
        }
    }

    TextMetrics {
        id: widthMeasure
        font.family: root.uiFontFamily
        font.pixelSize: root.textPixelSize
    }
}
