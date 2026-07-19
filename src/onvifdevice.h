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
#ifndef ONVIFDEVICE_H
#define ONVIFDEVICE_H

#include "onvifdeviceconnection.h"
#include "onvifmediaprofile.h"
#include "onvifdeviceinformation.h"
#include "onvifsnapshotdownloader.h"
#include <QTimer>
#include <QObject>
#include <QUrl>
#include <QVariantList>

class SofiaConnection;
class SofiaMediaServer;

class OnvifDevice : public QObject
{
    Q_OBJECT
    // "onvif" (default) or "sofia" — selects the camera backend. Sofia is the
    // native XiongMai/DVRIP protocol for cameras with no working ONVIF.
    Q_PROPERTY(QString deviceType READ deviceType WRITE setDeviceType NOTIFY deviceTypeChanged)
    Q_PROPERTY(QString deviceName READ deviceName WRITE setDeviceName NOTIFY deviceNameChanged)
    Q_PROPERTY(QString hostName READ hostName WRITE setHostName NOTIFY hostNameChanged)
    Q_PROPERTY(QString userName READ userName WRITE setUserName NOTIFY userNameChanged)
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY passwordChanged)
    Q_PROPERTY(bool preferContinuousMove READ preferContinuousMove WRITE setPreferContinuousMove NOTIFY preferContinuousMoveChanged)
    Q_PROPERTY(QString preferredVideoStreamProtocol READ preferredVideoStreamProtocol WRITE setPreferredVideoStreamProtocol NOTIFY preferredVideoStreamProtocolChanged)
    Q_PROPERTY(QString manualStreamUri READ manualStreamUri WRITE setManualStreamUri NOTIFY manualStreamUriChanged)
    Q_PROPERTY(bool showInMosaic READ showInMosaic WRITE setShowInMosaic NOTIFY showInMosaicChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)
    Q_PROPERTY(OnvifDeviceInformation* deviceInformation READ deviceInformation NOTIFY deviceInformationChanged)
    Q_PROPERTY(bool supportsSnapshotUri READ supportsSnapshotUri NOTIFY supportsSnapshotUriChanged)
    Q_PROPERTY(QUrl snapshotUri READ snapshotUri NOTIFY snapshotUriChanged)
    Q_PROPERTY(QUrl streamUri READ streamUri NOTIFY streamUriChanged)
    Q_PROPERTY(bool isPanTiltSupported READ isPanTiltSupported NOTIFY ptzCapabilitiesChanged)
    Q_PROPERTY(bool isPtzHomeSupported READ isPtzHomeSupported NOTIFY ptzCapabilitiesChanged)
    Q_PROPERTY(bool isZoomSupported READ isZoomSupported NOTIFY ptzCapabilitiesChanged)
    Q_PROPERTY(OnvifSnapshotDownloader* snapshotDownloader READ snapshotDownloader NOTIFY snapshotDownloaderChanged)
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(QString selectedProfileToken READ selectedProfileToken WRITE setSelectedProfileToken NOTIFY selectedProfileTokenChanged)
public:
    explicit OnvifDevice(QObject* parent = nullptr);

    Q_INVOKABLE void connectToDevice();
    Q_INVOKABLE void reconnectToDevice();

    QString deviceType() const;
    void setDeviceType(const QString& deviceType);

    OnvifDeviceInformation* deviceInformation() const;
    OnvifSnapshotDownloader* snapshotDownloader() const;
    bool supportsSnapshotUri() const;
    QUrl snapshotUri() const;
    QUrl streamUri() const;
    QString errorString() const;

    QString deviceName() const;
    void setDeviceName(const QString& deviceName);

    QString hostName() const;
    void setHostName(const QString& hostName);

    QString userName() const;
    void setUserName(const QString& userName);

    QString password() const;
    void setPassword(const QString& password);

    bool isPanTiltSupported() const;
    bool isPtzHomeSupported() const;
    bool isZoomSupported() const;

    bool preferContinuousMove() const;
    void setPreferContinuousMove(bool preferContinuousMove);

    QString preferredVideoStreamProtocol() const;
    void setPreferredVideoStreamProtocol(const QString& preferredVideoStreamProtocol);

    QString manualStreamUri() const;
    void setManualStreamUri(const QString& manualStreamUri);

    bool showInMosaic() const;
    void setShowInMosaic(bool showInMosaic);

    QVariantList profiles() const;
    QString selectedProfileToken() const;
    void setSelectedProfileToken(const QString& token);

    void initByUrl(const QUrl& url);

signals:
    void deviceTypeChanged(const QString& deviceType);
    void deviceNameChanged(const QString& deviceName);
    void hostNameChanged(const QString& hostName);
    void userNameChanged(const QString& userName);
    void passwordChanged(const QString& password);
    void preferContinuousMoveChanged(bool preferContinuousMove);
    void preferredVideoStreamProtocolChanged(const QString& preferredVideoStreamProtocol);
    void manualStreamUriChanged(const QString& manualStreamUri);
    void showInMosaicChanged(bool showInMosaic);
    void errorStringChanged(const QString& errorString);
    void deviceInformationChanged(OnvifDeviceInformation* deviceInformation);
    void supportsSnapshotUriChanged(bool supportsSnapshotUri);
    void snapshotUriChanged(const QUrl& url);
    void streamUriChanged(const QUrl& url);
    void snapshotDownloaderChanged(OnvifSnapshotDownloader* snapshotDownloader);
    void ptzCapabilitiesChanged();
    void profilesChanged();
    void selectedProfileTokenChanged(const QString& token);

public slots:
    void ptzUp();
    void ptzDown();
    void ptzLeft();
    void ptzRight();
    void ptzMove(float xFraction, float yFraction);
    void ptzStartMove(float xFraction, float yFraction);
    void ptzStartZoom(float direction);
    void ptzHome();
    void ptzSaveHomePosition();
    void ptzStop();
    void ptzZoomIn();
    void ptzZoomOut();

private slots:
    void servicesAvailable();
    void deviceInformationAvailable(const OnvifDeviceInformation& deviceInformation);
    void profileListAvailable(const QList<OnvifMediaProfile>& profileList);

private:
    bool isSofia() const { return m_deviceType == QLatin1String("sofia"); }
    void ensureSofia();
    void sofiaPtz(const QString& command, bool hold = false);

    OnvifDeviceConnection m_connection;
    QString m_deviceType = QStringLiteral("onvif");
    SofiaConnection* m_sofia = nullptr;       // native PTZ/control (lazy)
    SofiaMediaServer* m_sofiaMedia = nullptr; // native video → local HTTP (lazy)
    QString m_sofiaLastPtz;                    // command to send Stop for
    bool m_ptzActive = false;                  // a continuous move needs a Stop
    QString m_deviceName;
    QString m_hostName;
    QString m_userName;
    QString m_password;
    bool m_preferContinuousMove;
    QString m_preferredVideoStreamProtocol;
    QString m_manualStreamUri;
    bool m_showInMosaic = false;
    QList<OnvifMediaProfile> m_profileList;
    QString m_preferredProfileToken;
    OnvifMediaProfile m_selectedMediaProfile;

    void applyProfile(const OnvifMediaProfile& profile);
    OnvifDeviceInformation* m_cachedDeviceInformation;
    QTimer m_ptzStopTimer;
    OnvifSnapshotDownloader* m_cachedSnapshotDownloader;
};

#endif // ONVIFDEVICE_H
