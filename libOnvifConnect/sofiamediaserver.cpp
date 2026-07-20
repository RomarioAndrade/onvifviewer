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
#include "sofiamediaserver.h"
#include "sofiavideostream.h"
#include "sofiaconnection.h"
#include "mpegtsmuxer.h"

#include <QTcpServer>
#include <QTcpSocket>
#include <QHostAddress>

SofiaMediaServer::SofiaMediaServer(QObject* parent) :
    QObject(parent),
    m_server(new QTcpServer(this)),
    m_stream(new SofiaVideoStream(this)),
    m_muxer(new MpegTsMuxer())
{
    connect(m_server, &QTcpServer::newConnection, this, &SofiaMediaServer::onNewConnection);
    connect(m_stream, &SofiaVideoStream::videoFrame, this, &SofiaMediaServer::onVideoFrame);
    connect(m_stream, &SofiaVideoStream::codecChanged, this, &SofiaMediaServer::onCodecChanged);
}

SofiaMediaServer::~SofiaMediaServer()
{
    delete m_muxer;
}

void SofiaMediaServer::setHostname(const QString& hostname, quint16 port)
{
    m_stream->setHostname(hostname, port);
}

void SofiaMediaServer::setCredentials(const QString& username, const QString& password)
{
    m_stream->setCredentials(username, password);
}

void SofiaMediaServer::setStream(const QString& streamType)
{
    const QString type = streamType.isEmpty() ? QStringLiteral("Main") : streamType;
    if (type == m_stream->stream()) {
        return;
    }
    m_stream->setStream(type);
    if (m_upstreamRunning) {
        // Live switch: reopen the upstream on the new stream and hold every
        // client to its next key frame (which also re-sends PAT/PMT). The PTS
        // keeps counting up so the TS timeline stays monotonic.
        m_stream->stop();
        m_ready.clear();
        m_stream->start();
    }
}

void SofiaMediaServer::setControlConnection(SofiaConnection* control)
{
    if (m_control) {
        disconnect(m_control, &SofiaConnection::snapshotReady,
                   this, &SofiaMediaServer::onSnapshotReady);
    }
    m_control = control;
    if (m_control) {
        connect(m_control, &SofiaConnection::snapshotReady,
                this, &SofiaMediaServer::onSnapshotReady);
    }
}

QString SofiaMediaServer::start()
{
    if (!m_server->isListening()) {
        // Loopback only, ephemeral port: this endpoint is private to this host.
        if (!m_server->listen(QHostAddress::LocalHost, 0)) {
            return QString();
        }
    }
    return url();
}

void SofiaMediaServer::stop()
{
    m_server->close();
    m_stream->stop();
    m_upstreamRunning = false;
    for (QTcpSocket* c : std::as_const(m_clients)) {
        c->disconnectFromHost();
    }
    for (QTcpSocket* c : std::as_const(m_snapshotClients)) {
        c->disconnectFromHost();
    }
    m_clients.clear();
    m_ready.clear();
    m_snapshotClients.clear();
}

QString SofiaMediaServer::url() const
{
    if (!m_server->isListening()) {
        return QString();
    }
    return QStringLiteral("http://127.0.0.1:%1/").arg(m_server->serverPort());
}

QString SofiaMediaServer::snapshotUrl() const
{
    const QString base = url();
    return base.isEmpty() ? QString() : base + QStringLiteral("snapshot.jpg");
}

void SofiaMediaServer::startUpstreamIfNeeded()
{
    if (!m_upstreamRunning) {
        m_muxer->reset();
        m_stream->start();
        m_upstreamRunning = true;
    }
}

void SofiaMediaServer::onNewConnection()
{
    while (QTcpSocket* client = m_server->nextPendingConnection()) {
        // Wait for the request line before routing: "/snapshot.jpg" is a still
        // image, anything else is the live MPEG-TS video.
        connect(client, &QTcpSocket::readyRead, this, &SofiaMediaServer::onClientReadyRead);
        connect(client, &QTcpSocket::disconnected, this, &SofiaMediaServer::onClientDisconnected);
    }
}

void SofiaMediaServer::onClientReadyRead()
{
    QTcpSocket* client = qobject_cast<QTcpSocket*>(sender());
    if (!client) {
        return;
    }
    const QByteArray head = client->peek(2048);
    const int eol = head.indexOf("\r\n");
    if (eol < 0) {
        return; // request line not complete yet
    }
    const QByteArray requestLine = head.left(eol);
    disconnect(client, &QTcpSocket::readyRead, this, &SofiaMediaServer::onClientReadyRead);
    client->readAll();

    if (requestLine.contains("/snapshot")) {
        if (m_control && m_control->isLoggedIn()) {
            m_snapshotClients.insert(client);
            m_control->requestSnapshot();
        } else {
            client->write("HTTP/1.0 503 Service Unavailable\r\n"
                          "Connection: close\r\n\r\n");
            client->disconnectFromHost();
        }
        return;
    }

    // Live video: reply with a never-ending MPEG-TS body.
    client->write("HTTP/1.0 200 OK\r\n"
                  "Content-Type: video/mp2t\r\n"
                  "Cache-Control: no-cache\r\n"
                  "Connection: close\r\n\r\n");
    m_clients.insert(client);
    startUpstreamIfNeeded();
}

void SofiaMediaServer::onSnapshotReady(const QByteArray& jpeg)
{
    if (m_snapshotClients.isEmpty() || jpeg.isEmpty()) {
        return;
    }
    const QByteArray resp = "HTTP/1.0 200 OK\r\n"
                            "Content-Type: image/jpeg\r\n"
                            "Content-Length: " + QByteArray::number(jpeg.size()) + "\r\n"
                            "Cache-Control: no-cache\r\n"
                            "Connection: close\r\n\r\n" + jpeg;
    for (QTcpSocket* c : std::as_const(m_snapshotClients)) {
        c->write(resp);
        c->disconnectFromHost();
    }
    m_snapshotClients.clear();
}

void SofiaMediaServer::onClientDisconnected()
{
    QTcpSocket* client = qobject_cast<QTcpSocket*>(sender());
    if (!client) {
        return;
    }
    m_clients.remove(client);
    m_ready.remove(client);
    m_snapshotClients.remove(client);
    client->deleteLater();
    if (m_clients.isEmpty()) {
        m_stream->stop();
        m_upstreamRunning = false;
    }
}

void SofiaMediaServer::onCodecChanged(const QString& codec)
{
    m_muxer->setCodec(codec);
}

void SofiaMediaServer::onVideoFrame(const QByteArray& nal, bool keyFrame)
{
    if (m_clients.isEmpty()) {
        return;
    }
    // Stamp each frame with its real arrival time (90 kHz units). The clock
    // keeps running across upstream restarts so the timeline stays monotonic.
    if (!m_clock.isValid()) {
        m_clock.start();
    }
    const quint64 pts = quint64(m_clock.elapsed()) * 90;

    if (keyFrame) {
        // A key frame is a clean entry point: (re)send PAT/PMT so late joiners
        // can start decoding, and promote them to "ready".
        const QByteArray pkt = m_muxer->patPmt() + m_muxer->muxAccessUnit(nal, true, pts);
        for (QTcpSocket* c : std::as_const(m_clients)) {
            c->write(pkt);
            m_ready.insert(c);
        }
    } else {
        const QByteArray pkt = m_muxer->muxAccessUnit(nal, false, pts);
        for (QTcpSocket* c : std::as_const(m_ready)) {
            c->write(pkt);
        }
    }
}
