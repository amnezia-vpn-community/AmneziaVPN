import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    objectName: "setupWizardApiTrialEmailPage"
    Accessible.name: qsTr("Create an account")

    property string trialEmailErrorMessage: ""

    Connections {
        target: SubscriptionUiController

        function onTrialEmailError(message) {
            root.trialEmailErrorMessage = message
            emailField.errorText = message
        }
    }

    BackButtonType {
        id: backButton

        objectName: "setupWizardApiTrialEmailBackButton"
        Accessible.name: qsTr("Back")
        Accessible.role: Accessible.Button

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        onFocusChanged: {
            if (activeFocus) {
                flick.contentY = 0
            }
        }
    }

    FlickableType {
        id: flick

        objectName: "setupWizardApiTrialEmailFlickable"
        Accessible.name: root.Accessible.name

        anchors.top: backButton.bottom
        anchors.bottom: continueButton.top
        anchors.left: parent.left
        anchors.right: parent.right

        contentHeight: scrollColumn.implicitHeight + 24

        ColumnLayout {
            id: scrollColumn

            width: flick.width
            spacing: 0

            BaseHeaderType {
                objectName: "setupWizardApiTrialEmailHeader"
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 24

                headerText: qsTr("Create an account")
                descriptionText: qsTr("To manage your subscription")
            }

            TextFieldWithHeaderType {
                id: emailField

                objectName: "setupWizardApiTrialEmailField"
                Accessible.name: headerText
                textField.objectName: "setupWizardApiTrialEmailInput"
                textField.Accessible.name: headerText
                errorObjectName: "setupWizardApiTrialEmailError"

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 24

                headerText: qsTr("Email")
                textField.placeholderText: qsTr("Email")
                textField.inputMethodHints: Qt.ImhEmailCharactersOnly

                Connections {
                    target: emailField.textField

                    function onTextChanged() {
                        if (root.trialEmailErrorMessage !== "") {
                            root.trialEmailErrorMessage = ""
                            emailField.errorText = ""
                        }
                    }
                }
            }

            ParagraphTextType {
                objectName: "setupWizardApiTrialEmailDescription"
                Accessible.name: text

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 24

                wrapMode: Text.WordWrap
                color: AmneziaStyle.color.mutedGray
                font.pixelSize: 12
                text: qsTr("We will create an account for your trial subscription and send important subscription updates to this email address")
            }
        }
    }

    BasicButtonType {
        id: continueButton

        objectName: "setupWizardApiTrialEmailContinueButton"
        Accessible.name: text
        Accessible.role: Accessible.Button

        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16 + PageController.safeAreaBottomMargin

        text: qsTr("Continue")

        clickedFunc: function() {
            root.trialEmailErrorMessage = ""
            emailField.errorText = ""

            var raw = emailField.textField.text.trim()
            if (raw.length === 0 || raw.indexOf("@") < 0) {
                PageController.showNotificationMessage(qsTr("Enter a valid email address"))
                return
            }
            PageController.showBusyIndicator(true)
            var ok = SubscriptionUiController.importTrialFromGateway(raw)
            PageController.showBusyIndicator(false)
            if (ok) {
                PageController.closePage()
                PageController.closePage()
            }
        }
    }
}
