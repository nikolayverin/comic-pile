import QtQuick

Item {
    id: root

    ThemeColors { id: themeColors }

    property var options: []
    property string currentText: ""
    property string uiFontFamily: Qt.application.font.family
    property int textPixelSize: 13
    property color textColor: themeColors.settingsRadioTextColor
    property color indicatorColor: themeColors.settingsRadioIndicatorColor
    property color selectedDotColor: themeColors.settingsRadioSelectedDotColor
    property int indicatorSize: 20
    property int selectedDotSize: 8
    property int optionSpacing: 8
    property int optionGap: 10
    readonly property var normalizedOptions: buildNormalizedOptions()
    readonly property int maxTextWidth: calculateMaxTextWidth()

    signal activated(int index, string text)

    width: indicatorSize + optionGap + maxTextWidth
    height: normalizedOptions.length > 0
        ? (normalizedOptions.length * indicatorSize) + ((normalizedOptions.length - 1) * optionSpacing)
        : 0

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

    function calculateMaxTextWidth() {
        let maxWidth = 0
        const source = normalizedOptions
        for (let i = 0; i < source.length; i += 1) {
            widthMeasure.text = String(source[i] || "")
            maxWidth = Math.max(maxWidth, Math.ceil(widthMeasure.width))
        }
        return maxWidth
    }

    Column {
        anchors.fill: parent
        spacing: root.optionSpacing

        Repeater {
            model: root.normalizedOptions

            delegate: Item {
                required property int index
                required property string modelData

                width: root.width
                height: root.indicatorSize
                readonly property bool selected: String(modelData || "") === String(root.currentText || "")

                Rectangle {
                    id: optionIndicator
                    x: 0
                    y: 0
                    width: root.indicatorSize
                    height: root.indicatorSize
                    radius: Math.round(width / 2)
                    color: root.indicatorColor
                }

                Rectangle {
                    visible: parent.selected
                    width: root.selectedDotSize
                    height: root.selectedDotSize
                    radius: Math.round(width / 2)
                    color: root.selectedDotColor
                    anchors.centerIn: optionIndicator
                }

                Text {
                    x: root.indicatorSize + root.optionGap
                    y: Math.round((parent.height - implicitHeight) / 2)
                    text: parent.modelData
                    color: root.textColor
                    font.family: root.uiFontFamily
                    font.pixelSize: root.textPixelSize
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentText = parent.modelData
                        root.activated(index, parent.modelData)
                    }
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
