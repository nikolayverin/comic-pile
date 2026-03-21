import QtQuick

Item {
    id: root

    Typography { id: typography }
    ThemeColors { id: themeColors }
    PopupStyle { id: popupStyle }

    property int buttonHeight: 24
    property string status: "idle"
    property string idleText: "Verify"
    property string runningText: "Verifying"
    property string successText: "Verified"
    property string failureText: "Failed"
    property string detailText: ""
    property color detailTextColor: themeColors.popupStatusDetailTextColor
    property int detailTextPixelSize: 10
    property int detailTopGap: 2
    property bool enabled: true
    property int textPixelSize: typography.uiBasePx
    property color textColor: popupStyle.textColor
    property color idleColor: popupStyle.footerButtonIdleColor
    property color hoverColor: popupStyle.footerButtonHoverColor
    property color idleEdgeColor: themeColors.lineTopbarBottom
    property color hoverEdgeColor: themeColors.popupActionHoverEdgeColor
    property color pressedColor: themeColors.popupActionPressedColor
    property color pressedEdgeColor: themeColors.popupActionPressedEdgeColor
    property int cornerRadius: Math.round(buttonHeight / 2)
    property int edgeOffsetPx: 1
    property int horizontalPadding: 14
    property int minimumWidth: 96
    property int indicatorSlotWidth: 14
    property int indicatorGap: 8
    property color successColor: themeColors.popupSuccessColor
    property color failureColor: themeColors.popupFailureColor

    readonly property bool busy: status === "running"
    readonly property bool clickable: enabled && !busy
    readonly property bool hasDetailText: String(detailText || "").trim().length > 0
    readonly property string displayText: status === "running"
        ? runningText
        : status === "success"
            ? successText
            : status === "failure"
                ? failureText
                : idleText
    readonly property real contentWidth: maxLabelWidth + indicatorGap + indicatorSlotWidth
    readonly property real maxLabelWidth: Math.max(
        idleMetrics.advanceWidth,
        runningMetrics.advanceWidth,
        successMetrics.advanceWidth,
        failureMetrics.advanceWidth
    )

    signal clicked()

    height: implicitHeight
    implicitWidth: Math.max(
        minimumWidth,
        Math.ceil(contentWidth) + (horizontalPadding * 2)
    )
    implicitHeight: buttonHeight + (hasDetailText ? detailTopGap + Math.ceil(detailMetrics.height) : 0)
    opacity: enabled ? 1.0 : 0.45

    TextMetrics {
        id: idleMetrics
        font.pixelSize: root.textPixelSize
        text: root.idleText
    }

    TextMetrics {
        id: runningMetrics
        font.pixelSize: root.textPixelSize
        text: root.runningText
    }

    TextMetrics {
        id: successMetrics
        font.pixelSize: root.textPixelSize
        text: root.successText
    }

    TextMetrics {
        id: failureMetrics
        font.pixelSize: root.textPixelSize
        text: root.failureText
    }

    TextMetrics {
        id: detailMetrics
        font.pixelSize: root.detailTextPixelSize
        text: root.hasDetailText ? root.detailText : " "
    }

    InsetEdgeSurface {
        width: parent.width
        height: root.buttonHeight
        cornerRadius: root.cornerRadius
        fillColor: actionMouseArea.pressed && root.clickable
            ? root.pressedColor
            : actionMouseArea.containsMouse && root.clickable
                ? root.hoverColor
                : root.idleColor
        edgeColor: actionMouseArea.pressed && root.clickable
            ? root.pressedEdgeColor
            : actionMouseArea.containsMouse && root.clickable
                ? root.hoverEdgeColor
                : root.idleEdgeColor
        fillOffsetY: actionMouseArea.pressed && root.clickable
            ? root.edgeOffsetPx
            : actionMouseArea.containsMouse && root.clickable
                ? root.edgeOffsetPx
                : -root.edgeOffsetPx
    }

    Item {
        width: root.contentWidth
        height: root.buttonHeight
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayText
            color: root.textColor
            font.pixelSize: root.textPixelSize
        }

        Item {
            x: root.maxLabelWidth + root.indicatorGap
            width: root.indicatorSlotWidth
            height: root.indicatorSlotWidth
            anchors.verticalCenter: parent.verticalCenter

            ShuffleBusySpinner {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                running: root.status === "running"
                visible: running
            }

            Canvas {
                anchors.fill: parent
                visible: root.status === "success"
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.beginPath()
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.lineWidth = 2.6
                    ctx.strokeStyle = root.successColor
                    ctx.moveTo(width * 0.18, height * 0.56)
                    ctx.lineTo(width * 0.42, height * 0.8)
                    ctx.lineTo(width * 0.84, height * 0.2)
                    ctx.stroke()
                }
            }

            Canvas {
                anchors.fill: parent
                visible: root.status === "failure"
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.beginPath()
                    ctx.lineCap = "round"
                    ctx.lineWidth = 2.8
                    ctx.strokeStyle = root.failureColor
                    ctx.moveTo(width * 0.5, height * 0.14)
                    ctx.lineTo(width * 0.5, height * 0.68)
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.fillStyle = root.failureColor
                    ctx.arc(width * 0.5, height * 0.88, width * 0.08, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }

    Text {
        anchors.top: parent.top
        anchors.topMargin: root.buttonHeight + root.detailTopGap
        anchors.right: parent.right
        width: parent.width
        visible: root.hasDetailText
        text: root.detailText
        color: root.detailTextColor
        font.pixelSize: root.detailTextPixelSize
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    MouseArea {
        id: actionMouseArea
        width: parent.width
        height: root.buttonHeight
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
