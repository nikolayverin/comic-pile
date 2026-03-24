pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

PopupDialogWindow {
    id: dialog

    property string coverPreviewSource: ""
    property string backgroundPreviewSource: ""
    property string errorText: ""
    property bool shuffleBackgroundEnabled: false
    property bool shuffleBackgroundBusy: false

    signal uploadCoverRequested()
    signal uploadBackgroundRequested()
    signal shuffleBackgroundRequested()
    signal saveRequested()
    signal resetRequested()
    signal cancelRequested()

    PopupStyle {
        id: styleTokens
    }

    UiTokens {
        id: uiTokens
    }

    popupStyle: styleTokens
    title: "Series Header"
    closePolicy: Popup.CloseOnEscape
    width: styleTokens.seriesHeaderWidth
    height: styleTokens.seriesHeaderHeight

    onCloseRequested: dialog.cancelRequested()
    component UploadPreviewCard: Item {
        id: card

        property string source: ""
        property string uploadText: ""
        property bool loading: false

        signal clicked()

        Rectangle {
            id: previewSurface
            anchors.fill: parent
            radius: 14
            color: styleTokens.fieldFillColor
            antialiasing: true

            Image {
                id: previewImageSource
                source: card.source
                asynchronous: true
                cache: true
                smooth: true
                visible: false
            }

            Canvas {
                id: previewCanvas
                anchors.fill: parent
                contextType: "2d"

                property bool hovered: cardHover.containsMouse

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)

                    function roundedRectPath(pathWidth, pathHeight, radius) {
                        ctx.beginPath()
                        ctx.moveTo(radius, 0)
                        ctx.lineTo(pathWidth - radius, 0)
                        ctx.quadraticCurveTo(pathWidth, 0, pathWidth, radius)
                        ctx.lineTo(pathWidth, pathHeight - radius)
                        ctx.quadraticCurveTo(pathWidth, pathHeight, pathWidth - radius, pathHeight)
                        ctx.lineTo(radius, pathHeight)
                        ctx.quadraticCurveTo(0, pathHeight, 0, pathHeight - radius)
                        ctx.lineTo(0, radius)
                        ctx.quadraticCurveTo(0, 0, radius, 0)
                        ctx.closePath()
                    }

                    const centerAlpha = hovered ? 0.16 : 0.11
                    const edgeAlpha = hovered ? 0.68 : 0.56
                    const fadeX = Math.min(Math.max(width * 0.14, 26), 52)
                    const fadeY = Math.min(Math.max(height * 0.14, 26), 52)
                    const radius = 14

                    roundedRectPath(width, height, radius)
                    ctx.fillStyle = styleTokens.fieldFillColor
                    ctx.fill()

                    ctx.save()
                    roundedRectPath(width, height, radius)
                    ctx.clip()

                    if (card.source.length > 0 && previewImageSource.status === Image.Ready) {
                        const imageWidth = Math.max(
                            1,
                            Number(previewImageSource.sourceSize.width || previewImageSource.implicitWidth || 0)
                        )
                        const imageHeight = Math.max(
                            1,
                            Number(previewImageSource.sourceSize.height || previewImageSource.implicitHeight || 0)
                        )
                        const targetRatio = width / height
                        const imageRatio = imageWidth / imageHeight

                        let sourceX = 0
                        let sourceY = 0
                        let sourceWidth = imageWidth
                        let sourceHeight = imageHeight

                        if (imageRatio > targetRatio) {
                            sourceWidth = imageHeight * targetRatio
                            sourceX = (imageWidth - sourceWidth) / 2
                        } else if (imageRatio < targetRatio) {
                            sourceHeight = imageWidth / targetRatio
                            sourceY = (imageHeight - sourceHeight) / 2
                        }

                        ctx.drawImage(
                            previewImageSource,
                            sourceX,
                            sourceY,
                            sourceWidth,
                            sourceHeight,
                            0,
                            0,
                            width,
                            height
                        )
                    }

                    ctx.fillStyle = "rgba(0,0,0," + centerAlpha + ")"
                    ctx.fillRect(0, 0, width, height)

                    let gradient = ctx.createLinearGradient(0, 0, fadeX, 0)
                    gradient.addColorStop(0.0, "rgba(0,0,0," + edgeAlpha + ")")
                    gradient.addColorStop(1.0, "rgba(0,0,0,0.0)")
                    ctx.fillStyle = gradient
                    ctx.fillRect(0, 0, fadeX, height)

                    gradient = ctx.createLinearGradient(width, 0, width - fadeX, 0)
                    gradient.addColorStop(0.0, "rgba(0,0,0," + edgeAlpha + ")")
                    gradient.addColorStop(1.0, "rgba(0,0,0,0.0)")
                    ctx.fillStyle = gradient
                    ctx.fillRect(width - fadeX, 0, fadeX, height)

                    gradient = ctx.createLinearGradient(0, 0, 0, fadeY)
                    gradient.addColorStop(0.0, "rgba(0,0,0," + edgeAlpha + ")")
                    gradient.addColorStop(1.0, "rgba(0,0,0,0.0)")
                    ctx.fillStyle = gradient
                    ctx.fillRect(0, 0, width, fadeY)

                    gradient = ctx.createLinearGradient(0, height, 0, height - fadeY)
                    gradient.addColorStop(0.0, "rgba(0,0,0," + edgeAlpha + ")")
                    gradient.addColorStop(1.0, "rgba(0,0,0,0.0)")
                    ctx.fillStyle = gradient
                    ctx.fillRect(0, height - fadeY, width, fadeY)
                    ctx.restore()
                }

                onHoveredChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            Connections {
                target: previewImageSource
                ignoreUnknownSignals: true
                function onStatusChanged() { previewCanvas.requestPaint() }
                function onSourceSizeChanged() { previewCanvas.requestPaint() }
                function onImplicitWidthChanged() { previewCanvas.requestPaint() }
                function onImplicitHeightChanged() { previewCanvas.requestPaint() }
            }
        }

        FocusEdgeLine {
            targetItem: previewSurface
            cornerRadius: 14
            lineColor: styleTokens.edgeLineColor
            edge: "bottom"
            forceVisible: cardHover.containsMouse && !card.loading
        }

        Rectangle {
            id: centerOverlay
            readonly property bool hoverOverlayActive: !card.loading && cardHover.containsMouse
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 84
            height: 80
            radius: 10
            color: "#000000"
            opacity: card.loading ? 0.78 : (hoverOverlayActive ? 0.7 : 0)
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Image {
                visible: centerOverlay.hoverOverlayActive
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                width: 32
                height: 32
                source: uiTokens.dropZoneWhiteIcon
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                visible: centerOverlay.hoverOverlayActive
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: card.uploadText
                color: styleTokens.textColor
                font.pixelSize: 12
                lineHeight: 13
                lineHeightMode: Text.FixedHeight
            }

            ShuffleBusySpinner {
                anchors.centerIn: parent
                running: card.loading && visible
                visible: card.loading
            }
        }

        MouseArea {
            id: cardHover
            anchors.fill: parent
            enabled: !card.loading
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: card.clicked()
        }
    }

    Item {
        id: headerLayout
        anchors.fill: parent

        readonly property int contentLeft: styleTokens.dialogSideMargin + 28
        readonly property int contentTop: styleTokens.formSectionTop
        readonly property int coverWidth: 144
        readonly property int coverHeight: 238
        readonly property int gap: 18
        readonly property int backgroundWidth: width - contentLeft - styleTokens.dialogSideMargin - coverWidth - gap - 22
        readonly property int backgroundHeight: coverHeight
        readonly property int sectionTitleToPreviewLabelsGap: 10
        readonly property int previewLabelToCardGap: 12
        readonly property string coverTargetSizeLabel: "510x780 px"
        readonly property string backgroundTargetSizeLabel: "660x220 px"

        Column {
            x: headerLayout.contentLeft
            y: headerLayout.contentTop
            spacing: headerLayout.sectionTitleToPreviewLabelsGap

            Label {
                text: "Theme"
                color: styleTokens.textColor
                font.pixelSize: styleTokens.dialogHintFontSize
            }

            Row {
                spacing: headerLayout.gap

                Column {
                    width: headerLayout.coverWidth
                    spacing: headerLayout.previewLabelToCardGap

                    Item {
                        id: coverHeaderItem
                        width: parent.width
                        height: styleTokens.footerButtonHeight

                        Label {
                            id: coverTitleLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Main cover"
                            color: styleTokens.textColor
                            font.pixelSize: styleTokens.dialogHintFontSize
                        }

                        Label {
                            id: coverSizeLabel
                            anchors.left: coverTitleLabel.right
                            anchors.leftMargin: Math.max(
                                12,
                                coverHeaderItem.width - coverTitleLabel.implicitWidth - coverSizeLabel.implicitWidth
                            )
                            anchors.verticalCenter: parent.verticalCenter
                            text: headerLayout.coverTargetSizeLabel
                            color: styleTokens.hintTextColor
                            font.pixelSize: styleTokens.dialogHintFontSize
                        }
                    }

                    UploadPreviewCard {
                        width: parent.width
                        height: headerLayout.coverHeight
                        source: dialog.coverPreviewSource
                        uploadText: "Upload\ncover"
                        onClicked: dialog.uploadCoverRequested()
                    }
                }

                Column {
                    width: headerLayout.backgroundWidth
                    spacing: headerLayout.previewLabelToCardGap

                    Item {
                        id: backgroundHeaderItem
                        width: parent.width
                        height: coverHeaderItem.height

                        Label {
                            id: backgroundTitleLabel
                            anchors.left: backgroundHeaderItem.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Background"
                            color: styleTokens.textColor
                            font.pixelSize: styleTokens.dialogHintFontSize
                        }

                        PopupActionButton {
                            id: shuffleButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: styleTokens.footerButtonHeight
                            minimumWidth: 0
                            horizontalPadding: 12
                            cornerRadius: styleTokens.footerButtonRadius
                            idleColor: styleTokens.footerButtonIdleColor
                            hoverColor: styleTokens.footerButtonHoverColor
                            textColor: styleTokens.textColor
                            textPixelSize: styleTokens.dialogHintFontSize
                            text: "Shuffle"
                            enabled: dialog.shuffleBackgroundEnabled && !dialog.shuffleBackgroundBusy
                            onClicked: dialog.shuffleBackgroundRequested()
                        }

                        Label {
                            id: backgroundSizeLabel
                            anchors.left: backgroundTitleLabel.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: headerLayout.backgroundTargetSizeLabel
                            color: styleTokens.hintTextColor
                            font.pixelSize: styleTokens.dialogHintFontSize
                        }

                        Row {
                            visible: dialog.errorText.length > 0
                            anchors.left: backgroundSizeLabel.right
                            anchors.leftMargin: 38
                            anchors.right: shuffleButton.left
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Image {
                                width: 16
                                height: 16
                                source: "qrc:/qt/qml/ComicPile/assets/icons/icon-alert-triangle.svg"
                                sourceSize.width: 16
                                sourceSize.height: 16
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                width: Math.max(0, parent.width - 16 - 14)
                                text: dialog.errorText
                                color: styleTokens.textColor
                                font.family: Qt.application.font.family
                                font.pixelSize: 12
                                font.weight: Font.Normal
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    UploadPreviewCard {
                        width: parent.width
                        height: headerLayout.backgroundHeight
                        loading: dialog.shuffleBackgroundBusy
                        source: dialog.backgroundPreviewSource
                        uploadText: "Upload\nbackground"
                        onClicked: dialog.uploadBackgroundRequested()
                    }
                }
            }
        }

        PopupFooterRow {
            id: footerRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: styleTokens.footerBottomMargin
            horizontalPadding: styleTokens.footerSideMargin

            PopupActionButton {
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: "Save"
                onClicked: dialog.saveRequested()
            }

            PopupActionButton {
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: "Reset to default"
                onClicked: dialog.resetRequested()
            }

            PopupActionButton {
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: "Cancel"
                onClicked: dialog.cancelRequested()
            }
        }
    }
}
