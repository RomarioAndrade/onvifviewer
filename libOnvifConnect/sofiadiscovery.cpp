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
#include "sofiadiscovery.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkDatagram>
#include <QTimer>
#include <QUdpSocket>
#include <QtEndian>

namespace {
const quint16 discoveryPort = 34569;
const quint16 msgSearchReq = 1530;
const quint16 msgSearchResp = 1531;
const int headerSize = 20;
const int probeIntervalMs = 10000;
}

SofiaDiscovery::SofiaDiscovery(QObject* parent) :
    QObject(parent),
    m_socket(new QUdpSocket(this)),
    m_probeTimer(new QTimer(this))
{
    connect(m_socket, &QUdpSocket::readyRead,
            this, &SofiaDiscovery::onReadyRead);
    m_probeTimer->setInterval(probeIntervalMs);
    connect(m_probeTimer, &QTimer::timeout,
            this, &SofiaDiscovery::sendProbe);
}

void SofiaDiscovery::start()
{
    // Devices answer to port 34569 itself, so we must own that port.
    if (m_socket->state() != QAbstractSocket::BoundState &&
            !m_socket->bind(QHostAddress::AnyIPv4, discoveryPort,
                            QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint)) {
        qWarning("SofiaDiscovery: cannot bind UDP port %u: %s",
                 discoveryPort, qPrintable(m_socket->errorString()));
        return;
    }
    sendProbe();
    m_probeTimer->start();
}

void SofiaDiscovery::stop()
{
    m_probeTimer->stop();
    m_socket->close();
}

void SofiaDiscovery::sendProbe()
{
    // 20-byte DVRIP header with message id 1530 and no payload.
    QByteArray probe(headerSize, '\0');
    probe[0] = char(0xff);
    qToLittleEndian<quint16>(msgSearchReq, probe.data() + 14);
    m_socket->writeDatagram(probe, QHostAddress::Broadcast, discoveryPort);
}

void SofiaDiscovery::onReadyRead()
{
    while (m_socket->hasPendingDatagrams()) {
        const QNetworkDatagram datagram = m_socket->receiveDatagram();
        const QByteArray data = datagram.data();
        if (data.size() < headerSize || quint8(data.at(0)) != 0xff) {
            continue;
        }
        const quint16 msgId = qFromLittleEndian<quint16>(data.constData() + 14);
        const quint32 length = qFromLittleEndian<quint32>(data.constData() + 16);
        if (msgId != msgSearchResp || length == 0 ||
                data.size() < headerSize + int(length)) {
            continue;
        }
        QByteArray json = data.mid(headerSize, int(length));
        json.replace('\0', QByteArray());
        const QJsonObject reply = QJsonDocument::fromJson(json).object();
        const QJsonObject netCommon =
                reply.value(QLatin1String("NetWork.NetCommon")).toObject();
        const QString mac = netCommon.value(QLatin1String("MAC")).toString();
        if (mac.isEmpty()) {
            continue;
        }
        const QString hostName =
                netCommon.value(QLatin1String("HostName")).toString();
        // Prefer the address the reply actually came from over the announced
        // (possibly hex-encoded) HostIP.
        const quint16 tcpPort =
                quint16(netCommon.value(QLatin1String("TCPPort")).toInt(34567));
        emit deviceFound(mac, hostName, datagram.senderAddress(), tcpPort);
    }
}
