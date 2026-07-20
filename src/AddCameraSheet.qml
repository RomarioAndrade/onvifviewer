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
import net.meijn.onvifviewer 1.0
import org.kde.kirigami as Kirigami
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

// Every way to add a camera in a single overlay: pick a method, and the
// discovered/demo lists open in place (with a back button) instead of
// navigating to another screen.
Kirigami.OverlaySheet {
    id: sheet

    // Asks MainPage to open the settings overlay for the just-added camera.
    signal requestSettings()

    // 0 = method list, 1 = discovered cameras, 2 = demo cameras
    property int mode: 0

    title: mode === 1 ? i18n("Discovered cameras")
         : mode === 2 ? i18n("Demonstration cameras")
         : i18n("Add a camera")

    onVisibleChanged: {
        if (visible) {
            mode = 0
        }
    }

    function addDevice(deviceType) {
        selectedIndex = deviceManager.appendDevice()
        if (deviceType) {
            deviceManager.at(selectedIndex).deviceType = deviceType
        }
        close()
        requestSettings()
    }

    // Each way to add a camera is a single tappable row: icon, title and a
    // short explanation.
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

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Controls.ToolButton {
            icon.name: "go-previous"
            text: i18n("Back")
            visible: sheet.mode !== 0
            onClicked: sheet.mode = 0
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: sheet.mode

            // Method list.
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                AddOption {
                    iconName: "search"
                    title: i18n("Automatically discover camera")
                    subtitle: i18n("Automatically find a camera in your network.")
                    onClicked: sheet.mode = 1
                }
                AddOption {
                    iconName: "list-add"
                    title: i18n("Manually add camera")
                    subtitle: i18n("Provide the connection parameters (hostname or stream URL) yourself.")
                    onClicked: sheet.addDevice("")
                }
                AddOption {
                    iconName: "camera-video"
                    title: i18n("Add Sofia / XMEye camera")
                    subtitle: i18n("Native protocol for XiongMai cameras without working ONVIF (port 34567).")
                    onClicked: sheet.addDevice("sofia")
                }
                AddOption {
                    iconName: "camera-web"
                    title: i18n("Add demonstration camera")
                    subtitle: i18n("A demonstration camera shows you some of the capabilities, without owning a camera.")
                    onClicked: sheet.mode = 2
                }
            }

            // Discovered cameras.
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.PlaceholderMessage {
                    visible: deviceDiscover.matchList.length === 0
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
                    icon.name: "network-wireless"
                    text: i18n("Searching for cameras…")
                    explanation: i18n("Looking for ONVIF and Sofia/XMEye cameras on your local network.")

                    Controls.BusyIndicator {
                        running: parent.visible
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Controls.Label {
                    text: i18n("Click on a discovered camera to add it:")
                    visible: deviceDiscover.matchList.length !== 0
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Repeater {
                    model: deviceDiscover.matchList
                    delegate: Controls.ItemDelegate {
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
                        icon.name: "camera-video"
                        text: modelData.name + " (" + modelData.hardware + ")"
                        onClicked: {
                            selectedIndex = deviceManager.appendDevice()
                            var newDevice = deviceManager.at(selectedIndex)
                            newDevice.deviceType = modelData.deviceType;
                            newDevice.deviceName = modelData.name;
                            newDevice.hostName = modelData.host;
                            if (modelData.deviceType !== "sofia") {
                                // Sofia devices need credentials first; the
                                // settings overlay collects them.
                                newDevice.connectToDevice();
                            }
                            deviceManager.saveDevices()
                            sheet.close()
                            sheet.requestSettings()
                        }
                    }
                }
            }

            // Demo cameras.
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                ListModel {
                    id: demoCameraModel
                    ListElement {
                        deviceName: "Demo Norway"
                        hostName: "79.160.18.23:10000"
                        userName: ""
                        password: ""
                        preferredVideoStreamProtocol: "RtspOverHttp"
                    }
                    ListElement {
                        deviceName: "Demo Zurich"
                        hostName: "213.173.165.16:90"
                        userName: ""
                        password: ""
                    }
                    ListElement {
                        deviceName: "Demo frontdoor"
                        hostName: "84.171.95.10:50001"
                        userName: "service"
                        password: "service"
                    }
                }

                Repeater {
                    model: demoCameraModel
                    delegate: Controls.ItemDelegate {
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
                        icon.name: "camera-web"
                        text: deviceName
                        onClicked: {
                            selectedIndex = deviceManager.appendDevice()
                            var newDevice = deviceManager.at(selectedIndex)
                            newDevice.deviceName = deviceName;
                            newDevice.hostName = hostName;
                            newDevice.userName = userName ? userName : "";
                            newDevice.password = password ? password : "";
                            newDevice.preferredVideoStreamProtocol = preferredVideoStreamProtocol ? preferredVideoStreamProtocol : "";
                            newDevice.connectToDevice();
                            deviceManager.saveDevices()
                            sheet.close()
                        }
                    }
                }
            }
        }
    }
}
