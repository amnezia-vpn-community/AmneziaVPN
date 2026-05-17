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
    objectName: "settingsServersListPage"
    Accessible.name: qsTr("Servers")

    ColumnLayout {
        id: header
        objectName: "settingsServersListHeaderContainer"
        Accessible.name: qsTr("Servers")

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        BackButtonType {
            id: backButton
            objectName: "settingsServersListBackButton"
            Accessible.name: qsTr("Back")
            Accessible.role: Accessible.Button
        }

        BaseHeaderType {
            objectName: "settingsServersListHeader"
            Accessible.name: headerText

            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            headerText: qsTr("Servers")
        }
    }

    ListViewType {
        id: servers
        objectName: "servers"
        Accessible.name: qsTr("Servers")

        width: parent.width
        anchors.top: header.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right


        model: ServersModel

        delegate: Item {
            objectName: "settingsServersListDelegate:" + index

            implicitWidth: servers.width
            implicitHeight: delegateContent.implicitHeight

            ColumnLayout {
                id: delegateContent
                objectName: "settingsServersListDelegateContent:" + index

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right

                LabelWithButtonType {
                    id: server
                    objectName: "settingsServersListServerButton:" + index
                    Accessible.name: text
                    Accessible.description: descriptionText
                    Accessible.role: Accessible.Button

                    Layout.fillWidth: true

                    text: name

                    descriptionText: {
                        var servicesNameString = ""
                        var servicesName = ServersUiController.getAllInstalledServicesName(index)
                        for (var i = 0; i < servicesName.length; i++) {
                            servicesNameString += servicesName[i] + " · "
                        }

                        if (ServersModel.isServerFromApi(index)) {
                            return servicesNameString + serverDescription
                        } else {
                            return servicesNameString + hostName
                        }
                    }
                    rightImageSource: "qrc:/images/controls/chevron-right.svg"

                    clickedFunction: function() {
                        ServersUiController.processedIndex = index

                        if (ServersModel.getProcessedServerData("isServerFromGatewayApi")) {
                            PageController.showBusyIndicator(true)
                            let result = SubscriptionUiController.getAccountInfo(ServersUiController.getProcessedServerIndex(), false)
                            PageController.showBusyIndicator(false)
                            if (!result) {
                                return
                            }

                            PageController.goToPage(PageEnum.PageSettingsApiServerInfo)
                        } else {
                            PageController.goToPage(PageEnum.PageSettingsServerInfo)
                        }
                    }
                }

                DividerType {}
            }
        }
    }
}
