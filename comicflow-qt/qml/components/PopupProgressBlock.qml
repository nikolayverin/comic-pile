import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    property QtObject popupStyle: PopupStyle {}
    property bool active: false
    property bool reserveSpace: false
    property bool showTitle: true
    property bool showFileRow: true
    property string titleText: "Current file"
    property string currentFileName: ""
    property int totalCount: 0
    property int processedCount: 0
    property real progressFraction: 0
    property string statusTextOverride: ""
    property bool forceIndeterminate: false

    readonly property real clampedFraction: Math.max(0, Math.min(1, progressFraction))
    readonly property int progressPercent: Math.round(clampedFraction * 100)
    readonly property int rightInfoWidth: popupStyle.importProgressRightInfoWidth
    readonly property bool singleItemMode: active && totalCount === 1
    readonly property bool indeterminate: forceIndeterminate || (active && totalCount <= 1)
    readonly property string fileCounterText: active && !indeterminate && totalCount > 0
        ? String(Math.max(0, Math.min(totalCount, processedCount))) + " / " + String(Math.max(0, totalCount))
        : ""
    readonly property string rightStatusText: !active
        ? ""
        : (statusTextOverride.length > 0
            ? statusTextOverride
            : (indeterminate
            ? (singleItemMode ? "Importing..." : "Working...")
            : (String(progressPercent) + "%")))

    visible: reserveSpace || active
    spacing: popupStyle.dialogPlainTextSpacing

    Label {
        visible: root.showTitle
        text: root.titleText
        color: popupStyle.textColor
        font.pixelSize: popupStyle.dialogHintFontSize
        Layout.fillWidth: true
    }

    RowLayout {
        visible: root.showFileRow
        Layout.fillWidth: true
        spacing: popupStyle.dialogInlineMetricGap

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            text: root.active ? root.currentFileName : ""
            color: popupStyle.textColor
            font.pixelSize: popupStyle.dialogBodyFontSize
        }

        Label {
            text: root.fileCounterText
            color: popupStyle.textColor
            font.pixelSize: popupStyle.dialogBodyFontSize
            Layout.preferredWidth: root.rightInfoWidth
            horizontalAlignment: Text.AlignRight
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: popupStyle.dialogInlineMetricGap

        Item {
            id: progressTrack
            Layout.fillWidth: true
            Layout.preferredHeight: popupStyle.importProgressBarHeight
            height: popupStyle.importProgressBarHeight
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: popupStyle.importProgressBarHeight / 2
                color: popupStyle.fieldFillColor
            }

            Rectangle {
                id: determinateFill
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.active && !root.indeterminate
                width: Math.round(parent.width * (root.active ? root.clampedFraction : 0))
                height: parent.height
                radius: popupStyle.importProgressBarHeight / 2
                color: popupStyle.importProgressBarColor
            }

            Rectangle {
                id: indeterminateFill
                visible: root.indeterminate
                y: 0
                width: Math.max(28, Math.round(progressTrack.width * 0.28))
                height: progressTrack.height
                radius: popupStyle.importProgressBarHeight / 2
                color: popupStyle.importProgressBarColor
                opacity: 0.95
                x: -width
            }

            SequentialAnimation {
                id: indeterminateAnimation
                running: root.indeterminate && progressTrack.width > 0
                loops: Animation.Infinite

                NumberAnimation {
                    target: indeterminateFill
                    property: "x"
                    from: -Math.max(28, Math.round(progressTrack.width * 0.28))
                    to: progressTrack.width
                    duration: 1050
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Label {
            text: root.rightStatusText
            color: popupStyle.textColor
            font.pixelSize: popupStyle.dialogBodyFontSize
            Layout.preferredWidth: root.rightInfoWidth
            horizontalAlignment: Text.AlignRight
        }
    }
}
