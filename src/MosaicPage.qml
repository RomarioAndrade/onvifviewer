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

Kirigami.ScrollablePage {
    id: pageMosaic
    title: i18n("Mosaic")
    objectName: "mosaicPage"

    // Chosen grid density (columns). Rows flow and the page scrolls.
    property int columns: 2

    // Number of cameras flagged for the mosaic. Recomputed whenever a device
    // property changes so the placeholder and cell sizing stay in sync.
    property int selectedCount: 0
    function updateSelectedCount() {
        var count = 0
        for (var i = 0; i < deviceManager.size; i++) {
            var d = deviceManager.at(i)
            if (d && d.showInMosaic)
                count++
        }
        selectedCount = count
    }
    Component.onCompleted: updateSelectedCount()
    Connections {
        target: deviceManagerModel
        function onDataChanged() { pageMosaic.updateSelectedCount() }
        function onModelReset() { pageMosaic.updateSelectedCount() }
    }

    actions: [
        Kirigami.Action {
            text: i18nc("mosaic grid density", "Layout")
            icon.name: "view-grid"
            Kirigami.Action {
                text: i18n("2 × 2")
                checkable: true
                checked: pageMosaic.columns === 2
                onTriggered: pageMosaic.columns = 2
            }
            Kirigami.Action {
                text: i18n("3 × 3")
                checkable: true
                checked: pageMosaic.columns === 3
                onTriggered: pageMosaic.columns = 3
            }
            Kirigami.Action {
                text: i18n("4 × 4")
                checkable: true
                checked: pageMosaic.columns === 4
                onTriggered: pageMosaic.columns = 4
            }
        }
    ]

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: pageMosaic.selectedCount === 0
        icon.name: "view-grid"
        text: i18n("No cameras in the mosaic")
        explanation: i18n("Pick which cameras appear here from the camera list or its settings.")
        helpfulAction: Kirigami.Action {
            text: i18n("Go to camera list")
            icon.name: "go-previous"
            onTriggered: pageStack.pop(pageMosaic)
        }
    }

    Grid {
        id: grid
        visible: pageMosaic.selectedCount > 0
        columns: pageMosaic.columns
        spacing: Kirigami.Units.smallSpacing
        width: parent.width

        // Square-ish 16:9 cells that divide the available width evenly.
        readonly property real cellWidth: (width - (columns - 1) * spacing) / columns
        readonly property real cellHeight: cellWidth * 9 / 16

        Repeater {
            model: deviceManagerModel
            delegate: Item {
                // Positioners skip invisible items, so unselected cameras leave
                // no gap and the grid reflows as the selection changes.
                visible: model.device && model.device.showInMosaic
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    radius: Kirigami.Units.smallSpacing
                    clip: true

                    OnvifCameraViewer {
                        id: tileViewer
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
                                text: model.device.deviceName || i18n("Camera %1", model.index + 1)
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

                    // Tap a tile to open it fullscreen in the single view.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            selectedIndex = model.index
                            pageStack.push(deviceViewerComponent)
                        }
                    }
                }
            }
        }
    }
}
