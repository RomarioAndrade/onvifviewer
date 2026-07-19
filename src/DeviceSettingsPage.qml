/* Copyright (C) 2018 Casper Meijn <casper@meijn.net>
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
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Kirigami.ScrollablePage {
    property bool hasConnectionSettingsChanged: false
    property bool hasOtherSettingsChanged: false
    property bool isNewDevice: false

    title: isNewDevice ? i18n("New manual device") : i18n("Device settings")
    objectName: "settingsPage"

    onIsCurrentPageChanged: {
        if(!isCurrentPage) {
            if(hasConnectionSettingsChanged || hasOtherSettingsChanged) {
                if(hasConnectionSettingsChanged) {
                    selectedDevice.reconnectToDevice()
                }
                deviceManager.saveDevices()
                hasConnectionSettingsChanged = false;
                hasOtherSettingsChanged = false
            }
            isNewDevice = false
        }
    }

    property OnvifDevice selectedDevice: deviceManager.at(selectedIndex)

    ColumnLayout {
        spacing: Kirigami.Units.gridUnit

        // TODO: Figure out why this FormLayout is broken if the Style=Default in qtquickcontrols2.conf and work correct if Style=Material
        Kirigami.FormLayout {
            id: layout
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Connection settings")
            }
            TextField {
                Kirigami.FormData.label: i18n("Camera name:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                placeholderText: i18n("e.g. Backyard")
                text: selectedDevice && selectedDevice.deviceName
                onTextEdited: {
                    hasOtherSettingsChanged = true
                    selectedDevice.deviceName = text
                }
            }
            TextField {
                Kirigami.FormData.label: i18n("Hostname:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                placeholderText: i18n("e.g. ipcam.local or 192.168.0.12")
                text: selectedDevice && selectedDevice.hostName
                onTextEdited: {
                    hasConnectionSettingsChanged = true
                    selectedDevice.hostName = text
                }
            }
            TextField {
                Kirigami.FormData.label: i18n("Username:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                text: selectedDevice && selectedDevice.userName
                onTextEdited: {
                    hasConnectionSettingsChanged = true
                    selectedDevice.userName = text
                }
            }
            TextField {
                Kirigami.FormData.label: i18n("Password:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                echoMode: TextInput.Password
                text: selectedDevice && selectedDevice.password
                onTextEdited: {
                    hasConnectionSettingsChanged = true
                    selectedDevice.password = text
                }
            }
            ComboBox {
                Kirigami.FormData.label: i18n("Stream transport:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                textRole: "label"
                valueRole: "protocol"
                // UDP is prone to packet loss, which corrupts H.264/H.265
                // reference frames and makes the decoder fail. TCP (RTSP) or
                // RTSP over HTTP are more robust on lossy networks.
                model: [
                    { label: i18n("Automatic (camera default)"), protocol: "" },
                    { label: i18n("UDP (RTP unicast)"), protocol: "RtspUnicast" },
                    { label: i18n("TCP (RTSP)"), protocol: "RTSP" },
                    { label: i18n("RTSP over HTTP"), protocol: "RtspOverHttp" }
                ]
                Component.onCompleted: {
                    currentIndex = indexOfValue(selectedDevice ? selectedDevice.preferredVideoStreamProtocol : "")
                }
                onActivated: {
                    hasConnectionSettingsChanged = true
                    selectedDevice.preferredVideoStreamProtocol = currentValue
                }
            }
            ComboBox {
                id: profileCombo
                Kirigami.FormData.label: i18n("Video profile:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                textRole: "label"
                valueRole: "token"
                // The profile list only arrives after the camera connects.
                model: selectedDevice ? selectedDevice.profiles : []
                enabled: count > 0
                displayText: count > 0 ? currentText : i18n("Loading…")
                function syncSelection() {
                    currentIndex = indexOfValue(selectedDevice ? selectedDevice.selectedProfileToken : "")
                }
                onCountChanged: syncSelection()
                Component.onCompleted: syncSelection()
                onActivated: {
                    // Switches the stream live; persist the choice without a
                    // full reconnect (selectProfile already re-fetches the URIs).
                    hasOtherSettingsChanged = true
                    selectedDevice.selectedProfileToken = currentValue
                }
                Connections {
                    target: selectedDevice
                    function onSelectedProfileTokenChanged() { profileCombo.syncSelection() }
                }
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Camera properties")
            }
            Switch {
                Kirigami.FormData.label: i18n("Enable camera movement fix")
                checked: selectedDevice && selectedDevice.preferContinuousMove
                onCheckedChanged: {
                    hasOtherSettingsChanged = true
                    selectedDevice.preferContinuousMove = checked
                }
            }
        }
        Button {
            text: i18n("Remove camera")
            onClicked: {
                pageStack.pop();
                deviceManager.removeDevice(selectedIndex)
                deviceManager.saveDevices()
            }
            Layout.fillWidth: true
            Material.background: Material.Red
        }
    }
}
