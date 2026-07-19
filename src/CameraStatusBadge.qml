/* Copyright (C) 2026
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
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A small "● Live / Connecting… / Error" status pill for a camera.
RowLayout {
    id: badge

    // Set these from the caller.
    property string errorString: ""
    property bool isLive: false

    // 0 = live, 1 = connecting, 2 = error
    readonly property int state: errorString ? 2 : (isLive ? 0 : 1)

    readonly property color stateColor: state === 0 ? Kirigami.Theme.positiveTextColor
                                       : state === 2 ? Kirigami.Theme.negativeTextColor
                                       : Kirigami.Theme.neutralTextColor
    readonly property string stateText: state === 0 ? i18nc("camera stream status", "Live")
                                      : state === 2 ? i18nc("camera stream status", "Error")
                                      : i18nc("camera stream status", "Connecting…")

    spacing: Kirigami.Units.smallSpacing

    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: Math.round(Kirigami.Units.gridUnit * 0.55)
        implicitHeight: implicitWidth
        radius: width / 2
        color: badge.stateColor

        // Gentle pulse while connecting, so it reads as "in progress".
        SequentialAnimation on opacity {
            running: badge.state === 1
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { from: 1.0; to: 0.3; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.3; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
        }
    }

    QQC2.Label {
        text: badge.stateText
        color: badge.stateColor
        font: Kirigami.Theme.smallFont
    }
}
