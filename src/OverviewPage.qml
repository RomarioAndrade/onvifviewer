/* Copyright (C) 2018-2019 Casper Meijn <casper@meijn.net>
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import org.kde.kirigami as Kirigami
import QtQml.Models
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Kirigami.ScrollablePage {
    id: pageOverview
    title: i18n("Overview")
    objectName: "overviewPage"

    actions: [
        Kirigami.Action {
            text: i18nc("opens the live camera mosaic", "Mosaic")
            icon.name: "view-grid"
            enabled: deviceManager.size > 0
            onTriggered: {
                pageStack.push(mosaicComponent);
            }
        },
        Kirigami.Action {
            text: i18nc("adds a new camera", "Add")
            icon.name: "list-add"
            onTriggered: {
                bottomDrawer.open()
            }
        },
        Kirigami.Action {
            text: i18nc("opens the \"About\" menu", "About")
            icon.name: "help-about"
            onTriggered: {
                pageStack.push(aboutComponent);
            }
        }
    ]

    //Close the drawer with the back button
    onBackRequested: (event) => {
        if (bottomDrawer.visible) {
            event.accepted = true;
            bottomDrawer.close();
        }
    }

    Kirigami.OverlaySheet {
        id: bottomDrawer
        title: i18n("Add a camera")

        // Each way to add a camera is a single tappable row: icon, title and a
        // short explanation, instead of a button paired with loose text.
        component AddOption: Controls.ItemDelegate {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            property alias iconName: optionIcon.source
            property string title
            property string subtitle
            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    id: optionIcon
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Heading {
                        level: 4
                        text: title
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Controls.Label {
                        text: subtitle
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            AddOption {
                visible: deviceDiscover.isAvailable
                iconName: "search"
                title: i18n("Automatically discover camera")
                subtitle: i18n("Automatically find a camera in your network.")
                onClicked: {
                    pageStack.push(discoverCameraComponent);
                    bottomDrawer.close();
                }
            }
            AddOption {
                iconName: "camera-web"
                title: i18n("Add demonstration camera")
                subtitle: i18n("A demonstration camera shows you some of the capabilities, without owning a camera.")
                onClicked: {
                    pageStack.push(addDemoCameraComponent);
                    bottomDrawer.close();
                }
            }
            AddOption {
                iconName: "list-add"
                title: i18n("Manually add camera")
                subtitle: i18n("Provide the connection parameters (hostname or stream URL) yourself.")
                onClicked: {
                    selectedIndex = deviceManager.appendDevice()
                    pageStack.push(settingsComponent);
                    pageStack.currentItem.isNewDevice = true
                    bottomDrawer.close();
                }
            }
            AddOption {
                iconName: "camera-video"
                title: i18n("Add Sofia / XMEye camera")
                subtitle: i18n("Native protocol for XiongMai cameras without working ONVIF (port 34567).")
                onClicked: {
                    selectedIndex = deviceManager.appendDevice()
                    deviceManager.at(selectedIndex).deviceType = "sofia"
                    pageStack.push(settingsComponent);
                    pageStack.currentItem.isNewDevice = true
                    bottomDrawer.close();
                }
            }
        }
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: deviceManager.size === 0
        icon.name: "camera-video"
        text: i18n("No cameras yet")
        explanation: i18n("Add a network camera to start viewing and controlling it.")
        helpfulAction: Kirigami.Action {
            text: i18nc("adds a new camera", "Add camera")
            icon.name: "list-add"
            onTriggered: bottomDrawer.open()
        }
    }

    Kirigami.CardsLayout {
        id: view
        maximumColumnWidth: Kirigami.Units.gridUnit * 40

        Repeater {
            model: deviceManagerModel
            delegate: Kirigami.AbstractCard {
                header: ColumnLayout {
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Heading {
                            level: 2
                            text: model.deviceName || i18n("Camera %1", model.index + 1)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        CameraStatusBadge {
                            errorString: model.errorString
                            isLive: !model.errorString && String(model.device.streamUri).length > 0
                        }
                    }
                    Kirigami.Separator {
                        Layout.fillWidth: true
                    }
                }
                //NOTE: never put a Layout as contentItem as it will cause binding loops
                //SEE: https://bugreports.qt.io/browse/QTBUG-66826
                contentItem: Item {
                    //TODO: This appears to create a binding loop
//                    implicitWidth: 0
                    implicitHeight: delegateLayout.implicitHeight
                    GridLayout {
                        id: delegateLayout
                        anchors {
                            left: parent.left
                            top: parent.top
                            right: parent.right
                        }
                        Controls.Label {
                            id: errorText
                            text: i18n("An error occurred during communication with the camera.")
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            visible: model.errorString
                            Layout.fillWidth: true
                        }
                        Controls.Label {
                            id: snapshotUnsupportedText
                            text: i18n("The camera doesn't support the retrieval of snapshots.")
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            visible: !model.errorString && !model.supportsSnapshotUri
                            Layout.fillWidth: true
                        }
                        OnvifCameraViewer {
                            id: viewerItem
                            camera: model.device
                            snapshotInterval: 5000
                            loadStream: false
                            visible: !model.errorString && model.supportsSnapshotUri
                            Layout.fillWidth: true
                            //TODO: This appears to create a binding loop
                            Layout.preferredHeight: width / viewerItem.aspectRatio
                        }
                    }
                }
                footer: Kirigami.ActionToolBar {
                    id: actionsToolBar
                    actions: [
                        Kirigami.Action {
                            icon.name: "view-preview"
                            text: i18nc("Go to view a camera", "View")
                            onTriggered: {
                                selectedIndex = index
                                pageStack.pop(pageOverview);
                                pageStack.push(deviceViewerComponent);
                            }
                        },
                        Kirigami.Action {
                            checkable: true
                            checked: model.device.showInMosaic
                            icon.name: "view-grid"
                            text: i18nc("toggle showing this camera in the mosaic", "Mosaic")
                            onTriggered: {
                                model.device.showInMosaic = checked
                                deviceManager.saveDevices()
                            }
                        },
                        Kirigami.Action {
                            icon.name: "settings-configure"
                            text: i18nc("Go to settings of a camera", "Settings")
                            onTriggered: {
                                selectedIndex = index
                                pageStack.pop(pageOverview);
                                pageStack.push(settingsComponent);
                            }
                        }
                    ]
                }
            }
        }
    }
}
