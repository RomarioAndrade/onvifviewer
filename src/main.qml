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
import QtQuick
import net.meijn.onvifviewer 1.0

Kirigami.ApplicationWindow {
    id: root

    width: Kirigami.Units.gridUnit * 62
    height: Kirigami.Units.gridUnit * 36
    minimumWidth: Kirigami.Units.gridUnit * 36
    minimumHeight: Kirigami.Units.gridUnit * 22

    // -1 shows every camera in a grid; >= 0 shows that camera large.
    property int selectedIndex: -1
    readonly property OnvifDevice selectedDevice: deviceManager.at(selectedIndex)
    property OnvifDevice previewDevice: null

    onPreviewDeviceChanged: {
        if(previewDevice) {
            selectedIndex = deviceManager.indexOf(previewDevice);
        }
    }

    // The whole UI lives on a single page: camera list on the left, video on
    // the right. Only the "About" page is ever stacked on top (as a layer).
    pageStack.initialPage: MainPage {}

    Component {
        id: aboutComponent
        AboutPage{}
    }
}
