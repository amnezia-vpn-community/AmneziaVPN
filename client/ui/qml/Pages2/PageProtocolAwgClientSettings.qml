import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ProtocolEnum 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"


PageType {
    id: root
    objectName: "protocolAwgClientSettingsPage"
    Accessible.name: qsTr("AmneziaWG settings")

    BackButtonType {
        id: backButton
        objectName: "protocolAwgClientSettingsBackButton"
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

    SmartScroll {
        id: smartScroll
        listView: listView
    }

    ListViewType {
        id: listView
        objectName: "protocolAwgClientSettingsListView"
        Accessible.name: qsTr("AmneziaWG settings")

        anchors.top: backButton.bottom
        anchors.bottom: saveButton.top
        anchors.right: parent.right
        anchors.left: parent.left

        header: ColumnLayout {
            width: listView.width
            
            BaseHeaderType {
                objectName: "protocolAwgClientSettingsHeader"
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("AmneziaWG settings")
            }
        }

        model: AwgConfigModel

        delegate: ColumnLayout {
            objectName: "protocolAwgClientSettingsDelegate:" + index

            width: listView.width

            property bool isSaveButtonEnabled: mtuTextField.errorText === "" &&
                                               junkPacketMaxSizeTextField.errorText === "" &&
                                               junkPacketMinSizeTextField.errorText === "" &&
                                               junkPacketCountTextField.errorText === ""

            spacing: 0

            TextFieldWithHeaderType {
                id: mtuTextField
                objectName: "protocolAwgClientSettingsMtuField:" + index
                Accessible.name: qsTr("MTU")

                Layout.fillWidth: true
                Layout.topMargin: 40
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("MTU")
                textField.text: clientMtu
                textField.validator: IntValidator { bottom: 576; top: 65535 }

                textField.onEditingFinished: {
                    if (textField.text !== clientMtu) {
                        clientMtu = textField.text
                    }
                }

                textField.onActiveFocusChanged: {
                    if (textField.activeFocus) {
                        smartScroll.scrollToItem(mtuTextField)
                    }
                }

                checkEmptyText: true
            }

            AwgTextField {
                id: junkPacketCountTextField
                objectName: "protocolAwgClientSettingsJunkPacketCountField:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: "Jc - Junk packet count"
                textField.text: clientJunkPacketCount

                textField.onEditingFinished: {
                    if (textField.text !== clientJunkPacketCount) {
                        clientJunkPacketCount = textField.text
                    }
                }

                textField.onActiveFocusChanged: {
                    if (textField.activeFocus) {
                        smartScroll.scrollToItem(junkPacketCountTextField)
                    }
                }
            }

            AwgTextField {
                id: junkPacketMinSizeTextField
                objectName: "protocolAwgClientSettingsJunkPacketMinSizeField:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: "Jmin - Junk packet minimum size"
                textField.text: clientJunkPacketMinSize

                textField.onEditingFinished: {
                    if (textField.text !== clientJunkPacketMinSize) {
                        clientJunkPacketMinSize = textField.text
                    }
                }

                textField.onActiveFocusChanged: {
                    if (textField.activeFocus) {
                        smartScroll.scrollToItem(junkPacketMinSizeTextField)
                    }
                }
            }

            AwgTextField {
                id: junkPacketMaxSizeTextField
                objectName: "protocolAwgClientSettingsJunkPacketMaxSizeField:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: "Jmax - Junk packet maximum size"
                textField.text: clientJunkPacketMaxSize

                textField.onEditingFinished: {
                    if (textField.text !== clientJunkPacketMaxSize) {
                        clientJunkPacketMaxSize = textField.text
                    }
                }

                textField.onActiveFocusChanged: {
                    if (textField.activeFocus) {
                        smartScroll.scrollToItem(junkPacketMaxSizeTextField)
                    }
                }
            }

            AwgTextField {
                id: specialJunk1TextField
                objectName: "protocolAwgClientSettingsSpecialJunk1Field:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("I1 - First special junk packet")
                textField.text: clientSpecialJunk1
                textField.validator: null
                checkEmptyText: false

                textField.onEditingFinished: {
                    if (textField.text !== clientSpecialJunk1) {
                        clientSpecialJunk1 = textField.text
                    }
                }

                textField.onActiveFocusChanged: {
                    if (textField.activeFocus) {
                        smartScroll.scrollToItem(specialJunk1TextField)
                    }
                }
            }

            AwgTextField {
                id: specialJunk2TextField
                objectName: "protocolAwgClientSettingsSpecialJunk2Field:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("I2 - Second special junk packet")
                textField.text: clientSpecialJunk2
                textField.validator: null
                checkEmptyText: false

                textField.onEditingFinished: {
                    if (textField.text !== clientSpecialJunk2) {
                        clientSpecialJunk2 = textField.text
                    }
                }

                textField.onActiveFocusChanged: {
                    if (textField.activeFocus) {
                        smartScroll.scrollToItem(specialJunk2TextField)
                    }
                }
            }

            AwgTextField {
                id: specialJunk3TextField
                objectName: "protocolAwgClientSettingsSpecialJunk3Field:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("I3 - Third special junk packet")
                textField.text: clientSpecialJunk3
                textField.validator: null
                checkEmptyText: false

                textField.onEditingFinished: {
                    if (textField.text !== clientSpecialJunk3) {
                        clientSpecialJunk3 = textField.text
                    }
                }

                textField.onActiveFocusChanged: {
                    if (textField.activeFocus) {
                        smartScroll.scrollToItem(specialJunk3TextField)
                    }
                }
            }

            AwgTextField {
                id: specialJunk4TextField
                objectName: "protocolAwgClientSettingsSpecialJunk4Field:" + index
                Accessible.name: headerText
                
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("I4 - Fourth special junk packet")
                textField.text: clientSpecialJunk4
                textField.validator: null
                checkEmptyText: false

                textField.onEditingFinished: {
                    if (textField.text !== clientSpecialJunk4) {
                        clientSpecialJunk4 = textField.text
                    }
                }

                textField.onActiveFocusChanged: {
                    if (textField.activeFocus) {
                        smartScroll.scrollToItem(specialJunk4TextField)
                    }
                }
            }

            AwgTextField {
                id: specialJunk5TextField
                objectName: "protocolAwgClientSettingsSpecialJunk5Field:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("I5 - Fifth special junk packet")
                textField.text: clientSpecialJunk5
                textField.validator: null
                checkEmptyText: false

                textField.onEditingFinished: {
                    if (textField.text !== clientSpecialJunk5 ) {
                        clientSpecialJunk5 = textField.text
                    }
                }

                textField.onActiveFocusChanged: {
                    if (textField.activeFocus) {
                        smartScroll.scrollToItem(specialJunk5TextField)
                    }
                }
            }


            Header2TextType {
                objectName: "protocolAwgClientSettingsServerSettingsHeader:" + index
                Accessible.name: text

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Server settings")
            }

            AwgTextField {
                id: portTextField
                objectName: "protocolAwgClientSettingsPortField:" + index
                Accessible.name: qsTr("Port")

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: false

                headerText: qsTr("Port")
                textField.text: port
            }

            AwgTextField {
                id: initPacketJunkSizeTextField
                objectName: "protocolAwgClientSettingsInitPacketJunkSizeField:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: false

                headerText: "S1 - Init packet junk size"
                textField.text: serverInitPacketJunkSize
            }

            AwgTextField {
                id: responsePacketJunkSizeTextField
                objectName: "protocolAwgClientSettingsResponsePacketJunkSizeField:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: false

                headerText: "S2 - Response packet junk size"
                textField.text: serverResponsePacketJunkSize
            }

            AwgTextField {
                id: cookieReplyPacketJunkSizeTextField
                objectName: "protocolAwgClientSettingsCookieReplyPacketJunkSizeField:" + index
                Accessible.name: headerText

                visible: isAwg2

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: false

                headerText: "S3 - Cookie Reply packet junk size"
                textField.text: serverCookieReplyPacketJunkSize
            }

            AwgTextField {
                id: transportPacketJunkSizeTextField
                objectName: "protocolAwgClientSettingsTransportPacketJunkSizeField:" + index
                Accessible.name: headerText

                visible: isAwg2

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: false

                headerText: "S4 - Transport packet junk size"
                textField.text: serverTransportPacketJunkSize
            }

            AwgTextField {
                id: initPacketMagicHeaderTextField
                objectName: "protocolAwgClientSettingsInitPacketMagicHeaderField:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: false

                headerText: "H1 - Init packet magic header"
                textField.text: serverInitPacketMagicHeader
            }

            AwgTextField {
                id: responsePacketMagicHeaderTextField
                objectName: "protocolAwgClientSettingsResponsePacketMagicHeaderField:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: false

                headerText: "H2 - Response packet magic header"
                textField.text: serverResponsePacketMagicHeader
            }

            AwgTextField {
                id: underloadPacketMagicHeaderTextField
                objectName: "protocolAwgClientSettingsUnderloadPacketMagicHeaderField:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: false

                headerText: "H3 - Underload packet magic header"
                textField.text: serverUnderloadPacketMagicHeader
            }

            AwgTextField {
                id: transportPacketMagicHeaderTextField
                objectName: "protocolAwgClientSettingsTransportPacketMagicHeaderField:" + index
                Accessible.name: headerText

                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: false

                headerText: "H4 - Transport packet magic header"
                textField.text: serverTransportPacketMagicHeader
            }
        }
    }

    BasicButtonType {
        id: saveButton
        objectName: "protocolAwgClientSettingsSaveButton"
        Accessible.name: qsTr("Save")
        Accessible.role: Accessible.Button

        anchors.right: root.right
        anchors.left: root.left
        anchors.bottom: root.bottom

        anchors.topMargin: 24
        anchors.bottomMargin: 24
        anchors.rightMargin: 16
        anchors.leftMargin: 16

        enabled: listView.currentItem.isSaveButtonEnabled

        text: qsTr("Save")

        onActiveFocusChanged: {
            if(activeFocus) {
                listView.positionViewAtEnd()
            }
        }

        clickedFunc: function() {
            var headerText = qsTr("Save settings?")
            var descriptionText = qsTr("Only the settings for this device will be changed")
            var yesButtonText = qsTr("Continue")
            var noButtonText = qsTr("Cancel")

            var yesButtonFunction = function() {
                if (ConnectionController.isConnected && ServersModel.getDefaultServerData("defaultContainer") === ServersUiController.processedContainerIndex) {
                    PageController.showNotificationMessage(qsTr("Unable change settings while there is an active connection"))
                    return
                }

                PageController.goToPage(PageEnum.PageSetupWizardInstalling);
                InstallController.updateContainer(ServersUiController.processedIndex, ServersUiController.processedContainerIndex, ProtocolEnum.Awg)
            }

            var noButtonFunction = function() {}

            showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
        }
    }
}
