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

// Native XiongMai / "Sofia" (DVRIP, TCP 34567) control connection. Speaks the
// proprietary NETsurveillance/XMeye protocol used by cameras that expose no
// (working) ONVIF. Protocol reverse-engineered with OpenIPC/python-dvr as the
// reference. This class covers the control plane (login, keep-alive, PTZ); the
// native video stream (OPMonitor) is handled separately.
#ifndef SOFIACONNECTION_H
#define SOFIACONNECTION_H

#include <QObject>
#include <QAbstractSocket>

class QTcpSocket;
class QTimer;

class SofiaConnection : public QObject
{
    Q_OBJECT
public:
    explicit SofiaConnection(QObject* parent = nullptr);
    ~SofiaConnection() override;

    void setHostname(const QString& hostname, quint16 port = 34567);
    void setCredentials(const QString& username, const QString& password);

    void connectToDevice();
    void disconnectFromDevice();

    bool isLoggedIn() const;
    int channelCount() const;
    QString errorString() const;

    // Native PTZ (OPPTZControl). command is e.g. "DirectionUp"/"DirectionDown"/
    // "DirectionLeft"/"DirectionRight"/"ZoomTile"/"ZoomWide". ptzStart begins a
    // continuous move; ptzStop ends it (same command, Step 0).
    void ptzStart(const QString& command, int step = 5, int channel = 0);
    void ptzStop(const QString& command, int channel = 0);

    // Request a still image (OPSNAP); the JPEG arrives via snapshotReady().
    void requestSnapshot(int channel = 0);

    // The Sofia password hash (MD5 folded into the XM 62-char alphabet).
    static QString sofiaHash(const QString& password);

signals:
    void loggedIn();
    void loginFailed(int ret);
    void snapshotReady(const QByteArray& jpeg);
    void disconnected();
    void errorStringChanged(const QString& errorString);

private slots:
    void onConnected();
    void onReadyRead();
    void onSocketError(QAbstractSocket::SocketError error);
    void sendKeepAlive();

private:
    void sendCommand(quint16 msgId, const QByteArray& jsonPayload);
    void sendPtz(const QString& command, int step, int preset, int channel);
    void handlePacket(quint16 msgId, quint32 session, const QByteArray& payload);
    QByteArray sessionHex() const;
    void setErrorString(const QString& error);

    QTcpSocket* m_socket = nullptr;
    QTimer* m_keepAliveTimer = nullptr;
    QString m_hostname;
    quint16 m_port = 34567;
    QString m_username = QStringLiteral("admin");
    QString m_password;
    quint32 m_session = 0;
    quint32 m_sequence = 0;
    int m_channelCount = 1;
    bool m_loggedIn = false;
    QByteArray m_readBuffer;
    QString m_errorString;
};

#endif // SOFIACONNECTION_H
