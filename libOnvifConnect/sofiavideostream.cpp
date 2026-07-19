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
#include "sofiavideostream.h"
#include "sofiaconnection.h"

#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTcpSocket>
#include <QtEndian>

static constexpr quint16 MSG_LOGIN       = 1000;
static constexpr quint16 MSG_OPMONITOR   = 1413; // OPMonitor "Claim" (set) opcode
static constexpr quint16 MSG_MONITOR_RUN = 1410; // OPMonitor "Start"
static constexpr quint16 MSG_VIDEO_DATA  = 1412; // binary A/V frames

// Frame-type markers at the start of each media frame (big-endian).
static constexpr quint32 FT_VIDEO_I = 0x000001FC;
static constexpr quint32 FT_VIDEO_P = 0x000001FD;
static constexpr quint32 FT_JPEG    = 0x000001FE;
static constexpr quint32 FT_AUDIO   = 0x000001FA;
static constexpr quint32 FT_INFO    = 0x000001F9;

SofiaVideoStream::SofiaVideoStream(QObject* parent) :
    QObject(parent),
    m_socket(new QTcpSocket(this))
{
    connect(m_socket, &QTcpSocket::connected, this, &SofiaVideoStream::onConnected);
    connect(m_socket, &QTcpSocket::readyRead, this, &SofiaVideoStream::onReadyRead);
    connect(m_socket, &QTcpSocket::errorOccurred, this, &SofiaVideoStream::onError);
}

SofiaVideoStream::~SofiaVideoStream() = default;

void SofiaVideoStream::setHostname(const QString& hostname, quint16 port)
{
    m_hostname = hostname;
    m_port = port;
}

void SofiaVideoStream::setCredentials(const QString& username, const QString& password)
{
    m_username = username.isEmpty() ? QStringLiteral("admin") : username;
    m_password = password;
}

void SofiaVideoStream::setStream(const QString& streamType)
{
    m_streamType = streamType.isEmpty() ? QStringLiteral("Main") : streamType;
}

QString SofiaVideoStream::codecName() const { return m_codec; }
int SofiaVideoStream::frameWidth() const { return m_width; }
int SofiaVideoStream::frameHeight() const { return m_height; }
int SofiaVideoStream::fps() const { return m_fps; }

void SofiaVideoStream::start()
{
    stop();
    m_readBuffer.clear();
    m_frameBuf.clear();
    m_frameRemaining = 0;
    m_gotKeyFrame = false;
    m_sequence = 0;
    m_session = 0;
    m_loggedIn = false;
    m_monitorStarted = false;
    m_socket->connectToHost(m_hostname, m_port);
}

void SofiaVideoStream::stop()
{
    if (m_socket->state() != QAbstractSocket::UnconnectedState) {
        m_socket->abort();
    }
    if (m_monitorStarted) {
        m_monitorStarted = false;
        emit stopped();
    }
}

void SofiaVideoStream::sendCommand(quint16 msgId, const QByteArray& jsonPayload)
{
    QByteArray pkt;
    pkt.resize(20);
    char* h = pkt.data();
    memset(h, 0, 20);
    h[0] = static_cast<char>(0xFF);
    qToLittleEndian<quint32>(m_session, h + 4);
    qToLittleEndian<quint32>(m_sequence, h + 8);
    qToLittleEndian<quint16>(msgId, h + 14);
    qToLittleEndian<quint32>(static_cast<quint32>(jsonPayload.size() + 2), h + 16);
    pkt.append(jsonPayload);
    pkt.append('\x0a');
    pkt.append('\x00');
    m_socket->write(pkt);
    m_sequence++;
}

