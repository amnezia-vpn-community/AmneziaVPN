import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import SortFilterProxyModel 0.2

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

PageType {
    id: root
    objectName: "apiServicesListPage"

    BackButtonType {
        id: backButton
        objectName: "apiServicesListBackButton"

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
        objectName: "apiServicesListView"

        anchors.top: backButton.bottom
        anchors.right: parent.right
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.topMargin: 16

        header: ColumnLayout {
            width: listView.width

            BaseHeaderType {
                objectName: "apiServicesListHeader"

                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 24

                headerText: qsTr("VPN by Amnezia")
                descriptionText: qsTr("Choose a VPN service that suits your needs.")
            }
        }

        spacing: 0

        model: SortFilterProxyModel {
            id: proxyApiServicesModel

            sourceModel: ApiServicesModel
            sorters: RoleSorter {
                roleName: "order"
                sortOrder: Qt.AscendingOrder
            }
        }

        delegate: ColumnLayout {
            property bool hideCard: isPremium && !hasSubscriptionPlans
            readonly property int sourceIndex: proxyApiServicesModel.mapToSource(index)
            readonly property bool isAmneziaFree: sourceIndex === ApiServicesModel.serviceIndexForType("amnezia-free")
            readonly property bool isAmneziaPremium: sourceIndex === ApiServicesModel.serviceIndexForType("amnezia-premium")
            readonly property string serviceObjectName: isAmneziaFree
                ? "apiServiceRow:amnezia-free"
                : isAmneziaPremium ? "apiServiceRow:amnezia-premium" : "apiServiceRow:" + sourceIndex

            width: listView.width
            visible: !hideCard
            height: hideCard ? 0 : implicitHeight

            enabled: isServiceAvailable

            CardWithIconsType {
                id: card
                objectName: serviceObjectName
                Accessible.name: name
                Accessible.description: cardDescription

                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 16

                headerText: name
                bodyText: cardDescription
                footerText: price

                showRecommendedBadge: showRecommended && isServiceAvailable
                recommendedText: qsTr("Recommended")

                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                onClicked: {
                    if (isServiceAvailable) {
                        ApiServicesModel.setServiceIndex(proxyApiServicesModel.mapToSource(index))
                        if (ApiServicesModel.getSelectedServiceType() === "amnezia-premium") {
                            PageController.goToPage(PageEnum.PageSetupWizardApiPremiumInfo)
                        } else {
                            PageController.goToPage(PageEnum.PageSetupWizardApiFreeInfo)
                        }
                    }
                }
                
                Keys.onEnterPressed: clicked()
                Keys.onReturnPressed: clicked()
            }
        }
    }
}
