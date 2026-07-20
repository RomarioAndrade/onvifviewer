<!--
Copyright (C) 2019 Casper Meijn <casper@meijn.net>

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ONVIFViewer

**ONVIF camera viewer for Plasma Mobile and Linux desktop**

The goal of this project is to replace the proprietary app that was needed to configure and view my IP camera. The ONVIF protocol can be used to view and configure many types of camera's and is a open standard that can be implemented using standard SOAP libraries. Using Qt6 for the back-end and Kirigami UI framework makes this application a cross-platform solution. The primary focus is Plasma mobile and the Linux desktop, but an Android build is also available. 

This project was started as part of the [ONVIF Open Source Spotlight Challange](https://onvif-spotlight.bemyapp.com/#/projects/5ae0bbf7f98fde00047f0605) and the application finished in [fourth place](https://www.onvif.org/blog/2018/07/onvif-challenge-announces-top-10/) (out of 37 submissions). 
Before this project started, there was no open-source application for viewing ONVIF cameras for Plasma Mobile and Linux desktop. Neither is there a simple to use open-source C++ library to communicate with ONVIF cameras. The communication with the camera is implemented from scratch (using KDSoap) and modular designed, so that it can be separated into a reusable library at a later stage.

> **Note:** This repository is a fork maintained by Romário Andrade. It ports the
> application to Qt6/KF6 and fixes issues with cameras that don't fully comply
> with the ONVIF specification. All credit for the original application goes to
> Casper Meijn — the upstream project lives at
> <https://gitlab.com/caspermeijn/onvifviewer>.


## Current state

This fork is under active development. The application has been ported to Qt6
and KDE Frameworks 6 (KF6), and the focus is on making the viewer work with
real-world IP cameras — including the many models that don't fully comply with
the ONVIF specification.

Features added in this fork include automatic discovery of cameras on the LAN, a
single-screen UI with a camera sidebar, per-camera stream transport and video
profile selection, press-and-hold PTZ control, snapshot download, an audio
preview with a mute toggle, and recording ONVIF streams to disk (optionally
split into time-based segments).

The original author, Casper Meijn, stopped development on the upstream project;
this fork picks it back up. Contributions are welcome — feel free to open an
issue or send a merge/pull request.

## Translations
You can help translating this application using [Weblate](https://hosted.weblate.org/engage/onvifviewer/). You can login on the website and translate the texts to your language. The translations will be included in the next release.

[<img src="https://hosted.weblate.org/widgets/onvifviewer/-/287x66-grey.png" alt="Vertalingsstatus" />](https://hosted.weblate.org/engage/onvifviewer/?utm_source=widget)

## Building from source
It is also possible to build the application yourself. This requires Qt6, KDE Frameworks 6 (KF6), Kirigami and KDSoap to be installed.

### Dependencies

On Debian/Ubuntu based distributions you can install the build dependencies with:

    sudo apt install \
        build-essential cmake extra-cmake-modules gettext \
        qt6-base-dev qt6-declarative-dev qt6-svg-dev qt6-multimedia-dev \
        libkf6coreaddons-dev libkf6i18n-dev libkf6xmlgui-dev libkirigami-dev \
        libkdsoap-dev libkdsoapwsdiscoveryclient-dev

To run the application you also need these QML runtime modules and the icon theme:

    sudo apt install \
        qml6-module-org-kde-kirigami qml6-module-org-kde-desktop \
        qml6-module-qtquick-controls qml6-module-qtquick-layouts \
        qml6-module-qtquick-window qml6-module-qtquick-templates \
        qml6-module-qtqml-models qml6-module-qtmultimedia \
        breeze-icon-theme

On other distributions install the equivalent packages. The optional
`KDSoapWSDiscoveryClient` library enables automatic discovery of cameras on the
local network; if it is not available the rest of the application still builds.

### Build

Then build ONVIFViewer using CMake:

    git clone https://github.com/RomarioAndrade/onvifviewer.git
    mkdir build-onvifviewer
    cd build-onvifviewer
    cmake -DCMAKE_BUILD_TYPE=Release ../onvifviewer
    make
    cd ..

### Run

Run the freshly built binary directly:

    ./build-onvifviewer/bin/onvifviewer

### Install

Optionally install it system-wide:

    cd build-onvifviewer
    sudo make install
    cd ..

## Troubleshooting

### The app crashes (segfault) when viewing an H.265 camera

Some GPU/driver combinations crash inside the Qt FFmpeg backend when
hardware-accelerated H.265 (HEVC) decoding fails — it tries to map an invalid
GPU surface and segfaults. To avoid this, ONVIFViewer defaults to **software
decoding**.

If you know your GPU handles HEVC reliably and want hardware decoding back,
re-enable it by setting the environment variable to your device type (for
example `vaapi` or `vdpau`):

    QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi ./build-onvifviewer/bin/onvifviewer

### Stuttering, or green/grey blocks in the video

This is caused by packet loss on the RTSP stream, which corrupts the decoder's
reference frames (you will see `RTP: missed N packets` in the terminal). It is
most common with UDP transport. Open the camera's **Settings** and change
**Stream transport** to **TCP (RTSP)**, which retransmits lost packets. If the
camera does not honour that, try **RTSP over HTTP**.

## Attribution 
Google Play and the Google Play logo are trademarks of Google LLC.



