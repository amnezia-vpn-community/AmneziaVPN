import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root
    objectName: "settingsApiInstructionsPage"
    Accessible.name: qsTr("How to connect on another device")

    QtObject {
        id: windows

        readonly property string title: qsTr("Windows")
        readonly property string automationId: "Windows"
        readonly property string link: qsTr("documentation/instructions/connect-amnezia-premium#windows")
    }

    QtObject {
        id: macos

        readonly property string title: qsTr("macOS")
        readonly property string automationId: "Macos"
        readonly property string link: qsTr("documentation/instructions/connect-amnezia-premium#macos")
    }

    QtObject {
        id: android

        readonly property string title: qsTr("Android")
        readonly property string automationId: "Android"
        readonly property string link: qsTr("documentation/instructions/connect-amnezia-premium#android")
    }

    QtObject {
        id: androidTv

        readonly property string title: qsTr("AndroidTV")
        readonly property string automationId: "AndroidTv"
        readonly property string link: qsTr("documentation/instructions/android_tv_connect/")
    }

    QtObject {
        id: ios

        readonly property string title: qsTr("iOS")
        readonly property string automationId: "Ios"
        readonly property string link: qsTr("documentation/instructions/connect-amnezia-premium#ios")
    }

    QtObject {
        id: linux

        readonly property string title: qsTr("Linux")
        readonly property string automationId: "Linux"
        readonly property string link: qsTr("documentation/instructions/connect-amnezia-premium#linux")
    }

    QtObject {
        id: routers

        readonly property string title: qsTr("Routers")
        readonly property string automationId: "Routers"
        readonly property string link: qsTr("documentation/instructions/connect-amnezia-premium#routers")
    }

    property list<QtObject> instructionsModel: [
        windows,
        macos,
        android,
        androidTv,
        ios,
        linux,
        routers
    ]

    ListViewType {
        id: listView
        objectName: "settingsApiInstructionsListView"

        anchors.fill: parent
        anchors.topMargin: 20 + PageController.safeAreaTopMargin
        anchors.bottomMargin: 24

        model: instructionsModel

        header: ColumnLayout {
            width: listView.width

            BackButtonType {
                id: backButton
                objectName: "settingsApiInstructionsBackButton"
            }

            BaseHeaderType {
                id: header
                objectName: "settingsApiInstructionsHeader"
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                headerText: qsTr("How to connect on another device")
                descriptionText: qsTr("Setup guides on the Amnezia website")
            }
        }

        delegate: ColumnLayout {
            width: listView.width

            LabelWithButtonType {
                objectName: "settingsApiInstructions" + automationId + "Button"
                Accessible.name: text
                Accessible.role: Accessible.Button

                Layout.fillWidth: true
                Layout.topMargin: 6

                text: title
                rightImageSource: "qrc:/images/controls/external-link.svg"

                clickedFunction: function() {
                    Qt.openUrlExternally(LanguageUiController.getCurrentDocsUrl(link))
                }
            }

            DividerType {}
        }
    }
}
