import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"

PageType {
    id: root
    objectName: "setupWizardProtocolsPage"
    Accessible.name: qsTr("VPN protocol")


    SortFilterProxyModel {
        id: proxyContainersModel
        sourceModel: ContainersModel
        filters: [
            ValueFilter {
                roleName: "isVpnContainer"
                value: true
            },
            ValueFilter {
                roleName: "isSupported"
                value: true
            },
            ValueFilter {
                roleName: "isInstallationAllowed"
                value: true
            }
        ]
        sorters: RoleSorter {
            roleName: "installPageOrder"
            sortOrder: Qt.AscendingOrder
        }
    }

    BackButtonType {
        id: backButton
        objectName: "setupWizardProtocolsBackButton"
        Accessible.name: qsTr("Back")
        Accessible.role: Accessible.Button


        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        onActiveFocusChanged: {
            if(backButton.enabled && backButton.activeFocus) {
                listView.positionViewAtBeginning()
            }
        }
    }

    ListViewType {
        id: listView
        objectName: "setupWizardProtocolsListView"
        Accessible.name: qsTr("VPN protocol")

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        header: ColumnLayout {
            width: listView.width

            BaseHeaderType {
                id: header
                objectName: "setupWizardProtocolsHeader"
                Accessible.name: headerText


                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 16

                headerText: qsTr("VPN protocol")
                descriptionText: qsTr("Choose the one with the highest priority for you. Later, you can install other protocols and additional services, such as DNS proxy and SFTP.")
            }
        }

        model: proxyContainersModel

        spacing: 0
        snapMode: ListView.SnapToItem

        delegate: ColumnLayout {
            objectName: "setupWizardProtocolsDelegate:" + proxyContainersModel.mapToSource(index)

            width: listView.width

            LabelWithButtonType {
                objectName: "setupWizardProtocolButton:" + proxyContainersModel.mapToSource(index)
                Accessible.name: text
                Accessible.description: descriptionText
                Accessible.role: Accessible.Button

                Layout.fillWidth: true

                text: name
                descriptionText: description
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function () {
                    ServersUiController.processedContainerIndex = proxyContainersModel.mapToSource(index)
                    PageController.goToPage(PageEnum.PageSetupWizardProtocolSettings);
                }
            }

            DividerType {}
        }
    }
}
