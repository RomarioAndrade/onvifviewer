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
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window

Kirigami.Page {
    property OnvifDevice selectedDevice: deviceManager.at(selectedIndex)

    title: selectedDevice.deviceName || i18n("Camera %1", selectedIndex + 1)
    actions: [
        Kirigami.Action {
            text: i18nc("opens pan/tilt/zoom overlay", "Move")
            visible: selectedDevice.isPanTiltSupported || selectedDevice.isZoomSupported
            icon.name: "transform-move"
            onTriggered: {
                if (ptzOverlay.visible) ptzOverlay.close(); else ptzOverlay.open()
            }
        },
        Kirigami.Action {
            text: i18nc("opens device information overlay", "Device information")
            icon.name: "help-about"
            onTriggered: {
                if (deviceInformation.visible) deviceInformation.close(); else deviceInformation.open()
            }
        },
        Kirigami.Action {
            readonly property bool isFullScreen: applicationWindow().visibility === Window.FullScreen
            text: isFullScreen ? i18nc("leave fullscreen", "Exit fullscreen") : i18nc("enter fullscreen", "Fullscreen")
            icon.name: isFullScreen ? "view-restore" : "view-fullscreen"
            onTriggered: {
                applicationWindow().visibility = isFullScreen ? Window.Windowed : Window.FullScreen
            }
        }
    ]
    Kirigami.OverlaySheet {
        id: ptzOverlay
        RowLayout {
            spacing: Kirigami.Units.gridUnit
            Rectangle {
                Layout.fillWidth: true
            }
            GridLayout {
                visible: selectedDevice.isPanTiltSupported
                columns: 3

                QQC2.ToolButton {
                    Layout.row: 0
                    Layout.column: 1
                    icon.name: "go-up"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: {
                        selectedDevice.ptzUp()
                    }
                }
                QQC2.ToolButton {
                    Layout.row: 1
                    Layout.column: 0
                    icon.name: "go-previous"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: {
                        selectedDevice.ptzLeft()
                    }
                }
                QQC2.ToolButton {
                    Layout.row: 1
                    Layout.column: 1
                    visible: selectedDevice.isPtzHomeSupported
                    icon.name: "go-home"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: {
                        selectedDevice.ptzHome()
                    }
                    onPressAndHold: {
                        selectedDevice.ptzSaveHomePosition()
                        showPassiveNotification(i18n("Saving current position as home"))
                    }
                }
                QQC2.ToolButton {
                    Layout.row: 1
                    Layout.column: 2
                    icon.name: "go-next"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: {
                        selectedDevice.ptzRight()
                    }
                }
                QQC2.ToolButton {
                    Layout.row: 2
                    Layout.column: 1
                    icon.name: "go-down"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: {
                        selectedDevice.ptzDown()
                    }
                }
            }
            ColumnLayout {
                visible: selectedDevice.isZoomSupported
                QQC2.ToolButton {
                    icon.name: "zoom-in"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: {
                        selectedDevice.ptzZoomIn()
                    }
                }
                QQC2.ToolButton {
                    icon.name: "zoom-out"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: {
                        selectedDevice.ptzZoomOut()
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
            }
        }
    }
    Kirigami.OverlaySheet {
        id: deviceInformation
        GridLayout {
            columns: 2

            Kirigami.Heading {
                text: i18n("Device information")
                Layout.columnSpan: 2
                level: 2
            }

            QQC2.Label {
                text: i18n("Manufacturer:")
            }
            QQC2.Label {
                text: selectedDevice.deviceInformation.manufacturer
            }

            QQC2.Label {
                text: i18n("Model:")
            }
            QQC2.Label {
                text: selectedDevice.deviceInformation.model
            }

            QQC2.Label {
                text: i18n("Firmware version:")
            }
            QQC2.Label {
                text: selectedDevice.deviceInformation.firmwareVersion
            }

            QQC2.Label {
                text: i18n("Serial number:")
            }
            QQC2.Label {
                text: selectedDevice.deviceInformation.serialNumber
            }

            QQC2.Label {
                text: i18n("Hardware identifier:")
            }
            QQC2.Label {
                text: selectedDevice.deviceInformation.hardwareId
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        Rectangle {
            id: previewRectangle
            Layout.fillWidth: true
            implicitHeight: content.height
            color: Kirigami.Theme.highlightColor
            visible: selectedDevice == previewDevice
            RowLayout {
                id: content
                width: parent.width

                Text {
                    text: i18n("This camera is currently only opened as a preview. This means that the device is not loaded the next time you open this application. If you want to save this device, then you need to click the Save button.")
                    wrapMode: Text.Wrap
                    color: Kirigami.Theme.highlightedTextColor
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.gridUnit
                }
                QQC2.ToolButton {
                    icon.name: "document-save"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    icon.color: Kirigami.Theme.highlightedTextColor
                    Layout.margins: Kirigami.Units.gridUnit
                    onClicked: {
                        deviceManager.saveDevices()
                        previewDevice = null
                    }
                }
            }
        }
        Kirigami.PlaceholderMessage {
            visible: selectedDevice.errorString
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            icon.name: "network-disconnect"
            text: i18n("Cannot reach the camera")
            explanation: selectedDevice.errorString ? i18n("Technical details: %1", selectedDevice.errorString) : ""
            helpfulAction: Kirigami.Action {
                text: i18nc("retry connecting to the camera", "Reconnect")
                icon.name: "view-refresh"
                onTriggered: {
                    selectedDevice.reconnectToDevice()
                }
            }
        }

        OnvifCameraViewer {
            id: viewerItem
            objectName: "cameraViewer"
            camera: selectedDevice
            visible: !selectedDevice.errorString
            Layout.fillHeight: true
            Layout.fillWidth: true

            // Live status pill over the video (top-left).
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Kirigami.Units.smallSpacing
                radius: Kirigami.Units.smallSpacing
                color: Qt.rgba(0, 0, 0, 0.55)
                visible: viewerItem.visible
                implicitWidth: statusBadge.implicitWidth + Kirigami.Units.largeSpacing
                implicitHeight: statusBadge.implicitHeight + Kirigami.Units.smallSpacing
                CameraStatusBadge {
                    id: statusBadge
                    anchors.centerIn: parent
                    errorString: selectedDevice.errorString
                    isLive: !selectedDevice.errorString && String(selectedDevice.streamUri).length > 0
                }
            }
        }
    }
}
