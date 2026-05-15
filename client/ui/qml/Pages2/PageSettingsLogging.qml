import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QtCore

import PageEnum 1.0
import Style 1.0

import "../Controls2"
import "../Config"
import "../Components"
import "../Controls2/TextTypes"

PageType {
    id: root
    objectName: "settingsLoggingPage"

    BackButtonType {
        id: backButton
        objectName: "settingsLoggingBackButton"
        Accessible.name: qsTr("Back")

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        onFocusChanged: {
            if (this.activeFocus) {
                listView.positionViewAtBeginning()
            }
        }
    }

    ListViewType {
        id: listView
        objectName: "settingsLoggingListView"

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        header: ColumnLayout {
            width: listView.width

            BaseHeaderType {
                objectName: "settingsLoggingHeader"
                Accessible.name: qsTr("Logging")

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("Logging")
                descriptionText: qsTr("Enabling this function will save application's logs automatically. " +
                                      "By default, logging functionality is disabled. Enable log saving in case of application malfunction.")
            }

            SwitcherType {
                id: switcher
                objectName: "settingsLoggingEnableLogsSwitch"
                Accessible.name: qsTr("Enable logs")

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Enable logs")

                checked: SettingsController.isLoggingEnabled
                
                onToggled: function() {
                    if (checked !== SettingsController.isLoggingEnabled) {
                        SettingsController.isLoggingEnabled = checked
                    }
                }
            }

            DividerType {}

            LabelWithButtonType {
                objectName: "settingsLoggingClearLogsButton"
                Accessible.name: qsTr("Clear logs")

                Layout.fillWidth: true
                Layout.topMargin: -8

                text: qsTr("Clear logs")
                leftImageSource: "qrc:/images/controls/trash.svg"
                isSmallLeftImage: true

                clickedFunction: function() {
                    var headerText = qsTr("Clear logs?")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        PageController.showBusyIndicator(true)
                        SettingsController.clearLogs()
                        PageController.showBusyIndicator(false)
                        PageController.showNotificationMessage(qsTr("Logs have been cleaned up"))
                    }

                    var noButtonFunction = function() {

                    }

                    showQuestionDrawer(headerText, "", yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }
        }

        model: logTypes

        snapMode: ListView.SnapOneItem

        delegate: ColumnLayout {
            id: delegateContent
            objectName: logTypeObjectName

            width: listView.width

            enabled: isVisible

            ListItemTitleType {
                objectName: logTypeTitleObjectName
                Accessible.name: title

                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: title
            }

            ParagraphTextType {
                objectName: logTypeDescriptionObjectName
                Accessible.name: description

                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                color: AmneziaStyle.color.mutedGray

                text: description
            }

            LabelWithButtonType {
                objectName: openLogsObjectName
                Accessible.name: qsTr("Open logs folder")

                Layout.fillWidth: true
                Layout.topMargin: -8
                Layout.bottomMargin: -8

                visible: !GC.isMobile()

                text: qsTr("Open logs folder")
                leftImageSource: "qrc:/images/controls/folder-open.svg"
                isSmallLeftImage: true

                clickedFunction: openLogsHandler
            }

            DividerType {}

            LabelWithButtonType {
                objectName: exportLogsObjectName
                Accessible.name: qsTr("Export logs")

                Layout.fillWidth: true
                Layout.topMargin: -8
                Layout.bottomMargin: -8

                text: qsTr("Export logs")
                leftImageSource: "qrc:/images/controls/save.svg"
                isSmallLeftImage: true

                clickedFunction: exportLogsHandler
            }

            DividerType {}
        }
    }

    // Show service logs only if this is NOT a macOS build with
    // Network-Extension (IsMacOsNeBuild is injected from C++ at run-time)
    // or if this is NOT a mobile build
    property list<QtObject> logTypes: (IsMacOsNeBuild || GC.isMobile()) ? [
        clientLogs
    ] : [
        clientLogs,
        serviceLogs
    ]

    QtObject {
        id: clientLogs

        readonly property string title: qsTr("Client logs")
        readonly property string description: qsTr("AmneziaVPN logs")
        readonly property string logTypeObjectName: "settingsLoggingClientLogsSection"
        readonly property string logTypeTitleObjectName: "settingsLoggingClientLogsTitle"
        readonly property string logTypeDescriptionObjectName: "settingsLoggingClientLogsDescription"
        readonly property string openLogsObjectName: "settingsLoggingClientOpenLogsButton"
        readonly property string exportLogsObjectName: "settingsLoggingClientExportLogsButton"
        readonly property bool isVisible: true
        readonly property var openLogsHandler: function() {
            SettingsController.openLogsFolder()
        }
        readonly property var exportLogsHandler: function() {
            var fileName = ""
            if (GC.isMobile()) {
                fileName = "AmneziaVPN.log"
            } else {
                fileName = SystemController.getFileName(qsTr("Save"),
                                                        qsTr("Logs files (*.log)"),
                                                        StandardPaths.standardLocations(StandardPaths.DocumentsLocation) + "/AmneziaVPN",
                                                        true,
                                                        ".log")
            }
            if (fileName !== "") {
                PageController.showBusyIndicator(true)
                SettingsController.exportLogsFile(fileName)
                PageController.showBusyIndicator(false)
                PageController.showNotificationMessage(qsTr("Logs file saved"))
            }
        }
    }

    QtObject {
        id: serviceLogs

        readonly property string title: qsTr("Service logs")
        readonly property string description: qsTr("AmneziaVPN-service logs")
        readonly property string logTypeObjectName: "settingsLoggingServiceLogsSection"
        readonly property string logTypeTitleObjectName: "settingsLoggingServiceLogsTitle"
        readonly property string logTypeDescriptionObjectName: "settingsLoggingServiceLogsDescription"
        readonly property string openLogsObjectName: "settingsLoggingServiceOpenLogsButton"
        readonly property string exportLogsObjectName: "settingsLoggingServiceExportLogsButton"
        readonly property bool isVisible: !GC.isMobile() && !IsMacOsNeBuild
        readonly property var openLogsHandler: function() {
            SettingsController.openServiceLogsFolder()
        }
        readonly property var exportLogsHandler: function() {
            var fileName = ""
            fileName = SystemController.getFileName(qsTr("Save"),
                                                    qsTr("Logs files (*.log)"),
                                                    StandardPaths.standardLocations(StandardPaths.DocumentsLocation) + "/AmneziaVPN-service",
                                                    true,
                                                    ".log")
            if (fileName !== "") {
                PageController.showBusyIndicator(true)
                SettingsController.exportServiceLogsFile(fileName)
                PageController.showBusyIndicator(false)
                PageController.showNotificationMessage(qsTr("Logs file saved"))
            }
        }
    }
}
