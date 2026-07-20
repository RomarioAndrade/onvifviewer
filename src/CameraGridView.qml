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

// Live grid with every camera at once. Clicking a tile switches to the
// single-camera view of that camera.
Item {
    id: gridView

    // Squarish auto-fit: 1 camera fills the view, 2-4 make a 2-wide grid, etc.
    readonly property int columns: Math.max(1, Math.ceil(Math.sqrt(deviceManager.size)))
    readonly property int rows: Math.max(1, Math.ceil(deviceManager.size / columns))

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: gridView.columns
        spacing: Kirigami.Units.smallSpacing

        // Largest 16:9 cells that keep the whole grid inside the view.
        readonly property real cellWidth: Math.min(
            (gridView.width - (gridView.columns - 1) * spacing) / gridView.columns,
            ((gridView.height - (gridView.rows - 1) * spacing) / gridView.rows) * 16 / 9)
        readonly property real cellHeight: cellWidth * 9 / 16

        Repeater {
            model: deviceManagerModel
            delegate: Rectangle {
                width: grid.cellWidth
                height: grid.cellHeight
                color: "black"
                radius: Kirigami.Units.smallSpacing
                clip: true

                OnvifCameraViewer {
                    anchors.fill: parent
                    camera: model.device
                    loadStream: true
                    visible: !model.errorString
                }

                QQC2.Label {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.largeSpacing
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: "white"
                    text: i18n("Cannot reach the camera")
                    visible: model.errorString
                }

                // Name + live badge, bottom-left over the video.
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Kirigami.Units.smallSpacing
                    radius: Kirigami.Units.smallSpacing
                    color: Qt.rgba(0, 0, 0, 0.55)
                    implicitWidth: tileInfo.implicitWidth + Kirigami.Units.largeSpacing
                    implicitHeight: tileInfo.implicitHeight + Kirigami.Units.smallSpacing
                    RowLayout {
                        id: tileInfo
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        QQC2.Label {
                            text: model.deviceName || i18n("Camera %1", model.index + 1)
                            color: "white"
                            elide: Text.ElideRight
                            Layout.maximumWidth: grid.cellWidth - Kirigami.Units.gridUnit * 3
                        }
                        CameraStatusBadge {
                            errorString: model.errorString
                            isLive: !model.errorString && String(model.device.streamUri).length > 0
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: selectedIndex = model.index
                }
            }
        }
    }
}
