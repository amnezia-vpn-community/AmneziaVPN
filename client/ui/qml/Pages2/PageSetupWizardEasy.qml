import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import ProtocolProps 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"

PageType {
    id: root
    objectName: "easySetupPage"

    property bool isEasySetup: true

    SortFilterProxyModel {
        id: proxyContainersModel
        
        sourceModel: ContainersModel
        filters: [
            ValueFilter {
                roleName: "isEasySetupContainer"
                value: true
            }
        ]
        sorters: RoleSorter {
            roleName: "easySetupOrder"
            sortOrder: Qt.DescendingOrder
        }
    }

    BackButtonType {
        id: backButton
        objectName: "easySetupBackButton"
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

    ButtonGroup {
        id: buttonGroup
    }

    ListViewType {
        id: listView
        objectName: "easySetupListView"
        Accessible.name: qsTr("Installation type")

        property int dockerContainer
        property int containerDefaultPort
        property int containerDefaultTransportProto

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        spacing: 16

        header: ColumnLayout {
            width: listView.width

            spacing: 16

            BaseHeaderType {
                id: header
                objectName: "easySetupHeader"
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 16

                headerTextMaximumLineCount: 10

                headerText: qsTr("Choose Installation Type")
            }
        }

        model: proxyContainersModel
        currentIndex: 0

        delegate: ColumnLayout {
            objectName: "easySetupDelegate:" + proxyContainersModel.mapToSource(index)

            width: listView.width

            CardType {
                id: card
                objectName: "easySetupOptionButton:" + proxyContainersModel.mapToSource(index)
                Accessible.name: headerText
                Accessible.description: bodyText
                Accessible.role: Accessible.RadioButton

                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 16

                headerText: easySetupHeader
                bodyText: easySetupDescription

                ButtonGroup.group: buttonGroup

                onClicked: function() {
                    isEasySetup = true
                    checked = true
                    var defaultContainerProto =  ContainerProps.defaultProtocol(dockerContainer)

                    listView.dockerContainer = dockerContainer
                    listView.containerDefaultPort = InstallController.getPortForInstall(defaultContainerProto)
                    listView.containerDefaultTransportProto = InstallController.defaultTransportProto(defaultContainerProto)
                }

                Keys.onReturnPressed: this.clicked()
                Keys.onEnterPressed: this.clicked()
            }
        }

        footer: ColumnLayout {
            width: listView.width
            spacing: 16

            DividerType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
            }

            CardType {
                objectName: "manualSetupOptionButton"
                Accessible.name: headerText
                Accessible.description: bodyText
                Accessible.role: Accessible.RadioButton

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("Manual")
                bodyText: qsTr("Choose a VPN protocol")

                ButtonGroup.group: buttonGroup

                onClicked: function() {
                    isEasySetup = false
                    checked = true
                }

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()
            }

            BasicButtonType {
                id: continueButton
                objectName: "easySetupContinueButton"
                Accessible.name: text
                Accessible.role: Accessible.Button

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Continue")

                clickedFunc: function() {
                    if (root.isEasySetup) {
                        ServersUiController.processedContainerIndex = listView.dockerContainer
                        PageController.goToPage(PageEnum.PageSetupWizardInstalling)
                        InstallController.install(listView.dockerContainer,
                                                  listView.containerDefaultPort,
                                                  listView.containerDefaultTransportProto,
                                                  ServersUiController.processedIndex)
                    } else {
                        PageController.goToPage(PageEnum.PageSetupWizardProtocols)
                    }
                }
            }

            BasicButtonType {
                id: setupLaterButton
                objectName: "easySetupSkipButton"
                Accessible.name: text
                Accessible.role: Accessible.Button

                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 24
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.paleGray
                borderWidth: 1

                visible: {
                    if (PageController.isTriggeredByConnectButton()) {
                        PageController.setTriggeredByConnectButton(false)
                        return false
                    }

                    return  true
                }

                text: qsTr("Skip setup")

                clickedFunc: function() {
                    PageController.goToPage(PageEnum.PageSetupWizardInstalling)
                    InstallController.addEmptyServer()
                }
            }
        }

        Component.onCompleted: {
            var item = listView.itemAtIndex(listView.currentIndex)
            if (item !== null) {
                var button = item.children[0]
                button.checked = true
                button.clicked()
            }
        }
    }
}

