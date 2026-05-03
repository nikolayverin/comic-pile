import QtQuick

Item {
    id: navBlock

    property string textLanguage: ""
    property bool backVisible: true
    property bool nextVisible: true
    property bool closeVisible: false
    readonly property int anchorPointX: 122
    readonly property int anchorPointY: 15

    signal backRequested()
    signal nextRequested()
    signal closeRequested()

    width: 270
    height: 33

    UiTokens {
        id: uiTokens
    }

    Item {
        id: backField
        x: 0
        y: 0
        width: 113
        height: 33
        visible: navBlock.backVisible

        Image {
            id: backAsset
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: backMouseArea.containsMouse ? -2 : 0
            source: uiTokens.onboardingAssetSource("back", navBlock.textLanguage)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        MouseArea {
            id: backMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navBlock.backRequested()
        }
    }

    Image {
        id: slashField
        x: 113
        y: 0
        width: 18
        height: 33
        source: uiTokens.onboardingAssetSource("slash", navBlock.textLanguage)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Item {
        id: rightField
        x: 131
        y: 0
        width: 139
        height: 33
        visible: navBlock.nextVisible || navBlock.closeVisible

        Image {
            id: rightAsset
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: rightMouseArea.containsMouse ? -2 : 0
            source: uiTokens.onboardingAssetSource(navBlock.closeVisible ? "close" : "next", navBlock.textLanguage)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        MouseArea {
            id: rightMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (navBlock.closeVisible) {
                    navBlock.closeRequested()
                } else {
                    navBlock.nextRequested()
                }
            }
        }
    }
}
