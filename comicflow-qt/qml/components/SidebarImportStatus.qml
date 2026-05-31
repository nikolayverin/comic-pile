import QtQuick
import "AppText.js" as AppText

Item {
    id: status

    ThemeColors { id: themeColors }
    Typography { id: typography }

    property string textLanguage: AppText.fallbackLanguageCode
    property string uiFontFamily: Qt.application.font.family
    property int uiFontPixelSize: typography.uiBasePx
    property color textColor: themeColors.textPrimary
    property color subtleTextColor: themeColors.textMuted
    property color textShadowColor: themeColors.uiTextShadow
    property color progressColor: themeColors.importProgressBarColor
    property color progressTrackColor: "#050505"
    property color buttonIdleColor: themeColors.popupFillColor
    property color buttonHoverColor: themeColors.uiActionHoverBackground
    property color buttonTextColor: themeColors.textPrimary
    property string showPopupIconSource: ""
    property string alertIconSource: ""
    property string currentFileName: ""
    property string attentionText: ""
    property int totalCount: 0
    property int processedCount: 0
    property double totalBytes: 0
    property double processedBytes: 0
    property bool cancelPending: false
    property bool cleanupActive: false
    property string statusTitle: AppText.t("importStatusTitle", textLanguage)
    readonly property bool attentionActive: attentionText.length > 0

    signal cancelRequested()
    signal showPopupRequested()

    readonly property bool cancelFlowActive: cancelPending || cleanupActive
    readonly property real progressFraction: {
        if (totalBytes > 0) {
            return Math.max(0, Math.min(1, processedBytes / totalBytes))
        }
        if (totalCount > 0) {
            return Math.max(0, Math.min(1, processedCount / totalCount))
        }
        return 0
    }
    readonly property int progressPercent: Math.round(progressFraction * 100)
    readonly property int safeTotalCount: Math.max(0, totalCount)
    readonly property int safeProcessedCount: safeTotalCount > 0
        ? Math.max(0, Math.min(safeTotalCount, processedCount))
        : Math.max(0, processedCount)
    readonly property string countText: safeTotalCount > 0
        ? (String(safeProcessedCount) + " / " + String(safeTotalCount))
        : ""
    readonly property string effectiveFileName: currentFileName.length > 0
        ? currentFileName
        : (cancelPending
            ? AppText.t("importProgressWaitingSafeStop", textLanguage)
            : AppText.t("importProgressPreparingImport", textLanguage))

    Item {
        id: contentGroup
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        height: 86
    }

    Text {
        id: titleText
        parent: contentGroup
        x: 0
        y: 0
        text: status.cancelFlowActive
            ? AppText.t("importProgressTitleCancelling", status.textLanguage)
            : status.statusTitle
        color: status.textColor
        font.family: status.uiFontFamily
        font.pixelSize: status.uiFontPixelSize
        font.bold: true
    }

    Item {
        id: showPopupButton
        parent: contentGroup
        x: Math.round(titleText.x + titleText.implicitWidth + 8)
        y: Math.round(titleText.y + (titleText.implicitHeight - height) / 2)
        width: 16
        height: 16

        Image {
            anchors.centerIn: parent
            width: 15
            height: 15
            source: status.showPopupIconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: showPopupMouseArea.containsMouse ? 1.0 : 0.9
        }

        MouseArea {
            id: showPopupMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: status.showPopupRequested()
        }
    }

    Text {
        id: countTextItem
        parent: contentGroup
        x: showPopupButton.x + showPopupButton.width + 8
        anchors.verticalCenter: titleText.verticalCenter
        text: status.countText
        color: status.textColor
        font.family: status.uiFontFamily
        font.pixelSize: status.uiFontPixelSize
    }

    Item {
        id: cancelButton
        parent: contentGroup
        width: 76
        height: 22
        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.verticalCenter: titleText.verticalCenter
        opacity: status.cancelFlowActive ? 0.55 : 1.0

        InsetEdgeSurface {
            anchors.fill: parent
            cornerRadius: 11
            fillColor: cancelMouseArea.containsMouse && !status.cancelFlowActive
                ? status.buttonHoverColor
                : status.buttonIdleColor
            edgeColor: "#101010"
            fillOffsetY: cancelMouseArea.containsMouse && !status.cancelFlowActive ? 1 : -1
        }

        Text {
            anchors.centerIn: parent
            text: status.cancelFlowActive
                ? AppText.t("importProgressCancelling", status.textLanguage)
                : AppText.t("commonCancel", status.textLanguage)
            color: status.buttonTextColor
            font.family: status.uiFontFamily
            font.pixelSize: Math.max(10, status.uiFontPixelSize - 1)
            elide: Text.ElideRight
            width: parent.width - 12
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: cancelMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !status.cancelFlowActive
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: status.cancelRequested()
        }
    }

    Text {
        id: currentFileText
        parent: contentGroup
        x: 0
        y: 48
        width: parent.width
        text: AppText.t("importStatusCurrentFile", status.textLanguage) + " " + status.effectiveFileName
        color: status.textColor
        font.family: status.uiFontFamily
        font.pixelSize: status.uiFontPixelSize
        elide: Text.ElideRight
    }

    Item {
        id: attentionRow
        parent: contentGroup
        x: 0
        y: 23
        width: parent.width
        height: 22
        visible: status.attentionActive

        Image {
            id: attentionIcon
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 15
            height: 15
            source: status.alertIconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            id: attentionTextItem
            x: attentionIcon.x + attentionIcon.width + 6
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, showButton.x - x - 8)
            text: status.attentionText
            color: status.textColor
            font.family: status.uiFontFamily
            font.pixelSize: status.uiFontPixelSize
            elide: Text.ElideRight
        }

        Item {
            id: showButton
            width: 64
            height: 22
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            InsetEdgeSurface {
                anchors.fill: parent
                cornerRadius: 11
                fillColor: showMouseArea.containsMouse
                    ? status.buttonHoverColor
                    : status.buttonIdleColor
                edgeColor: "#101010"
                fillOffsetY: showMouseArea.containsMouse ? 1 : -1
            }

            Text {
                anchors.centerIn: parent
                text: AppText.t("importStatusShow", status.textLanguage)
                color: status.buttonTextColor
                font.family: status.uiFontFamily
                font.pixelSize: Math.max(10, status.uiFontPixelSize - 1)
                elide: Text.ElideRight
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                id: showMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: status.showPopupRequested()
            }
        }
    }

    Row {
        id: progressRow
        parent: contentGroup
        x: 0
        y: 74
        width: contentGroup.width
        height: 18
        spacing: 12

        Rectangle {
            width: Math.max(1, progressRow.width - percentText.width - progressRow.spacing)
            height: 10
            radius: 5
            color: status.progressTrackColor
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: status.progressFraction > 0
                    ? Math.max(1, Math.round(parent.width * status.progressFraction))
                    : 0
                height: parent.height
                radius: parent.radius
                color: status.progressColor
            }
        }

        Text {
            id: percentText
            width: 40
            anchors.verticalCenter: parent.verticalCenter
            text: String(status.progressPercent) + "%"
            color: status.textColor
            font.family: status.uiFontFamily
            font.pixelSize: status.uiFontPixelSize
            horizontalAlignment: Text.AlignRight
        }
    }
}
