import QtQuick

QtObject {
    property real containerWidth: 0
    property int contentWidth: 872
    property int leftFieldWidth: 370
    property int smallFieldWidth: 110
    property int rightFieldWidth: 234
    property int fieldGap: 16

    readonly property int leftX: Math.round((containerWidth - contentWidth) / 2)
    readonly property int col1X: leftX + leftFieldWidth + fieldGap
    readonly property int col2X: col1X + smallFieldWidth + fieldGap
    readonly property int col3X: col2X + smallFieldWidth + fieldGap
    readonly property int rightX: leftX + contentWidth

    readonly property int creditsFieldWidth: Math.floor((contentWidth - fieldGap * 3) / 4)
    readonly property int creditsColStep: creditsFieldWidth + fieldGap
    readonly property int storyFieldWidth: Math.floor((contentWidth - fieldGap) / 2)
    readonly property int storyColStep: storyFieldWidth + fieldGap
}
