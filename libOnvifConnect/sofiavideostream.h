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

// Native XiongMai / "Sofia" (DVRIP) video stream over TCP 34567. Uses a
// dedicated connection: logs in, issues OPMonitor (Claim/Start), and
// reassembles the proprietary frame framing into a raw H.264/H.265 Annex-B
// elementary stream. Protocol reference: OpenIPC/python-dvr.
#ifndef SOFIAVIDEOSTREAM_H
#define SOFIAVIDEOSTREAM_H

#include <QObject>
#include <QAbstractSocket>

class QTcpSocket;

class SofiaVideoStream : public QObject
{
    Q_OBJECT
public:
    explicit SofiaVideoStream(QObject* parent = nullptr);
    ~SofiaVideoStream() override;

    void setHostname(const QString& hostname, quint16 port = 34567);
    void setCredentials(const QString& username, const QString& password);
    void setStream(const QString& streamType); // "Main" or "Extra1"
    QString stream() const { return m_streamType; }

    void start();
    void stop();

    QString codecName() const;    // "h264" / "h265" / "" (unknown yet)
    int frameWidth() const;
    int frameHeight() const;
    int fps() const;

signals:
    // A complete coded video access unit (Annex-B NAL data). isKeyFrame marks
    // I-frames, so a consumer can start muxing at a clean point.
    void videoFrame(const QByteArray& nal, bool isKeyFrame);
    void codecChanged(const QString& codecName);
    void errorOccurred(const QString& error);
    void stopped();

private slots:
    void onConnected();
    void onReadyRead();
    void onError(QAbstractSocket::SocketError error);

private:
    void sendCommand(quint16 msgId, const QByteArray& jsonPayload);
    void startMonitor();
    void feed(const QByteArray& packetPayload); // one msg-1412 payload
    void emitFrame();

    QTcpSocket* m_socket = nullptr;
    QString m_hostname;
    quint16 m_port = 34567;
    QString m_username = QStringLiteral("admin");
    QString m_password;
    QString m_streamType = QStringLiteral("Main");
    quint32 m_session = 0;
    quint32 m_sequence = 0;
    bool m_loggedIn = false;
    bool m_monitorStarted = false;
    QByteArray m_readBuffer;

    // Frame-reassembly state machine.
    qint64 m_frameRemaining = 0; // bytes still expected for the current frame
    bool m_frameIsVideo = false;
    bool m_frameIsKey = false;
    bool m_gotKeyFrame = false; // gate output until the first key frame
    QByteArray m_frameBuf;

    QString m_codec;
    int m_width = 0;
    int m_height = 0;
    int m_fps = 0;
};

#endif // SOFIAVIDEOSTREAM_H
