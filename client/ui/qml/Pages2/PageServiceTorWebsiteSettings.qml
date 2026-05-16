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
    objectName: "serviceTorWebsiteSettingsPage"
    Accessible.name: qsTr("Tor website settings")

    Connections {
        target: InstallController

        function onUpdateContainerFinished() {
            PageController.showNotificationMessage(qsTr("Settings updated successfully"))
        }
    }

    BackButtonType {
        id: backButton
        objectName: "serviceTorWebsiteSettingsBackButton"
        Accessible.name: qsTr("Back")
        Accessible.role: Accessible.Button

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
        objectName: "serviceTorWebsiteSettingsListView"
        Accessible.name: qsTr("Tor website settings")

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        header: ColumnLayout {
            width: listView.width

            BaseHeaderType {
                objectName: "serviceTorWebsiteSettingsHeader"
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("Tor website settings")
            }
        }

        model: TorConfigModel

        delegate: ColumnLayout {
            width: listView.width

            LabelWithButtonType {
                id: websiteName
                objectName: "serviceTorWebsiteSettingsWebsiteButton:" + index
                Accessible.name: text
                Accessible.description: descriptionText
                Accessible.role: Accessible.Button

                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.bottomMargin: 24

                text: qsTr("Website address")
                descriptionText: site || ""

                descriptionOnTop: true
                textColor: AmneziaStyle.color.goldenApricot

                rightImageSource: "qrc:/images/controls/copy.svg"
                rightImageColor: AmneziaStyle.color.paleGray

                clickedFunction: function() {
                    GC.copyToClipBoard(descriptionText)
                    PageController.showNotificationMessage(qsTr("Copied"))
                }
            }
        }

        footer: ColumnLayout {
            width: listView.width

            ParagraphTextType {
                objectName: "serviceTorWebsiteSettingsTorBrowserHint"
                Accessible.name: qsTr("Use Tor Browser to open this URL.")

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                onLinkActivated: Qt.openUrlExternally(link)
                textFormat: Text.RichText
                text: qsTr("Use <a href=\"https://www.torproject.org/download/\" style=\"color: #FBB26A;\">Tor Browser</a> to open this URL.")
            }

            ParagraphTextType {
                objectName: "serviceTorWebsiteSettingsAvailabilityHint"
                Accessible.name: text

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("After creating your onion site, it takes a few minutes for the Tor network to make it available for use.")
            }

            ParagraphTextType {
                objectName: "serviceTorWebsiteSettingsWordPressHint"
                Accessible.name: text

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("When configuring WordPress set the this onion address as domain.")
            }
        }
    }
}
