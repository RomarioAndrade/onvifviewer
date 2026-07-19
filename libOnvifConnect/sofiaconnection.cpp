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
#include "sofiaconnection.h"

#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTcpSocket>
#include <QTimer>
#include <QtEndian>
#include <QDebug>

// DVRIP message ids used by the control plane.
static constexpr quint16 MSG_LOGIN     = 1000;
static constexpr quint16 MSG_KEEPALIVE = 1006;
static constexpr quint16 MSG_PTZ       = 1400;
// Ret values that the firmware considers a success.
static bool isOkCode(int ret) { return ret == 100 || ret == 515; }

SofiaConnection::SofiaConnection(QObject* parent) :
    QObject(parent),
    m_socket(new QTcpSocket(this)),
    m_keepAliveTimer(new QTimer(this))
{
    connect(m_socket, &QTcpSocket::connected, this, &SofiaConnection::onConnected);
    connect(m_socket, &QTcpSocket::readyRead, this, &SofiaConnection::onReadyRead);
    connect(m_socket, &QTcpSocket::errorOccurred, this, &SofiaConnection::onSocketError);
    connect(m_socket, &QTcpSocket::disconnected, this, [this]() {
        m_loggedIn = false;
        m_keepAliveTimer->stop();
        emit disconnected();
    });

    // XM devices report an AliveInterval (~20s); ping at half that to stay logged in.
    m_keepAliveTimer->setInterval(10000);
    connect(m_keepAliveTimer, &QTimer::timeout, this, &SofiaConnection::sendKeepAlive);
}

SofiaConnection::~SofiaConnection() = default;

void SofiaConnection::setHostname(const QString& hostname, quint16 port)
{
    m_hostname = hostname;
    m_port = port;
}

void SofiaConnection::setCredentials(const QString& username, const QString& password)
{
    // XM devices default to the "admin" account; an empty username would be rejected.
    m_username = username.isEmpty() ? QStringLiteral("admin") : username;
    m_password = password;
}

bool SofiaConnection::isLoggedIn() const { return m_loggedIn; }
int SofiaConnection::channelCount() const { return m_channelCount; }
QString SofiaConnection::errorString() const { return m_errorString; }

void SofiaConnection::connectToDevice()
{
    disconnectFromDevice();
    m_readBuffer.clear();
    m_sequence = 0;
    m_session = 0;
    m_socket->connectToHost(m_hostname, m_port);
}

void SofiaConnection::disconnectFromDevice()
{
    m_keepAliveTimer->stop();
    m_loggedIn = false;
    if (m_socket->state() != QAbstractSocket::UnconnectedState) {
        m_socket->abort();
    }
}

QString SofiaConnection::sofiaHash(const QString& password)
{
    const QByteArray md5 =
        QCryptographicHash::hash(password.toUtf8(), QCryptographicHash::Md5);
    static const char alphabet[] =
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"; // 62 chars
    QString out;
    out.reserve(8);
    for (int i = 0; i < 16; i += 2) {
        const int n = (static_cast<quint8>(md5[i]) + static_cast<quint8>(md5[i + 1])) % 62;
        out.append(QLatin1Char(alphabet[n]));
    }
    return out;
}

QByteArray SofiaConnection::sessionHex() const
{
    return QByteArray("0x") + QByteArray::number(m_session, 16).rightJustified(8, '0').toUpper();
}

