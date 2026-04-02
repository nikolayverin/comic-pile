import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    debugName: "about-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    title: ""
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: 434
    height: 620

    onCloseRequested: close()

    Item {
        anchors.fill: parent

        Text {
            id: aboutTitle
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            text: "About"
            color: "#ffffff"
            font.family: Qt.application.font.family
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        Image {
            id: appIcon
            anchors.horizontalCenter: parent.horizontalCenter
            y: 38
            width: 256
            height: 256
            source: "qrc:/qt/qml/ComicPile/assets/ui/about-app-icon-256.png"
            sourceSize.width: 256
            sourceSize.height: 256
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            id: appName
            anchors.horizontalCenter: parent.horizontalCenter
            y: appIcon.y + appIcon.height + 12
            text: "Comic Pile"
            color: "#ffffff"
            font.family: Qt.application.font.family
            font.pixelSize: 34
            font.weight: Font.Bold
        }

        Text {
            id: appSubtitle
            anchors.horizontalCenter: parent.horizontalCenter
            y: appName.y + appName.implicitHeight
            text: "comic reader and library manager"
            color: "#8ba4c0"
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }

        GridLayout {
            id: infoGrid
            x: 126
            y: appSubtitle.y + appSubtitle.implicitHeight + 24
            columns: 2
            columnSpacing: 18
            rowSpacing: 6

            Text {
                text: "Created by"
                color: "#a9a9a9"
                font.family: Qt.application.font.family
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }

            Text {
                text: "Nikolay Verin"
                color: "#ffffff"
                font.family: Qt.application.font.family
                font.pixelSize: 12
            }

            Text {
                text: "Made with"
                color: "#a9a9a9"
                font.family: Qt.application.font.family
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }

            Text {
                text: "CODEX by OpenAI"
                color: "#ffffff"
                font.family: Qt.application.font.family
                font.pixelSize: 12
            }

            Text {
                text: "Built with"
                color: "#a9a9a9"
                font.family: Qt.application.font.family
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }

            Text {
                text: "Qt 6, QML, C++, SQLite"
                color: "#ffffff"
                font.family: Qt.application.font.family
                font.pixelSize: 12
            }

            Text {
                text: "Licenses"
                color: "#a9a9a9"
                font.family: Qt.application.font.family
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignTop
                Layout.alignment: Qt.AlignRight | Qt.AlignTop
            }

            Column {
                spacing: 6

                Text {
                    text: "Project License"
                    color: "#ffffff"
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                }

                Text {
                    text: "Qt Licenses"
                    color: "#ffffff"
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                }

                Text {
                    text: "Third-Party Licenses"
                    color: "#ffffff"
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                }
            }

            Text {
                text: "Source Code"
                color: "#a9a9a9"
                font.family: Qt.application.font.family
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }

            Text {
                text: "GitHub Repository"
                color: "#ffffff"
                font.family: Qt.application.font.family
                font.pixelSize: 12
            }

            Text {
                text: "Build"
                color: "#a9a9a9"
                font.family: Qt.application.font.family
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }

            Text {
                text: String(appVersion || "")
                color: "#ffffff"
                font.family: Qt.application.font.family
                font.pixelSize: 12
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: infoGrid.y + infoGrid.implicitHeight + 24
            text: "\u00a9 2026 Open-source project"
            color: "#a9a9a9"
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }
    }
}
