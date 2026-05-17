import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../Controls2"
import "../Controls2/TextTypes"

import SortFilterProxyModel 0.2

import InstalledAppsModel 1.0
import Style 1.0

DrawerType2 {
    id: root

    Accessible.name: qsTr("Choose application")

    anchors.fill: parent
    expandedHeight: parent.height * 0.9

    onAboutToShow: {
        PageController.showBusyIndicator(true)
        installedAppsModel.updateModel()
        PageController.showBusyIndicator(false)
    }

    InstalledAppsModel {
        id: installedAppsModel
    }

    expandedStateContent: Item {
        id: container

        implicitHeight: expandedHeight

        ColumnLayout {
            id: backButton
            objectName: "installedAppsDrawerContent"

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: searchField.top
            anchors.topMargin: 16

            BackButtonType {
                objectName: "installedAppsDrawerBackButton"
                Accessible.name: qsTr("Back")

                backButtonImage: "qrc:/images/controls/arrow-left.svg"
                backButtonFunction: function() {
                    root.closeTriggered()
                }
            }

            Header2Type {
                id: header
                objectName: "installedAppsDrawerHeader"
                Accessible.name: headerText

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                headerText: qsTr("Choose application")
            }

            ListViewType {
                id: listView
                objectName: "installedAppsDrawerListView"

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                model: SortFilterProxyModel {
                    id: proxyInstalledAppsModel
                    sourceModel: installedAppsModel
                    filters: RegExpFilter {
                        roleName: "appName"
                        pattern: ".*" + searchField.textField.text + ".*"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                }

                ButtonGroup {
                    id: buttonGroup
                }

                delegate: ColumnLayout {
                    objectName: "installedAppsDrawerDelegate:" + proxyInstalledAppsModel.mapToSource(index)

                    width: listView.width

                    RowLayout {
                        CheckBoxType {
                            objectName: "installedAppsDrawerAppCheckBox:" + proxyInstalledAppsModel.mapToSource(index)
                            Accessible.name: appName

                            Layout.fillWidth: true

                            text: appName
                            checked: isAppSelected
                            onCheckedChanged: {
                                installedAppsModel.selectedStateChanged(proxyInstalledAppsModel.mapToSource(index), checked)
                            }
                        }

                        Image {
                            source: "image://installedAppImage/" + appIcon

                            sourceSize.width: 24
                            sourceSize.height: 24

                            Layout.rightMargin: 48
                        }
                    }

                    DividerType {}
                }
            }
        }

        TextFieldWithHeaderType {
            id: searchField
            objectName: "installedAppsDrawerSearchField"

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: addButton.top
            anchors.bottomMargin: 16
            anchors.rightMargin: 16
            anchors.leftMargin: 16

            backgroundColor: AmneziaStyle.color.slateGray

            textField.placeholderText: qsTr("application name")
            textField.objectName: "installedAppsDrawerSearchInput"
        }

        BasicButtonType {
            id: addButton
            objectName: "installedAppsDrawerAddSelectedButton"
            Accessible.name: text

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.rightMargin: 16
            anchors.leftMargin: 16

            text: qsTr("Add selected")

            clickedFunc: function() {
                PageController.showBusyIndicator(true)
                AppSplitTunnelingController.addApps(installedAppsModel.getSelectedAppsInfo())
                PageController.showBusyIndicator(false)
                root.closeTriggered()
            }
        }
    }
}
