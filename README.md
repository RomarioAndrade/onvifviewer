<!--
Copyright (C) 2019 Casper Meijn <casper@meijn.net>

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ONVIFViewer

**ONVIF camera viewer for Plasma Mobile and Linux desktop**

The goal of this project is to replace the proprietary app that was needed to configure and view my IP camera. The ONVIF protocol can be used to view and configure many types of camera's and is a open standard that can be implemented using standard SOAP libraries. Using Qt6 for the back-end and Kirigami UI framework makes this application a cross-platform solution. The primary focus is Plasma mobile and the Linux desktop, but an Android build is also available. 

This project was started as part of the [ONVIF Open Source Spotlight Challange](https://onvif-spotlight.bemyapp.com/#/projects/5ae0bbf7f98fde00047f0605) and the application finished in [fourth place](https://www.onvif.org/blog/2018/07/onvif-challenge-announces-top-10/) (out of 37 submissions). 
Before this project started, there was no open-source application for viewing ONVIF cameras for Plasma Mobile and Linux desktop. Neither is there a simple to use open-source C++ library to communicate with ONVIF cameras. The communication with the camera is implemented from scratch (using KDSoap) and modular designed, so that it can be separated into a reusable library at a later stage.


## Current state

I stopped development on this project. I was fun to create this application, but I don't have a usecase for my camera anymore. Therefore I have lost interest in adding new features. 

I also found out that most bugs reported are from cameras that don't comply to the ONVIF specification. As I don't have such camera available it is not possible to fix that issue. This left multiple issue unsolved. This is not motivating me.

Also I had difficulties releasing this as full free software, because of the non-free license of the ONVIF specification itself. 

Feel free to send in merge request for your own developments.

## Flatpak
On most Linux desktops you can install the application using Flatpak. 

1) First install Flatpak itself using the instructions on their [website](https://www.flatpak.org/setup/).
2) Then you can install the application from the [ONVIFViewer flathub page](https://flathub.org/apps/details/net.meijn.onvifviewer).

[<img width='240' alt='Download on Flathub' src='https://flathub.org/assets/badges/flathub-badge-en.png'/>](https://flathub.org/apps/details/net.meijn.onvifviewer)
      
## Translations
You can help translating this application using [Weblate](https://hosted.weblate.org/engage/onvifviewer/). You can login on the website and translate the texts to your language. The translations will be included in the next release.

[<img src="https://hosted.weblate.org/widgets/onvifviewer/-/287x66-grey.png" alt="Vertalingsstatus" />](https://hosted.weblate.org/engage/onvifviewer/?utm_source=widget)

## Donations
You can donate via Bitcoin at [15PerwiiGxPf27AxVTYq7hGYJ52WfM9EWo](bitcoin:15PerwiiGxPf27AxVTYq7hGYJ52WfM9EWo).

You can donate via PayPal via: [<img src="https://www.paypalobjects.com/nl_NL/NL/i/btn/btn_donateCC_LG.gif" alt="Donate" />](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=RNGGP3C6J84QU)

You can donate via LiberaPay via: [<img alt="Donate using Liberapay" src="https://liberapay.com/assets/widgets/donate.svg" />](https://liberapay.com/caspermeijn/donate)

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

    git clone https://gitlab.com/caspermeijn/onvifviewer.git
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

### Build artifacts ended up in the source tree

Always build **out of source** (into a separate directory such as
`build-onvifviewer`), as shown above. If you accidentally ran `cmake` from the
project root, review what would be removed first (dry run), then delete it —
keeping your build directory:

    git clean -ndx -e build-onvifviewer    # preview only
    git clean -fdx -e build-onvifviewer    # actually remove

## Attribution 
Google Play and the Google Play logo are trademarks of Google LLC.



