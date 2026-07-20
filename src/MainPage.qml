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

// The single screen of the application: a fixed sidebar with the camera list
// on the left and the live video (grid or single camera) on the right.
// Everything else (settings, adding cameras) opens as an overlay on top, so
// the user never navigates away from their cameras.
Kirigami.Page {
    id: mainPage
    padding: 0
    globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None

    // In fullscreen only the video area remains.
    readonly property bool chromeHidden: applicationWindow().visibility === Window.FullScreen

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: sidebar
            visible: !mainPage.chromeHidden
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 13
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false
            color: Kirigami.Theme.backgroundColor

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Kirigami.Heading {
                    text: i18n("Cameras")
                    level: 4
                    opacity: 0.7
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                }

                QQC2.ItemDelegate {
                    Layout.fillWidth: true
                    icon.name: "view-grid"
                    text: i18n("All cameras")
                    visible: deviceManager.size > 0
                    highlighted: selectedIndex === -1
                    onClicked: selectedIndex = -1
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                    visible: deviceManager.size > 0
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: deviceManagerModel
                    delegate: QQC2.ItemDelegate {
                        width: ListView.view.width
                        highlighted: model.index === selectedIndex
                        onClicked: selectedIndex = model.index
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                source: "camera-video"
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            }
                            QQC2.Label {
                                text: model.deviceName || i18n("Camera %1", model.index + 1)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                implicitWidth: Math.round(Kirigami.Units.gridUnit * 0.5)
                                implicitHeight: implicitWidth
                                radius: width / 2
                                color: model.errorString ? Kirigami.Theme.negativeTextColor
                                     : String(model.device.streamUri).length > 0 ? Kirigami.Theme.positiveTextColor
                                     : Kirigami.Theme.neutralTextColor
                            }
                        }
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                QQC2.ItemDelegate {
                    Layout.fillWidth: true
                    icon.name: "list-add"
                    text: i18n("Add camera")
                    onClicked: addSheet.open()
                }
                QQC2.ItemDelegate {
                    Layout.fillWidth: true
                    icon.name: "settings-configure"
                    text: i18n("Camera settings")
                    enabled: selectedDevice !== null
                    onClicked: settingsSheet.openFor(false)
                }
                QQC2.ItemDelegate {
                    Layout.fillWidth: true
                    icon.name: "help-about"
                    text: i18n("About")
                    onClicked: applicationWindow().pageStack.layers.push(aboutComponent)
                }
            }
        }

        Kirigami.Separator {
            visible: !mainPage.chromeHidden
            Layout.fillHeight: true
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

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
                    onTriggered: addSheet.open()
                }
            }

            CameraGridView {
                anchors.fill: parent
                visible: deviceManager.size > 0 && selectedIndex === -1
            }

            CameraSingleView {
                anchors.fill: parent
                visible: selectedDevice !== null
            }
        }
    }

    DeviceSettingsSheet {
        id: settingsSheet
    }


    AddCameraSheet {
        id: addSheet
        onRequestSettings: settingsSheet.openFor(true)
    }
}
