/* Copyright (C) 2019 Casper Meijn <casper@meijn.net>
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
#include "onvifdevicediscover.h"

#include "sofiadiscovery.h"

#include <QHostAddress>

#ifdef WITH_KDSOAP_WSDISCOVERY_CLIENT
#include <KDSoapWSDiscoveryClient/WSDiscoveryClient>
#include <KDSoapWSDiscoveryClient/WSDiscoveryTargetService>
#include <KDSoapWSDiscoveryClient/WSDiscoveryProbeJob>
#include <QDebug>
#include <QSharedPointer>
#endif

OnvifDeviceDiscover::OnvifDeviceDiscover(QObject* parent) :
    QObject(parent)
{
    qRegisterMetaType<QObjectList> ("QObjectList");

#ifdef WITH_KDSOAP_WSDISCOVERY_CLIENT
    m_client = new WSDiscoveryClient(this);

    m_probeJob = new WSDiscoveryProbeJob(m_client);
    connect(m_probeJob, &WSDiscoveryProbeJob::matchReceived, this, &OnvifDeviceDiscover::matchReceived);
    KDQName type("tdn:NetworkVideoTransmitter");
    type.setNameSpace("http://www.onvif.org/ver10/network/wsdl");
    m_probeJob->addType(type);
#endif

    m_sofiaDiscovery = new SofiaDiscovery(this);
    connect(m_sofiaDiscovery, &SofiaDiscovery::deviceFound,
            this, &OnvifDeviceDiscover::sofiaDeviceFound);
}

bool OnvifDeviceDiscover::isAvailable()
{
    // Sofia/XMEye discovery only needs a UDP socket, so it always works.
    return true;
}

QObjectList OnvifDeviceDiscover::matchList() const
{
    QObjectList list;
    for (auto match : m_matchMap.values()) {
        list.append(match);
    }
    return list;
}

void OnvifDeviceDiscover::start()
{
#ifdef WITH_KDSOAP_WSDISCOVERY_CLIENT
    m_client->start();
    m_probeJob->start();
#endif
    m_sofiaDiscovery->start();
}

void OnvifDeviceDiscover::sofiaDeviceFound(const QString& mac, const QString& hostName,
                                           const QHostAddress& address, quint16 tcpPort)
{
    const QString endpoint = QStringLiteral("sofia:") + mac;
    OnvifDeviceDiscoverMatch* deviceMatch = m_matchMap.value(endpoint);
    const QString host = tcpPort == 34567
            ? address.toString()
            : QStringLiteral("%1:%2").arg(address.toString()).arg(tcpPort);
    const QString name = hostName.isEmpty() ? mac : hostName;
    if (deviceMatch != nullptr) {
        // Devices answer every periodic probe; only notify on changes.
        deviceMatch->m_lastSeen = QDateTime::currentDateTime();
        if (deviceMatch->m_name == name && deviceMatch->m_host == host) {
            return;
        }
    } else {
        deviceMatch = new OnvifDeviceDiscoverMatch();
    }
    deviceMatch->m_endpoint = endpoint;
    deviceMatch->m_deviceType = QStringLiteral("sofia");
    deviceMatch->m_name = name;
    deviceMatch->m_hardware = QStringLiteral("Sofia/XMEye");
    deviceMatch->m_host = host;
    deviceMatch->m_lastSeen = QDateTime::currentDateTime();

    m_matchMap.insert(endpoint, deviceMatch);
    emit matchListChanged(matchList());
}

void OnvifDeviceDiscover::matchReceived(const WSDiscoveryTargetService& matchedService)
{
#ifdef WITH_KDSOAP_WSDISCOVERY_CLIENT
    OnvifDeviceDiscoverMatch* deviceMatch = m_matchMap.value(matchedService.endpointReference());
    if (deviceMatch == nullptr) {
        deviceMatch = new OnvifDeviceDiscoverMatch();
    }
    deviceMatch->m_endpoint = matchedService.endpointReference();
    for (auto& scope : matchedService.scopeList()) {
        if (scope.scheme() == "onvif" &&
                scope.authority().toLower() == "www.onvif.org") {
            auto splitPath = scope.path().split("/", Qt::SkipEmptyParts);
            if (splitPath[0].toLower() == "name") {
                deviceMatch->m_name = splitPath[1];
            }
            if (splitPath[0].toLower() == "hardware") {
                deviceMatch->m_hardware = splitPath[1];
            }
        }
    }
    for (auto& xAddr : matchedService.xAddrList()) {
        deviceMatch->m_xAddr = xAddr;
    }
    deviceMatch->m_lastSeen = matchedService.lastSeen();

    m_matchMap.insert(deviceMatch->m_endpoint, deviceMatch);
    emit matchListChanged(matchList());
#endif
}

QString OnvifDeviceDiscoverMatch::getHardware() const
{
    return m_hardware;
}

QString OnvifDeviceDiscoverMatch::getEndpoint() const
{
    return m_endpoint;
}

QUrl OnvifDeviceDiscoverMatch::getXAddr() const
{
    return m_xAddr;
}

QString OnvifDeviceDiscoverMatch::getHost() const
{
    return m_host.isEmpty() ? m_xAddr.authority() : m_host;
}

QString OnvifDeviceDiscoverMatch::getDeviceType() const
{
    return m_deviceType;
}

QString OnvifDeviceDiscoverMatch::getName() const
{
    return m_name;
}