void SofiaConnection::sendCommand(quint16 msgId, const QByteArray& jsonPayload)
{
    // 20-byte DVRIP header (little-endian): 0xFF, version, 2 reserved,
    // session, sequence, total, current, msgId, dataLength. dataLength counts
    // the JSON plus the trailing "\n\0".
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

void SofiaConnection::onConnected()
{
    QJsonObject obj;
    obj.insert(QStringLiteral("EncryptType"), QStringLiteral("MD5"));
    obj.insert(QStringLiteral("LoginType"), QStringLiteral("DVRIP-Web"));
    obj.insert(QStringLiteral("UserName"), m_username);
    obj.insert(QStringLiteral("PassWord"), sofiaHash(m_password));
    sendCommand(MSG_LOGIN, QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

void SofiaConnection::onReadyRead()
{
    m_readBuffer.append(m_socket->readAll());
    // Drain as many complete packets as the buffer holds.
    while (m_readBuffer.size() >= 20) {
        const uchar* h = reinterpret_cast<const uchar*>(m_readBuffer.constData());
        if (h[0] != 0xFF) {
            // Out of sync; drop a byte and retry.
            m_readBuffer.remove(0, 1);
            continue;
        }
        const quint32 session = qFromLittleEndian<quint32>(h + 4);
        const quint16 msgId = qFromLittleEndian<quint16>(h + 14);
        const quint32 len = qFromLittleEndian<quint32>(h + 16);
        if (static_cast<quint32>(m_readBuffer.size()) < 20 + len) {
            break; // wait for the rest of the payload
        }
        const QByteArray payload = m_readBuffer.mid(20, len);
        m_readBuffer.remove(0, 20 + len);
        handlePacket(msgId, session, payload);
    }
}

void SofiaConnection::handlePacket(quint16 msgId, quint32 session, const QByteArray& payload)
{
    Q_UNUSED(msgId)
    // Control replies are JSON, null/newline terminated.
    const qsizetype nul = payload.indexOf('\x00');
    const QByteArray jsonBytes = nul >= 0 ? payload.left(nul) : payload;
    const QJsonObject obj = QJsonDocument::fromJson(jsonBytes).object();
    const int ret = obj.value(QStringLiteral("Ret")).toInt(-1);

    if (!m_loggedIn) {
        // The login reply carries the SessionID we must echo in later commands.
        const QString sid = obj.value(QStringLiteral("SessionID")).toString();
        if (!sid.isEmpty() && isOkCode(ret)) {
            bool ok = false;
            const QString hex = sid.startsWith(QStringLiteral("0x")) ? sid.mid(2) : sid;
            m_session = hex.toUInt(&ok, 16);
            if (!ok) {
                m_session = session;
            }
            m_channelCount = obj.value(QStringLiteral("ChannelNum")).toInt(1);
            m_loggedIn = true;
            m_keepAliveTimer->start();
            emit loggedIn();
            return;
        }
        if (ret != -1 && !isOkCode(ret)) {
            setErrorString(QStringLiteral("Sofia login failed (Ret %1)").arg(ret));
            emit loginFailed(ret);
            return;
        }
    }
    // PTZ / keepalive replies: nothing to do beyond surfacing errors.
    if (ret != -1 && !isOkCode(ret)) {
        setErrorString(QStringLiteral("Sofia command failed (Ret %1)").arg(ret));
    }
}

void SofiaConnection::sendKeepAlive()
{
    if (!m_loggedIn) {
        return;
    }
    QJsonObject obj;
    obj.insert(QStringLiteral("Name"), QStringLiteral("KeepAlive"));
    obj.insert(QStringLiteral("SessionID"), QString::fromLatin1(sessionHex()));
    sendCommand(MSG_KEEPALIVE, QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

void SofiaConnection::ptzStart(const QString& command, int step, int channel)
{
    // Preset 65535 starts a continuous move; ptzStop sends the same command
    // with Preset -1 to halt it. Using -1 to *start* is what silently no-ops
    // (the camera replies Ret 100 but never moves).
    sendPtz(command, step, 65535, channel);
}

void SofiaConnection::ptzStop(const QString& command, int channel)
{
    sendPtz(command, 5, -1, channel);
}

void SofiaConnection::sendPtz(const QString& command, int step, int preset, int channel)
{
    if (!m_loggedIn) {
        return;
    }
    QJsonObject aux;
    aux.insert(QStringLiteral("Number"), 0);
    aux.insert(QStringLiteral("Status"), QStringLiteral("On"));
    QJsonObject point;
    point.insert(QStringLiteral("bottom"), 0);
    point.insert(QStringLiteral("left"), 0);
    point.insert(QStringLiteral("right"), 0);
    point.insert(QStringLiteral("top"), 0);
    QJsonObject param;
    param.insert(QStringLiteral("AUX"), aux);
    param.insert(QStringLiteral("Channel"), channel);
    param.insert(QStringLiteral("MenuOpts"), QStringLiteral("Enter"));
    param.insert(QStringLiteral("POINT"), point);
    param.insert(QStringLiteral("Pattern"), QStringLiteral("SetBegin"));
    param.insert(QStringLiteral("Preset"), preset);
    param.insert(QStringLiteral("Step"), step);
    param.insert(QStringLiteral("Tour"), 0);
    QJsonObject ctrl;
    ctrl.insert(QStringLiteral("Command"), command);
    ctrl.insert(QStringLiteral("Parameter"), param);
    QJsonObject obj;
    obj.insert(QStringLiteral("Name"), QStringLiteral("OPPTZControl"));
    obj.insert(QStringLiteral("SessionID"), QString::fromLatin1(sessionHex()));
    obj.insert(QStringLiteral("OPPTZControl"), ctrl);
    sendCommand(MSG_PTZ, QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

void SofiaConnection::onSocketError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error)
    setErrorString(m_socket->errorString());
}

void SofiaConnection::setErrorString(const QString& error)
{
    if (m_errorString != error) {
        m_errorString = error;
        emit errorStringChanged(m_errorString);
    }
}
