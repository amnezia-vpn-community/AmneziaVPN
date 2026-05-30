import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root
    objectName: "settingsServerInfoPage"

    readonly property int pageSettingsServerProtocols: 0
    readonly property int pageSettingsServerServices: 1
    readonly property int pageSettingsServerData: 2

    property var processedServer

    Connections {
        target: PageController

        function onGoToPageSettingsServerServices() {
            tabBar.setCurrentIndex(root.pageSettingsServerServices)
        }
    }

    Connections {
        target: ServersModel

        function onProcessedServerChanged() {
            root.processedServer = proxyServersModel.get(0)
        }
    }

    SortFilterProxyModel {
        id: proxyServersModel
        objectName: "settingsServerInfoProxyServersModel"

        sourceModel: ServersModel
        filters: [
            ValueFilter {
                roleName: "isCurrentlyProcessed"
                value: true
            }
        ]

        Component.onCompleted: {
            root.processedServer = proxyServersModel.get(0)
        }
    }

    ColumnLayout {
        objectName: "settingsServerInfoMainLayout"

        anchors.fill: parent
        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        spacing: 4

        BackButtonType {
            id: backButton
            objectName: "settingsServerInfoBackButton"
        }

        HeaderTypeWithButton {
            id: headerContent
            objectName: "settingsServerInfoHeader"

            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 10

            actionButtonImage: "qrc:/images/controls/edit-3.svg"
            actionButton.objectName: "settingsServerInfoEditButton"

            headerText: root.processedServer.name
            descriptionText: {
                if (root.processedServer.isServerFromTelegramApi) {
                    return root.processedServer.serverDescription
                } else {
                    return root.processedServer.hostName
                }
            }

            actionButtonFunction: function() {
                serverNameEditDrawer.openTriggered()
            }
        }

        RenameServerDrawer {
            id: serverNameEditDrawer
            objectName: "settingsServerInfoRenameServerDrawer"

            parent: root

            anchors.fill: parent
            expandedHeight: root.height * 0.35

            serverNameText: root.processedServer.name
        }

        TabBar {
            id: tabBar
            objectName: "settingsServerInfoTabBar"

            Layout.fillWidth: true

            currentIndex: (ServersModel.getProcessedServerData("isServerFromTelegramApi")
                           && !ServersModel.getProcessedServerData("hasInstalledContainers")) ?
                              root.pageSettingsServerData : root.pageSettingsServerProtocols

            background: Rectangle {
                color: AmneziaStyle.color.transparent
            }


            TabButtonType {
                id: protocolsTab
                objectName: "settingsServerInfoProtocolsTabButton"
                visible: protocolsPage.installedProtocolsCount
                width: protocolsPage.installedProtocolsCount ? undefined : 0
                isSelected: TabBar.tabBar.currentIndex === root.pageSettingsServerProtocols
                text: qsTr("Protocols")

                Keys.onReturnPressed: TabBar.tabBar.setCurrentIndex(root.pageSettingsServerProtocols)
                Keys.onEnterPressed: TabBar.tabBar.setCurrentIndex(root.pageSettingsServerProtocols)
            }

            TabButtonType {
                id: servicesTab
                objectName: "settingsServerInfoServicesTabButton"
                visible: servicesPage.installedServicesCount
                width: servicesPage.installedServicesCount ? undefined : 0
                isSelected: TabBar.tabBar.currentIndex === root.pageSettingsServerServices
                text: qsTr("Services")

                Keys.onReturnPressed: TabBar.tabBar.setCurrentIndex(root.pageSettingsServerServices)
                Keys.onEnterPressed: TabBar.tabBar.setCurrentIndex(root.pageSettingsServerServices)
            }

            TabButtonType {
                id: dataTab
                objectName: "settingsServerInfoManagementTabButton"
                isSelected: tabBar.currentIndex === root.pageSettingsServerData
                text: qsTr("Management")

                Keys.onReturnPressed: TabBar.tabBar.setCurrentIndex(root.pageSettingsServerData)
                Keys.onEnterPressed: TabBar.tabBar.setCurrentIndex(root.pageSettingsServerData)
            }
        }

        StackLayout {
            id: nestedStackView
            objectName: "settingsServerInfoStackLayout"

            Layout.fillWidth: true

            currentIndex: tabBar.currentIndex

            PageSettingsServerProtocols {
                id: protocolsPage
                objectName: "settingsServerInfoProtocolsPage"
                stackView: root.stackView
            }

            PageSettingsServerServices {
                id: servicesPage
                objectName: "settingsServerInfoServicesPage"
                stackView: root.stackView
            }

            PageSettingsServerData {
                id: dataPage
                objectName: "settingsServerInfoManagementPage"
                stackView: root.stackView
            }
        }
    }
}
