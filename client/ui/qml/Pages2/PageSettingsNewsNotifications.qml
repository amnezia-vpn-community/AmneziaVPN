import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

PageType {
    id: root
    objectName: "settingsNewsNotificationsPage"
    Accessible.name: qsTr("News & Notifications")

    ColumnLayout {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        BackButtonType {
            id: backButton
            objectName: "settingsNewsNotificationsBackButton"
            Accessible.name: qsTr("Back")
        }

        BaseHeaderType {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            objectName: "settingsNewsNotificationsHeader"
            Accessible.name: headerText

            headerText: qsTr("News & Notifications")
        }
    }

    ListView {
        id: newsList
        objectName: "settingsNewsNotificationsListView"
        Accessible.name: qsTr("News & Notifications")
        width: parent.width
        anchors.top: header.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        property bool isFocusable: true

        model: NewsModel
        
        clip: true
        reuseItems: true

        delegate: Item {
            objectName: "settingsNewsNotificationsDelegate:" + index
            Accessible.name: title
            implicitWidth: newsList.width
            implicitHeight: content.implicitHeight

            ColumnLayout {
                id: content
                objectName: "settingsNewsNotificationsDelegateContent:" + index
                Accessible.name: title
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right

                LabelWithButtonType {
                    objectName: "settingsNewsNotificationsItemButton:" + index
                    Accessible.name: title
                    Layout.fillWidth: true
                    leftImageSource: read ? "" : "qrc:/images/controls/unread-dot.svg"
                    isSmallLeftImage: !read
                    text: title
                    descriptionText: Qt.formatDateTime(timestamp, "dd.MM.yyyy HH:mm")
                    rightImageSource: "qrc:/images/controls/chevron-right.svg"

                    clickedFunction: function() {
                        if (!isUpdate) {
                            NewsModel.markAsRead(index)
                        }
                        NewsModel.processedIndex = index
                        PageController.goToPage(PageEnum.PageSettingsNewsDetail)
                    }
                }

                DividerType {}
            }
        }
    }
} 
