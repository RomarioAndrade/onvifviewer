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

    property int selectedIndex: 0
    property OnvifDevice previewDevice: null

    onPreviewDeviceChanged: {
        if(previewDevice) {
            selectedIndex = deviceManager.indexOf(previewDevice);
            pageStack.push(deviceViewerComponent);
        }
    }

    contextDrawer: Kirigami.ContextDrawer {
        id: contextDrawer
    }

    // Always show a header toolbar with a back button on pushed pages,
    // so it is always possible to navigate back to the previous screen.
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar
    pageStack.globalToolBar.showNavigationButtons: Kirigami.ApplicationHeaderStyle.ShowBackButton

    pageStack.initialPage: overviewComponent
    Component {
        id: deviceViewerComponent
        DeviceViewerPage{}
    }
    Component {
        id: settingsComponent
        DeviceSettingsPage{}
    }
    Component {
        id: overviewComponent
        OverviewPage{}
    }
    Component {
        id: mosaicComponent
        MosaicPage{}
    }
    Component {
        id: addDemoCameraComponent
        AddDemoCamera{}
    }
    Component {
        id: discoverCameraComponent
        DiscoverCamera{}
    }
    
    Component {
        id: aboutComponent
        AboutPage{}
    }
}

