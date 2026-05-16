import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ProtocolEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    objectName: "protocolXraySettingsPage"
    Accessible.name: qsTr("XRay settings")

    BackButtonType {
        id: backButton

        objectName: "protocolXraySettingsBackButton"
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

        objectName: "protocolXraySettingsListView"
        Accessible.name: qsTr("XRay settings")

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        enabled: ServersUiController.isProcessedServerHasWriteAccess()
        model: XrayConfigModel

        delegate: ColumnLayout {
            width: listView.width

            objectName: "protocolXraySettingsDelegate:" + index

            property alias focusItemId: textFieldWithHeaderType.textField

            spacing: 0

            BaseHeaderType {
                objectName: "protocolXraySettingsHeader:" + index
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                headerText: qsTr("XRay settings")
            }

            TextFieldWithHeaderType {
                id: textFieldWithHeaderType

                objectName: "protocolXraySettingsSiteField:" + index
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: listView.enabled

                headerText: qsTr("Disguised as traffic from")
                textField.text: site

                textField.onEditingFinished: {
                    if (textField.text !== site) {
                        var tmpText = textField.text
                        tmpText = tmpText.toLocaleLowerCase()

                        if (tmpText.startsWith("https://")) {
                            tmpText = textField.text.substring(8)
                            site = tmpText
                        } else {
                            site = textField.text
                        }
                    }
                }

                checkEmptyText: true
            }

            TextFieldWithHeaderType {
                id: portTextField

                objectName: "protocolXraySettingsPortField:" + index
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: listView.enabled

                headerText: qsTr("Port")
                textField.text: port
                textField.maximumLength: 5
                textField.validator: IntValidator { bottom: 1; top: 65535 }

                textField.onEditingFinished: {
                    if (textField.text !== port) {
                        port = textField.text
                    }
                }

                checkEmptyText: true
            }

            BasicButtonType {
                id: saveButton

                objectName: "protocolXraySettingsSaveButton:" + index
                Accessible.name: text

                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.bottomMargin: 24
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: portTextField.errorText === ""

                text: qsTr("Save")

                onClicked: function() {
                    forceActiveFocus()

                    var headerText = qsTr("Save settings?")
                    var descriptionText = qsTr("All users with whom you shared a connection with will no longer be able to connect to it.")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        if (ConnectionController.isConnected && ServersModel.getDefaultServerData("defaultContainer") === ServersUiController.processedContainerIndex) {
                            PageController.showNotificationMessage(qsTr("Unable change settings while there is an active connection"))
                            return
                        }

                        PageController.goToPage(PageEnum.PageSetupWizardInstalling);
                        InstallController.updateContainer(ServersUiController.processedIndex, ServersUiController.processedContainerIndex, ProtocolEnum.Xray)
                    }
                    var noButtonFunction = function() {
                        if (!GC.isMobile()) {
                            saveButton.forceActiveFocus()
                        }
                    }
                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }

                Keys.onEnterPressed: saveButton.clicked()
                Keys.onReturnPressed: saveButton.clicked()
            }
        }
    }
}