void SofiaVideoStream::onConnected()
{
    QJsonObject obj;
    obj.insert(QStringLiteral("EncryptType"), QStringLiteral("MD5"));
    obj.insert(QStringLiteral("LoginType"), QStringLiteral("DVRIP-Web"));
    obj.insert(QStringLiteral("UserName"), m_username);
    obj.insert(QStringLiteral("PassWord"), SofiaConnection::sofiaHash(m_password));
    sendCommand(MSG_LOGIN, QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

static QJsonObject opMonitorBody(const QString& action, const QString& stream,
                                 quint32 session)
{
    QJsonObject params;
    params.insert(QStringLiteral("Channel"), 0);
    params.insert(QStringLiteral("CombinMode"), QStringLiteral("NONE"));
    params.insert(QStringLiteral("StreamType"), stream);
    params.insert(QStringLiteral("TransMode"), QStringLiteral("TCP"));
    QJsonObject mon;
    mon.insert(QStringLiteral("Action"), action);
    mon.insert(QStringLiteral("Parameter"), params);
    QJsonObject obj;
    obj.insert(QStringLiteral("Name"), QStringLiteral("OPMonitor"));
    obj.insert(QStringLiteral("SessionID"),
               QStringLiteral("0x%1").arg(session, 8, 16, QLatin1Char('0')).toUpper());
    obj.insert(QStringLiteral("OPMonitor"), mon);
    return obj;
}

void SofiaVideoStream::startMonitor()
{
    // Claim (opcode 1413) then Start (opcode 1410) — sending Start on 1410 while
    // the claim used 1410 is what a plain implementation gets wrong (Ret 103).
    sendCommand(MSG_OPMONITOR,
                QJsonDocument(opMonitorBody(QStringLiteral("Claim"), m_streamType, m_session))
                    .toJson(QJsonDocument::Compact));
    sendCommand(MSG_MONITOR_RUN,
                QJsonDocument(opMonitorBody(QStringLiteral("Start"), m_streamType, m_session))
                    .toJson(QJsonDocument::Compact));
    m_monitorStarted = true;
}

void SofiaVideoStream::onReadyRead()
{
    m_readBuffer.append(m_socket->readAll());
    while (m_readBuffer.size() >= 20) {
        const uchar* h = reinterpret_cast<const uchar*>(m_readBuffer.constData());
        if (h[0] != 0xFF) {
            m_readBuffer.remove(0, 1);
            continue;
        }
        const quint16 msgId = qFromLittleEndian<quint16>(h + 14);
        const quint32 len = qFromLittleEndian<quint32>(h + 16);
        if (static_cast<quint32>(m_readBuffer.size()) < 20 + len) {
            break;
        }
        const QByteArray payload = m_readBuffer.mid(20, len);
        m_readBuffer.remove(0, 20 + len);

        if (msgId == MSG_VIDEO_DATA) {
            feed(payload);
        } else if (!m_loggedIn) {
            const int nul = static_cast<int>(payload.indexOf('\x00'));
            const QJsonObject obj =
                QJsonDocument::fromJson(nul >= 0 ? payload.left(nul) : payload).object();
            const QString sid = obj.value(QStringLiteral("SessionID")).toString();
            const int ret = obj.value(QStringLiteral("Ret")).toInt(-1);
            if (!sid.isEmpty() && (ret == 100 || ret == 515)) {
                bool ok = false;
                const QString hex = sid.startsWith(QStringLiteral("0x")) ? sid.mid(2) : sid;
                m_session = hex.toUInt(&ok, 16);
                m_loggedIn = true;
                startMonitor();
            } else if (ret != -1 && ret != 100 && ret != 515) {
                emit errorOccurred(QStringLiteral("Sofia video login failed (Ret %1)").arg(ret));
            }
        }
        // Other control replies (claim/start acks) are ignored; data follows.
    }
}

void SofiaVideoStream::feed(const QByteArray& pkt)
{
    const uchar* p = reinterpret_cast<const uchar*>(pkt.constData());
    if (m_frameRemaining == 0) {
        // Start of a new media frame: read its type header.
        if (pkt.size() < 8) {
            return;
        }
        const quint32 dataType = qFromBigEndian<quint32>(p);
        qsizetype frameLen;
        qint64 length;
        m_frameIsVideo = false;
        m_frameIsKey = false;
        if (dataType == FT_VIDEO_I || dataType == FT_JPEG) {
            if (pkt.size() < 16) return;
            frameLen = 16;
            const quint8 media = p[4];
            m_fps = p[5];
            m_width = p[6] * 8;
            m_height = p[7] * 8;
            length = qFromLittleEndian<quint32>(p + 12);
            m_frameIsVideo = true;
            m_frameIsKey = (dataType == FT_VIDEO_I);
            const QString codec = media == 2 ? QStringLiteral("h264")
                                : media == 3 ? QStringLiteral("h265")
                                : media == 1 ? QStringLiteral("mpeg4")
                                             : QString();
            if (!codec.isEmpty() && codec != m_codec) {
                m_codec = codec;
                emit codecChanged(codec);
            }
        } else if (dataType == FT_VIDEO_P) {
            frameLen = 8;
            length = qFromLittleEndian<quint32>(p + 4);
            m_frameIsVideo = true;
        } else if (dataType == FT_AUDIO || dataType == FT_INFO) {
            frameLen = 8;
            length = qFromLittleEndian<quint16>(p + 6);
        } else {
            // Unknown/desync — drop this packet and wait for the next frame start.
            return;
        }
        const QByteArray body = pkt.mid(frameLen);
        if (m_frameIsVideo) {
            m_frameBuf.append(body);
        }
        m_frameRemaining = length - body.size();
    } else {
        // Continuation packet of the current frame.
        if (m_frameIsVideo) {
            m_frameBuf.append(pkt);
        }
        m_frameRemaining -= pkt.size();
    }

    if (m_frameRemaining <= 0) {
        if (m_frameIsVideo && !m_frameBuf.isEmpty()) {
            // A decoder must start at a key frame (SPS/PPS + IDR); drop leading
            // P-frames until the first one arrives so the output is clean.
            if (m_frameIsKey) {
                m_gotKeyFrame = true;
            }
            if (m_gotKeyFrame) {
                emitFrame();
            }
        }
        m_frameBuf.clear();
        m_frameRemaining = 0;
        m_frameIsVideo = false;
    }
}

void SofiaVideoStream::emitFrame()
{
    emit videoFrame(m_frameBuf, m_frameIsKey);
}

void SofiaVideoStream::onError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error)
    emit errorOccurred(m_socket->errorString());
}
