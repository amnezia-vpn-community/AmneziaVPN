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
    objectName: "protocolOpenVpnSettingsPage"
    Accessible.name: qsTr("OpenVPN settings")

    BackButtonType {
        id: backButton
        objectName: "protocolOpenVpnSettingsBackButton"
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
        objectName: "protocolOpenVpnSettingsListView"
        Accessible.name: qsTr("OpenVPN settings")

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        enabled: ServersUiController.isProcessedServerHasWriteAccess()

        header: ColumnLayout {
            width: listView.width

            BaseHeaderType {
                id: header
                objectName: "protocolOpenVpnSettingsHeader"
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                headerText: qsTr("OpenVPN Settings")
            }
        }

        model: OpenVpnConfigModel             

        delegate: ColumnLayout {
            id: delegateItem
            objectName: "protocolOpenVpnSettingsDelegate:" + index

            width: listView.width

            spacing: 0

            TextFieldWithHeaderType {
                id: vpnAddressSubnetTextField
                objectName: "protocolOpenVpnSettingsVpnAddressSubnetField:" + index
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: listView.enabled

                headerText: qsTr("VPN address subnet")
                textField.text: subnetAddress

                textField.onEditingFinished: {
                    if (textField.text !== subnetAddress) {
                        subnetAddress = textField.text
                    }
                }

                checkEmptyText: true
            }

            ParagraphTextType {
                objectName: "protocolOpenVpnSettingsNetworkProtocolLabel:" + index
                Accessible.name: text

                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Network protocol")
            }

            TransportProtoSelector {
                id: transportProtoSelector
                objectName: "protocolOpenVpnSettingsTransportProtocolSelector:" + index
                Accessible.name: qsTr("Network protocol")

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                rootWidth: root.width

                enabled: isTransportProtoEditable

                currentIndex: {
                    return transportProto === "tcp" ? 1 : 0
                }

                onCurrentIndexChanged: {
                    if (transportProto === "tcp" && currentIndex === 0) {
                        transportProto = "udp"
                    } else if (transportProto === "udp" && currentIndex === 1) {
                        transportProto = "tcp"
                    }
                }
            }

            TextFieldWithHeaderType {
                id: portTextField
                objectName: "protocolOpenVpnSettingsPortField:" + index
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.topMargin: 40
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

            SwitcherType {
                id: autoNegotiateEncryprionSwitcher
                objectName: "protocolOpenVpnSettingsAutoNegotiateEncryptionSwitch:" + index
                Accessible.name: text

                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Auto-negotiate encryption")
                checked: autoNegotiateEncryprion

                onToggled: function() {
                    if (checked !== autoNegotiateEncryprion) {
                        autoNegotiateEncryprion = checked
                    }
                }
            }

            DropDownType {
                id: hashDropDown
                objectName: "protocolOpenVpnSettingsHashSelector:" + index
                Accessible.name: descriptionText

                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: !autoNegotiateEncryprionSwitcher.checked

                descriptionText: qsTr("Hash")
                headerText: qsTr("Hash")

                drawerParent: root

                listView: ListViewWithRadioButtonType {
                    id: hashListView
                    objectName: "protocolOpenVpnSettingsHashListView:" + index
                    Accessible.name: qsTr("Hash")

                    rootWidth: root.width

                    model: ListModel {
                        ListElement { name : qsTr("SHA512") }
                        ListElement { name : qsTr("SHA384") }
                        ListElement { name : qsTr("SHA256") }
                        ListElement { name : qsTr("SHA3-512") }
                        ListElement { name : qsTr("SHA3-384") }
                        ListElement { name : qsTr("SHA3-256") }
                        ListElement { name : qsTr("whirlpool") }
                        ListElement { name : qsTr("BLAKE2b512") }
                        ListElement { name : qsTr("BLAKE2s256") }
                        ListElement { name : qsTr("SHA1") }
                    }

                    function updateSelectedIndex() {
                        hashDropDown.text = hash
                        for (var i = 0; i < hashListView.model.count; i++) {
                            if (hashListView.model.get(i).name === hash) {
                                selectedIndex = i
                                break
                            }
                        }
                    }

                    clickedFunction: function() {
                        hashDropDown.text = selectedText
                        hash = hashDropDown.text
                        hashDropDown.closeTriggered()
                    }

                    Component.onCompleted: {
                        updateSelectedIndex()
                    }
                }

                Connections {
                    target: listView.model
                    function onDataChanged() {
                        hashListView.updateSelectedIndex()
                    }
                }
            }

            DropDownType {
                id: cipherDropDown
                objectName: "protocolOpenVpnSettingsCipherSelector:" + index
                Accessible.name: descriptionText

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: !autoNegotiateEncryprionSwitcher.checked

                descriptionText: qsTr("Cipher")
                headerText: qsTr("Cipher")

                drawerParent: root

                listView: ListViewWithRadioButtonType {
                    id: cipherListView
                    objectName: "protocolOpenVpnSettingsCipherListView:" + index
                    Accessible.name: qsTr("Cipher")

                    rootWidth: root.width

                    model: ListModel {
                        ListElement { name : qsTr("AES-256-GCM") }
                        ListElement { name : qsTr("AES-192-GCM") }
                        ListElement { name : qsTr("AES-128-GCM") }
                        ListElement { name : qsTr("AES-256-CBC") }
                        ListElement { name : qsTr("AES-192-CBC") }
                        ListElement { name : qsTr("AES-128-CBC") }
                        ListElement { name : qsTr("ChaCha20-Poly1305") }
                        ListElement { name : qsTr("ARIA-256-CBC") }
                        ListElement { name : qsTr("CAMELLIA-256-CBC") }
                        ListElement { name : qsTr("none") }
                    }

                    function updateSelectedIndex() {
                        cipherDropDown.text = cipher
                        for (var i = 0; i < cipherListView.model.count; i++) {
                            if (cipherListView.model.get(i).name === cipher) {
                                selectedIndex = i
                                break
                            }
                        }
                    }

                    clickedFunction: function() {
                        cipherDropDown.text = selectedText
                        cipher = cipherDropDown.text
                        cipherDropDown.closeTriggered()
                    }

                    Component.onCompleted: {
                        updateSelectedIndex()
                    }
                }

                Connections {
                    target: listView.model
                    function onDataChanged() {
                        cipherListView.updateSelectedIndex()
                    }
                }
            }

            Rectangle {
                id: contentRect
                objectName: "protocolOpenVpnSettingsOptionsPanel:" + index

                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                Layout.preferredHeight: checkboxLayout.implicitHeight
                color: AmneziaStyle.color.onyxBlack
                radius: 16

                ColumnLayout {
                    id: checkboxLayout

                    anchors.fill: parent

                    CheckBoxType {
                        id: tlsAuthCheckBox
                        objectName: "protocolOpenVpnSettingsTlsAuthCheckBox:" + index
                        Accessible.name: text

                        Layout.fillWidth: true

                        text: qsTr("TLS auth")
                        checked: tlsAuth

                        onCheckedChanged: {
                            if (checked !== tlsAuth) {
                                console.log("tlsAuth changed to: " + checked)
                                tlsAuth = checked
                            }
                        }
                    }

                    DividerType {}

                    CheckBoxType {
                        id: blockDnsCheckBox
                        objectName: "protocolOpenVpnSettingsBlockDnsCheckBox:" + index
                        Accessible.name: text

                        Layout.fillWidth: true

                        text: qsTr("Block DNS requests outside of VPN")
                        checked: blockDns

                        onCheckedChanged: {
                            if (checked !== blockDns) {
                                blockDns = checked
                            }
                        }
                    }
                }
            }

            SwitcherType {
                id: additionalClientCommandsSwitcher
                objectName: "protocolOpenVpnSettingsAdditionalClientCommandsSwitch:" + index
                Accessible.name: text

                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                checked: additionalClientCommands !== ""

                text: qsTr("Additional client configuration commands")

                onToggled: function() {
                    if (!checked) {
                        additionalClientCommands = ""
                    }
                }
            }

            TextAreaType {
                id: additionalClientCommandsTextArea
                objectName: "protocolOpenVpnSettingsAdditionalClientCommandsField:" + index
                Accessible.name: qsTr("Additional client configuration commands")

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                visible: additionalClientCommandsSwitcher.checked

                textAreaText: additionalClientCommands
                placeholderText: qsTr("Commands:")

                textArea.onEditingFinished: {
                    if (additionalClientCommands !== textAreaText) {
                        additionalClientCommands = textAreaText
                    }
                }
            }

            SwitcherType {
                id: additionalServerCommandsSwitcher
                objectName: "protocolOpenVpnSettingsAdditionalServerCommandsSwitch:" + index
                Accessible.name: text

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                checked: additionalServerCommands !== ""

                text: qsTr("Additional server configuration commands")

                onToggled: function() {
                    if (!checked) {
                        additionalServerCommands = ""
                    }
                }
            }

            TextAreaType {
                id: additionalServerCommandsTextArea
                objectName: "protocolOpenVpnSettingsAdditionalServerCommandsField:" + index
                Accessible.name: qsTr("Additional server configuration commands")

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                visible: additionalServerCommandsSwitcher.checked

                textAreaText: additionalServerCommands
                placeholderText: qsTr("Commands:")

                textArea.onEditingFinished: {
                    if (additionalServerCommands !== textAreaText) {
                        additionalServerCommands = textAreaText
                    }
                }
            }

            BasicButtonType {
                id: saveButton
                objectName: "protocolOpenVpnSettingsSaveButton:" + index
                Accessible.name: text
                Accessible.role: Accessible.Button

                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.bottomMargin: 24
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: vpnAddressSubnetTextField.errorText === "" &&
                            portTextField.errorText === ""

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
                        InstallController.updateContainer(ServersUiController.processedIndex, ServersUiController.processedContainerIndex, ProtocolEnum.OpenVpn)
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
