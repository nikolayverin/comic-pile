import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    readonly property string aboutLinkColor: "#78b7ff"
    readonly property string repositoryUrl: "https://github.com/nikolayverin/comic-pile"
    readonly property string projectLicenseUrl: repositoryUrl + "/blob/main/LICENSE"
    readonly property string qtLicensesUrl: repositoryUrl + "/blob/main/release/License/03-QT-NOTICE.txt"
    readonly property string thirdPartyLicensesUrl: repositoryUrl + "/blob/main/release/License/01-README.txt"
    readonly property bool fastDevBuild: Boolean(appIsFastDevBuild)
    readonly property var updatesRef: (typeof releaseCheckService !== "undefined") ? releaseCheckService : null
    readonly property string buildVersionText: {
        const versionText = String(appVersion || "").trim()
        const buildText = String(appBuildIteration || "").trim()
        if (!fastDevBuild || buildText.length < 1) {
            return versionText
        }
        if (versionText.length < 1) {
            return "DEV " + buildText
        }
        return versionText + " (DEV " + buildText + ")"
    }
    readonly property string updateStatusText: {
        if (!updatesRef) {
            return ""
        }
        if (Boolean(updatesRef.checking)) {
            return "Checking GitHub Releases..."
        }
        const errorText = String(updatesRef.lastError || "").trim()
        if (errorText.length > 0) {
            return errorText
        }
        const latestVersion = String(updatesRef.latestVersion || "").trim()
        if (latestVersion.length < 1) {
            return "No update check has been run yet."
        }
        if (Boolean(updatesRef.latestVersionIsNewer)) {
            return "Update available: " + latestVersion
        }
        return "You are up to date."
    }
    readonly property bool hasUpdateAvailable: Boolean(updatesRef) && Boolean(updatesRef.hasReleaseInfo) && Boolean(updatesRef.latestVersionIsNewer)
    readonly property string releaseNotesUrl: {
        const url = String(updatesRef && updatesRef.latestReleaseUrl || "").trim()
        return url
    }
    readonly property string updateDownloadUrl: {
        const url = String(updatesRef && updatesRef.latestAssetDownloadUrl || "").trim()
        return url
    }

    PopupStyle {
        id: styleTokens
    }

    ThemeColors {
        id: themeColors
    }

    popupStyle: styleTokens
    debugName: "about-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    title: ""
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: 434
    height: 664

    onCloseRequested: close()

    function openExternalLink(url) {
        if (!url || url.length === 0) {
            return
        }
        Qt.openUrlExternally(url)
    }

    function aboutLinkText(url, label, hovered) {
        const decoration = hovered ? "underline" : "none"
        return "<a href=\"" + url + "\" style=\"color:" + aboutLinkColor + "; text-decoration:" + decoration + ";\">" + label + "</a>"
    }

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
                    id: projectLicenseLink
                    property bool hovered: false
                    text: dialog.aboutLinkText(dialog.projectLicenseUrl, "Project License", hovered)
                    color: "#ffffff"
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                    textFormat: Text.RichText
                    onLinkActivated: function(link) { dialog.openExternalLink(link) }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: projectLicenseLink.linkAt(mouseX, mouseY) !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: projectLicenseLink.hovered = true
                        onExited: projectLicenseLink.hovered = false
                        onClicked: function(mouse) {
                            const link = projectLicenseLink.linkAt(mouse.x, mouse.y)
                            if (link !== "")
                                dialog.openExternalLink(link)
                        }
                    }
                }

                Text {
                    id: qtLicensesLink
                    property bool hovered: false
                    text: dialog.aboutLinkText(dialog.qtLicensesUrl, "Qt Licenses", hovered)
                    color: "#ffffff"
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                    textFormat: Text.RichText
                    onLinkActivated: function(link) { dialog.openExternalLink(link) }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: qtLicensesLink.linkAt(mouseX, mouseY) !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: qtLicensesLink.hovered = true
                        onExited: qtLicensesLink.hovered = false
                        onClicked: function(mouse) {
                            const link = qtLicensesLink.linkAt(mouse.x, mouse.y)
                            if (link !== "")
                                dialog.openExternalLink(link)
                        }
                    }
                }

                Text {
                    id: thirdPartyLicensesLink
                    property bool hovered: false
                    text: dialog.aboutLinkText(dialog.thirdPartyLicensesUrl, "Third-Party Licenses", hovered)
                    color: "#ffffff"
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                    textFormat: Text.RichText
                    onLinkActivated: function(link) { dialog.openExternalLink(link) }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: thirdPartyLicensesLink.linkAt(mouseX, mouseY) !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: thirdPartyLicensesLink.hovered = true
                        onExited: thirdPartyLicensesLink.hovered = false
                        onClicked: function(mouse) {
                            const link = thirdPartyLicensesLink.linkAt(mouse.x, mouse.y)
                            if (link !== "")
                                dialog.openExternalLink(link)
                        }
                    }
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
                id: repositoryLink
                property bool hovered: false
                text: dialog.aboutLinkText(dialog.repositoryUrl, "GitHub Repository", hovered)
                color: "#ffffff"
                font.family: Qt.application.font.family
                font.pixelSize: 12
                textFormat: Text.RichText
                onLinkActivated: function(link) { dialog.openExternalLink(link) }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: repositoryLink.linkAt(mouseX, mouseY) !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: repositoryLink.hovered = true
                    onExited: repositoryLink.hovered = false
                    onClicked: function(mouse) {
                        const link = repositoryLink.linkAt(mouse.x, mouse.y)
                        if (link !== "")
                            dialog.openExternalLink(link)
                    }
                }
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
                text: dialog.buildVersionText
                color: "#ffffff"
                font.family: Qt.application.font.family
                font.pixelSize: 12
            }

            Text {
                text: "Updates"
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

                PopupActionButton {
                    id: checkForUpdatesButton
                    text: dialog.updatesRef && Boolean(dialog.updatesRef.checking)
                        ? "Checking..."
                        : dialog.hasUpdateAvailable && dialog.updateDownloadUrl.length > 0
                            ? "Download update"
                            : "Check for updates"
                    enabled: !!dialog.updatesRef
                    height: styleTokens.footerButtonHeight
                    minimumWidth: 168
                    horizontalPadding: styleTokens.footerButtonHorizontalPadding
                    cornerRadius: styleTokens.footerButtonRadius
                    idleColor: dialog.hasUpdateAvailable && dialog.updateDownloadUrl.length > 0
                        ? "#84db3f"
                        : styleTokens.footerButtonIdleColor
                    hoverColor: dialog.hasUpdateAvailable && dialog.updateDownloadUrl.length > 0
                        ? "#459b00"
                        : styleTokens.footerButtonHoverColor
                    idleEdgeColor: dialog.hasUpdateAvailable && dialog.updateDownloadUrl.length > 0
                        ? "#1e4400"
                        : themeColors.lineTopbarBottom
                    hoverEdgeColor: dialog.hasUpdateAvailable && dialog.updateDownloadUrl.length > 0
                        ? "#e2ff40"
                        : themeColors.popupPrimaryActionHoverEdgeColor
                    textColor: styleTokens.textColor
                    textPixelSize: styleTokens.footerButtonTextSize
                    onClicked: {
                        if (dialog.hasUpdateAvailable && dialog.updateDownloadUrl.length > 0) {
                            dialog.openExternalLink(dialog.updateDownloadUrl)
                        } else if (dialog.updatesRef) {
                            dialog.updatesRef.checkLatestRelease()
                        }
                    }
                }

                Text {
                    width: 190
                    text: dialog.updateStatusText
                    color: String(dialog.updatesRef && dialog.updatesRef.lastError || "").trim().length > 0
                        ? "#e2a4a4"
                        : "#8ba4c0"
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Text {
                    id: downloadUpdateLink
                    visible: dialog.hasUpdateAvailable && dialog.updateDownloadUrl.length > 0
                    property bool hovered: false
                    text: dialog.aboutLinkText(dialog.updateDownloadUrl, "Download update", hovered)
                    color: "#ffffff"
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                    textFormat: Text.RichText
                    onLinkActivated: function(link) { dialog.openExternalLink(link) }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: downloadUpdateLink.linkAt(mouseX, mouseY) !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: downloadUpdateLink.hovered = true
                        onExited: downloadUpdateLink.hovered = false
                        onClicked: function(mouse) {
                            const link = downloadUpdateLink.linkAt(mouse.x, mouse.y)
                            if (link !== "") {
                                dialog.openExternalLink(link)
                            }
                        }
                    }
                }

                Text {
                    id: releaseNotesLink
                    visible: dialog.hasUpdateAvailable && dialog.releaseNotesUrl.length > 0
                    property bool hovered: false
                    text: dialog.aboutLinkText(dialog.releaseNotesUrl, "Release notes", hovered)
                    color: "#ffffff"
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                    textFormat: Text.RichText
                    onLinkActivated: function(link) { dialog.openExternalLink(link) }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: releaseNotesLink.linkAt(mouseX, mouseY) !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: releaseNotesLink.hovered = true
                        onExited: releaseNotesLink.hovered = false
                        onClicked: function(mouse) {
                            const link = releaseNotesLink.linkAt(mouse.x, mouse.y)
                            if (link !== "") {
                                dialog.openExternalLink(link)
                            }
                        }
                    }
                }
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
