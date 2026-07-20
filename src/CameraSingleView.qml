/* Copyright (C) 2026 Romário Andrade
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

// One camera large: name and status on top, live video in the middle and the
// pan/tilt/zoom controls always visible below it (no hidden overlays).
Item {
    id: singleView

    readonly property bool isFullScreen: applicationWindow().visibility === Window.FullScreen

    // Press-and-hold movement: start on press, stop on release.
    component PtzButton: QQC2.ToolButton {
        property real dx: 0
        property real dy: 0
        icon.width: Kirigami.Units.iconSizes.medium
        icon.height: Kirigami.Units.iconSizes.medium
        onPressed: selectedDevice.ptzStartMove(dx, dy)
        onReleased: selectedDevice.ptzStop()
        onCanceled: selectedDevice.ptzStop()
    }

    // Leave fullscreen with Escape.
    Shortcut {
        sequence: "Esc"
        enabled: singleView.visible && singleView.isFullScreen
        onActivated: applicationWindow().visibility = Window.Windowed
    }

    // Let the user know where recordings go, and surface failures.
    Connections {
        target: selectedDevice
        ignoreUnknownSignals: true
        function onIsRecordingChanged() {
            if (selectedDevice.isRecording)
                showPassiveNotification(i18n("Recording to %1", selectedDevice.recordingFile))
            else if (!selectedDevice.recordingError)
                showPassiveNotification(i18n("Recording saved to %1", selectedDevice.recordingFile))
        }
        function onRecordingErrorChanged() {
            if (selectedDevice.recordingError)
                showPassiveNotification(i18n("Recording error: %1", selectedDevice.recordingError))
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                level: 2
                text: selectedDevice ? (selectedDevice.deviceName || i18n("Camera %1", selectedIndex + 1)) : ""
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            CameraStatusBadge {
                errorString: selectedDevice ? selectedDevice.errorString : ""
                isLive: selectedDevice && !selectedDevice.errorString && String(selectedDevice.streamUri).length > 0
            }
            QQC2.Label {
                visible: selectedDevice && selectedDevice.isRecording
                text: i18nc("recording indicator", "● REC")
                color: Kirigami.Theme.negativeTextColor
                font.bold: true
            }
            QQC2.ToolButton {
                visible: selectedDevice && selectedDevice.canRecord
                icon.name: selectedDevice && selectedDevice.isRecording ? "media-playback-stop" : "media-record"
                text: selectedDevice && selectedDevice.isRecording ? i18n("Stop recording") : i18n("Record")
                display: QQC2.AbstractButton.IconOnly
                icon.color: selectedDevice && selectedDevice.isRecording ? Kirigami.Theme.negativeTextColor : undefined
                onClicked: {
                    if (selectedDevice.isRecording)
                        selectedDevice.stopRecording()
                    else
                        selectedDevice.startRecording(deviceManager.recordingFolder)
                }
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "settings-configure"
                text: i18n("Settings")
                display: QQC2.AbstractButton.IconOnly
                visible: !singleView.isFullScreen
                onClicked: settingsSheet.openFor(false)
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: singleView.isFullScreen ? "view-restore" : "view-fullscreen"
                text: singleView.isFullScreen ? i18nc("leave fullscreen", "Exit fullscreen") : i18nc("enter fullscreen", "Fullscreen")
                display: QQC2.AbstractButton.IconOnly
                onClicked: applicationWindow().visibility = singleView.isFullScreen ? Window.Windowed : Window.FullScreen
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
            }
        }

        Rectangle {
            id: previewRectangle
            Layout.fillWidth: true
            implicitHeight: previewContent.height
            color: Kirigami.Theme.highlightColor
            visible: previewDevice && selectedDevice == previewDevice
            RowLayout {
                id: previewContent
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
            visible: selectedDevice && selectedDevice.errorString
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            icon.name: "network-disconnect"
            text: i18n("Cannot reach the camera")
            explanation: selectedDevice && selectedDevice.errorString ? i18n("Technical details: %1", selectedDevice.errorString) : ""
            helpfulAction: Kirigami.Action {
                text: i18nc("retry connecting to the camera", "Reconnect")
                icon.name: "view-refresh"
                onTriggered: selectedDevice.reconnectToDevice()
            }
        }

        OnvifCameraViewer {
            id: viewerItem
            objectName: "cameraViewer"
            camera: selectedDevice
            visible: selectedDevice && !selectedDevice.errorString
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        // PTZ bar: a directional pad plus zoom, centered under the video.
        RowLayout {
            visible: selectedDevice && !selectedDevice.errorString &&
                     (selectedDevice.isPanTiltSupported || selectedDevice.isZoomSupported)
            Layout.alignment: Qt.AlignHCenter
            // Nested layouts default to expanding; the video above gets the space.
            Layout.fillHeight: false
            spacing: Kirigami.Units.gridUnit

            GridLayout {
                visible: selectedDevice && selectedDevice.isPanTiltSupported
                columns: 3
                rowSpacing: 0
                columnSpacing: 0

                PtzButton {
                    Layout.row: 0; Layout.column: 1
                    icon.name: "go-up"
                    dy: 0.1
                }
                PtzButton {
                    Layout.row: 1; Layout.column: 0
                    icon.name: "go-previous"
                    dx: -0.1
                }
                QQC2.ToolButton {
                    Layout.row: 1; Layout.column: 1
                    visible: selectedDevice && selectedDevice.isPtzHomeSupported
                    icon.name: "go-home"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onClicked: selectedDevice.ptzHome()
                    onPressAndHold: {
                        selectedDevice.ptzSaveHomePosition()
                        showPassiveNotification(i18n("Saving current position as home"))
                    }
                }
                PtzButton {
                    Layout.row: 1; Layout.column: 2
                    icon.name: "go-next"
                    dx: 0.1
                }
                PtzButton {
                    Layout.row: 2; Layout.column: 1
                    icon.name: "go-down"
                    dy: -0.1
                }
            }

            Kirigami.Separator {
                visible: selectedDevice && selectedDevice.isPanTiltSupported &&
                         selectedDevice.isZoomSupported
                Layout.fillHeight: true
            }

            ColumnLayout {
                visible: selectedDevice && selectedDevice.isZoomSupported
                spacing: 0
                QQC2.ToolButton {
                    icon.name: "zoom-in"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onPressed: selectedDevice.ptzStartZoom(1)
                    onReleased: selectedDevice.ptzStop()
                    onCanceled: selectedDevice.ptzStop()
                }
                QQC2.ToolButton {
                    icon.name: "zoom-out"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    onPressed: selectedDevice.ptzStartZoom(-1)
                    onReleased: selectedDevice.ptzStop()
                    onCanceled: selectedDevice.ptzStop()
                }
            }
        }
    }
}
