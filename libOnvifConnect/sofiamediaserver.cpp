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
    m_stream->setStream(streamType);
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
    m_clients.clear();
    m_ready.clear();
}

QString SofiaMediaServer::url() const
{
    if (!m_server->isListening()) {
        return QString();
    }
    return QStringLiteral("http://127.0.0.1:%1/").arg(m_server->serverPort());
}

void SofiaMediaServer::startUpstreamIfNeeded()
{
    if (!m_upstreamRunning) {
        m_pts = 0;
        m_muxer->reset();
        m_stream->start();
        m_upstreamRunning = true;
    }
}

void SofiaMediaServer::onNewConnection()
{
    while (QTcpSocket* client = m_server->nextPendingConnection()) {
        connect(client, &QTcpSocket::disconnected, this, &SofiaMediaServer::onClientDisconnected);
        // The player issues a GET; we don't need to parse it. Reply immediately
        // with a never-ending MPEG-TS body.
        client->write("HTTP/1.0 200 OK\r\n"
                      "Content-Type: video/mp2t\r\n"
                      "Cache-Control: no-cache\r\n"
                      "Connection: close\r\n\r\n");
        m_clients.insert(client);
        startUpstreamIfNeeded();
    }
}

void SofiaMediaServer::onClientDisconnected()
{
    QTcpSocket* client = qobject_cast<QTcpSocket*>(sender());
    if (!client) {
        return;
    }
    m_clients.remove(client);
    m_ready.remove(client);
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
    if (m_fps <= 0) {
        m_fps = 25;
    }
    const int streamFps = m_stream->fps();
    if (streamFps > 0) {
        m_fps = streamFps;
    }

    if (keyFrame) {
        // A key frame is a clean entry point: (re)send PAT/PMT so late joiners
        // can start decoding, and promote them to "ready".
        const QByteArray pkt = m_muxer->patPmt() + m_muxer->muxAccessUnit(nal, true, m_pts);
        for (QTcpSocket* c : std::as_const(m_clients)) {
            c->write(pkt);
            m_ready.insert(c);
        }
    } else {
        const QByteArray pkt = m_muxer->muxAccessUnit(nal, false, m_pts);
        for (QTcpSocket* c : std::as_const(m_ready)) {
            c->write(pkt);
        }
    }
    m_pts += 90000 / m_fps;
}
