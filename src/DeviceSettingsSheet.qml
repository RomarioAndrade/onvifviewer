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
import QtQuick.Dialogs
import QtQuick.Layouts

// Settings of the selected camera as an overlay: the camera list and video
// stay in place behind it. Changes apply when the overlay closes.
Kirigami.OverlaySheet {
    id: sheet

    property bool isNewDevice: false
    property bool hasConnectionSettingsChanged: false
    property bool hasOtherSettingsChanged: false
    readonly property bool isSofia: selectedDevice && selectedDevice.deviceType === "sofia"

    title: isNewDevice ? i18n("New camera") : i18n("Camera settings")

    function openFor(newDevice) {
        isNewDevice = newDevice
        // A brand-new device has nothing filled in yet; connect on close even
        // if the user only typed into some of the fields.
        hasConnectionSettingsChanged = newDevice
        hasOtherSettingsChanged = false
        open()
    }

    onVisibleChanged: {
        if (!visible && (hasConnectionSettingsChanged || hasOtherSettingsChanged)) {
            if (hasConnectionSettingsChanged && selectedDevice) {
                selectedDevice.reconnectToDevice()
            }
            deviceManager.saveDevices()
            hasConnectionSettingsChanged = false
            hasOtherSettingsChanged = false
            isNewDevice = false
        }
    }

    FolderDialog {
        id: recordingFolderDialog
        title: i18n("Choose recording folder")
        currentFolder: deviceManager.recordingFolder ? Qt.resolvedUrl("file://" + deviceManager.recordingFolder) : ""
        onAccepted: deviceManager.recordingFolder = selectedFolder
    }

    Kirigami.PromptDialog {
        id: removeDialog
        title: i18n("Remove camera?")
        subtitle: selectedDevice ? i18n("\"%1\" will be removed from the list.",
                                        selectedDevice.deviceName || i18n("Camera %1", selectedIndex + 1)) : ""
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            var index = selectedIndex
            sheet.hasConnectionSettingsChanged = false
            sheet.hasOtherSettingsChanged = false
            sheet.close()
            selectedIndex = -1
            deviceManager.removeDevice(index)
            deviceManager.saveDevices()
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.gridUnit

        Kirigami.FormLayout {
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
                text: selectedDevice ? selectedDevice.deviceName : ""
                onTextEdited: {
                    hasOtherSettingsChanged = true
                    selectedDevice.deviceName = text
                }
            }
            ComboBox {
                id: protocolCombo
                Kirigami.FormData.label: i18n("Protocol:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                textRole: "label"
                valueRole: "type"
                model: [
                    { label: i18n("ONVIF"), type: "onvif" },
                    { label: i18n("Sofia / XMEye (native)"), type: "sofia" }
                ]
                function syncSelection() {
                    currentIndex = indexOfValue(selectedDevice ? selectedDevice.deviceType : "onvif")
                }
                Component.onCompleted: syncSelection()
                onActivated: {
                    hasConnectionSettingsChanged = true
                    selectedDevice.deviceType = currentValue
                }
                Connections {
                    target: sheet
                    // Qualify the call: inside Connections the ComboBox's own
                    // methods are out of scope, so a bare syncSelection() throws
                    // ReferenceError and the combo never re-syncs on reopen.
                    function onVisibleChanged() { if (sheet.visible) protocolCombo.syncSelection() }
                }
            }
            TextField {
                Kirigami.FormData.label: sheet.isSofia ? i18n("IP address:") : i18n("Hostname:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                placeholderText: sheet.isSofia ? i18n("e.g. 192.168.0.12 (port 34567)")
                                               : i18n("e.g. ipcam.local or 192.168.0.12")
                text: selectedDevice ? selectedDevice.hostName : ""
                onTextEdited: {
                    hasConnectionSettingsChanged = true
                    selectedDevice.hostName = text
                }
            }
            TextField {
                Kirigami.FormData.label: i18n("Manual stream URL:")
                visible: !sheet.isSofia
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                placeholderText: i18n("e.g. rtsp://192.168.0.12:554/stream")
                text: selectedDevice ? selectedDevice.manualStreamUri : ""
                onTextEdited: {
                    hasConnectionSettingsChanged = true
                    selectedDevice.manualStreamUri = text
                }
            }
            TextField {
                Kirigami.FormData.label: i18n("Username:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                text: selectedDevice ? selectedDevice.userName : ""
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
                text: selectedDevice ? selectedDevice.password : ""
                onTextEdited: {
                    hasConnectionSettingsChanged = true
                    selectedDevice.password = text
                }
            }
            ComboBox {
                id: transportCombo
                Kirigami.FormData.label: i18n("Stream transport:")
                visible: !sheet.isSofia
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
                function syncSelection() {
                    currentIndex = indexOfValue(selectedDevice ? selectedDevice.preferredVideoStreamProtocol : "")
                }
                Component.onCompleted: syncSelection()
                onActivated: {
                    hasConnectionSettingsChanged = true
                    selectedDevice.preferredVideoStreamProtocol = currentValue
                }
                Connections {
                    target: sheet
                    function onVisibleChanged() { if (sheet.visible) transportCombo.syncSelection() }
                }
            }
            ComboBox {
                id: profileCombo
                Kirigami.FormData.label: i18n("Video profile:")
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                textRole: "label"
                valueRole: "token"
                // Sofia cameras always offer exactly these two streams; the
                // ONVIF profile list only arrives after the camera connects.
                model: sheet.isSofia ? [
                    { label: i18n("Main stream (high quality)"), token: "Main" },
                    { label: i18n("Substream (fast, lower quality)"), token: "Extra1" }
                ] : (selectedDevice ? selectedDevice.profiles : [])
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
                Connections {
                    target: sheet
                    function onVisibleChanged() { if (sheet.visible) profileCombo.syncSelection() }
                }
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Recording (all cameras)")
                visible: !sheet.isSofia
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Save folder:")
                visible: !sheet.isSofia
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                Label {
                    text: deviceManager.recordingFolder
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Button {
                    text: i18n("Browse…")
                    icon.name: "document-open-folder"
                    onClicked: recordingFolderDialog.open()
                }
            }
            SpinBox {
                Kirigami.FormData.label: i18n("Split every:")
                visible: !sheet.isSofia
                from: 0
                to: 180
                stepSize: 5
                editable: false
                value: deviceManager.recordingSegmentMinutes
                onValueModified: deviceManager.recordingSegmentMinutes = value
                // 0 disables splitting; otherwise show the length in minutes.
                textFromValue: function(value, locale) {
                    return value === 0 ? i18n("Don't split") : i18n("%1 min", value)
                }
            }
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Camera properties")
                visible: !sheet.isSofia
            }
            Switch {
                Kirigami.FormData.label: i18n("Enable camera movement fix")
                visible: !sheet.isSofia
                checked: selectedDevice ? selectedDevice.preferContinuousMove : false
                onCheckedChanged: {
                    hasOtherSettingsChanged = true
                    if (selectedDevice) {
                        selectedDevice.preferContinuousMove = checked
                    }
                }
            }
        }
        Button {
            text: i18n("Remove camera")
            icon.name: "edit-delete"
            visible: !sheet.isNewDevice
            onClicked: removeDialog.open()
            Layout.fillWidth: true
        }
    }
}
