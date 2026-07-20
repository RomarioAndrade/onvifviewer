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

// LAN discovery of XiongMai / "Sofia" (DVRIP) devices: a UDP broadcast to
// port 34569 with message id 1530; each device answers with message id 1531
// carrying a JSON "NetWork.NetCommon" object (HostName, MAC, TCPPort, ...).
// Reference: OpenIPC/python-dvr DeviceManager.SearchXM.
#ifndef SOFIADISCOVERY_H
#define SOFIADISCOVERY_H

#include <QHostAddress>
#include <QObject>

class QTimer;
class QUdpSocket;

class SofiaDiscovery : public QObject
{
    Q_OBJECT
public:
    explicit SofiaDiscovery(QObject* parent = nullptr);

    // Sends a probe immediately and then keeps probing periodically.
    void start();
    void stop();

signals:
    void deviceFound(const QString& mac, const QString& hostName,
                     const QHostAddress& address, quint16 tcpPort);

private slots:
    void sendProbe();
    void onReadyRead();

private:
    QUdpSocket* m_socket = nullptr;
    QTimer* m_probeTimer = nullptr;
};

#endif // SOFIADISCOVERY_H
