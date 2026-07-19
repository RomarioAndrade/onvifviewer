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
        contentItem: ColumnLayout {
            Controls.Button {
                text: i18n("Automaticly discover camera")
                Layout.fillWidth: true
                onClicked: {
                    pageStack.push(discoverCameraComponent);
                    bottomDrawer.close();
                }
                visible: deviceDiscover.isAvailable
            }
            Controls.Label {
                text: i18n("Automatically find a camera in your network.");
                wrapMode: Text.WordWrap
                horizontalAlignment: "AlignHCenter"
                Layout.leftMargin: Kirigami.Units.gridUnit * 2
                Layout.rightMargin: Kirigami.Units.gridUnit * 2
                Layout.fillWidth: true
                visible: deviceDiscover.isAvailable
            }
            Controls.Button {
                text: i18n("Add demonstration camera")
                Layout.fillWidth: true
                onClicked: {
                    pageStack.push(addDemoCameraComponent);
                    bottomDrawer.close();
                }
            }
            Controls.Label {
                text: i18n("These demonstration cameras show you some on the capabilities, without owning a camera.");
                wrapMode: Text.WordWrap
                horizontalAlignment: "AlignHCenter"
                Layout.leftMargin: Kirigami.Units.gridUnit * 2
                Layout.rightMargin: Kirigami.Units.gridUnit * 2
                Layout.fillWidth: true
            }
            Controls.Button {
                text: i18n("Manually add camera")
                Layout.fillWidth: true
                onClicked: {
                    selectedIndex = deviceManager.appendDevice()
                    pageStack.push(settingsComponent);
                    pageStack.currentItem.isNewDevice = true
                    bottomDrawer.close();
                }
            }
            Controls.Label {
                text: i18n("Manually adding a camera means that you need to provide the connection parameters yourself.");
                wrapMode: Text.WordWrap
                horizontalAlignment: "AlignHCenter"
                Layout.leftMargin: Kirigami.Units.gridUnit * 2
                Layout.rightMargin: Kirigami.Units.gridUnit * 2
                Layout.fillWidth: true
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
