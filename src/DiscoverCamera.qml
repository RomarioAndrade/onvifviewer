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

Kirigami.ScrollablePage {
    id: pageDiscoverCamera
    title: i18n("Discover camera")
    objectName: "discoverCameraPage"

    ColumnLayout {
        width: pageDiscoverCamera.width
        height: pageDiscoverCamera.height

        Kirigami.PlaceholderMessage {
            visible: deviceDiscover.matchList.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignCenter
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

        ListView {
            visible: deviceDiscover.matchList.length !== 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: deviceDiscover.matchList
            delegate: Controls.ItemDelegate {
                icon.name: "camera-video"
                text: modelData.name + " (" + modelData.hardware + ")"
                onClicked: {
                    selectedIndex = deviceManager.appendDevice()
                    var newDevice = deviceManager.at(selectedIndex)
                    newDevice.deviceType = modelData.deviceType;
                    newDevice.deviceName = modelData.name;
                    newDevice.hostName = modelData.host;
                    if (modelData.deviceType !== "sofia") {
                        // Sofia devices need credentials first; the settings
                        // page pushed below collects them before connecting.
                        newDevice.connectToDevice();
                    }
                    deviceManager.saveDevices()

                    pageStack.pop();
                    pageStack.push(settingsComponent);
                    pageStack.currentItem.isNewDevice = true
                }
                width: parent.width
            }
        }
    }
}
