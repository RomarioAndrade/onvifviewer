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
import QtMultimedia
import QtQuick

Item {
    id: viewer

    property alias streamUri: video.source
    // Preview audio, off by default. ONVIF RTSP streams carry the camera's
    // audio track; the caller flips this to let the user hear it.
    property bool muted: true
    property bool hasError: video.error !== MediaPlayer.NoError

    function isStreamAvailable() {
        return video.playbackState === MediaPlayer.PlayingState && video.hasVideo && video.source != ""
    }

    onVisibleChanged: {
        if(viewer.visible)
            video.play()
        else
            video.stop()
    }

    MediaPlayer {
        id: video
        videoOutput: videoOutput
        audioOutput: AudioOutput {
            muted: viewer.muted
        }
        onSourceChanged: {
            if (source != "")
                play()
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
    }
}
