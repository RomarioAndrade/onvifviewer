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

// Bridges a native Sofia video stream into the app's existing URL-based player:
// pulls H.264/H.265 access units from SofiaVideoStream, muxes them to MPEG-TS,
// and serves the result over a loopback HTTP endpoint. The Sofia device simply
// points its stream URL at url(), reusing the normal media pipeline. The
// upstream Sofia connection is opened on the first client and closed when the
// last one leaves; late joiners are held until the next key frame.
#ifndef SOFIAMEDIASERVER_H
#define SOFIAMEDIASERVER_H

#include <QElapsedTimer>
#include <QObject>
#include <QSet>

class QTcpServer;
class QTcpSocket;
class SofiaVideoStream;
class SofiaConnection;
class MpegTsMuxer;

class SofiaMediaServer : public QObject
{
    Q_OBJECT
public:
    explicit SofiaMediaServer(QObject* parent = nullptr);
    ~SofiaMediaServer() override;

    void setHostname(const QString& hostname, quint16 port = 34567);
    void setCredentials(const QString& username, const QString& password);
    void setStream(const QString& streamType);
    // Existing control connection used to fetch OPSNAP still images. Not owned.
    void setControlConnection(SofiaConnection* control);

    // Begin listening on loopback. Returns the local URL to feed the player, or
    // an empty string if it could not bind.
    QString start();
    void stop();
    QString url() const;          // http://127.0.0.1:PORT/  (MPEG-TS video)
    QString snapshotUrl() const;  // http://127.0.0.1:PORT/snapshot.jpg

private slots:
    void onNewConnection();
    void onClientReadyRead();
    void onClientDisconnected();
    void onVideoFrame(const QByteArray& nal, bool keyFrame);
    void onCodecChanged(const QString& codec);
    void onSnapshotReady(const QByteArray& jpeg);

private:
    void startUpstreamIfNeeded();

    QTcpServer* m_server = nullptr;
    SofiaVideoStream* m_stream = nullptr;
    MpegTsMuxer* m_muxer = nullptr;
    SofiaConnection* m_control = nullptr; // not owned; for OPSNAP snapshots
    QSet<QTcpSocket*> m_clients;   // all connected players
    QSet<QTcpSocket*> m_ready;     // players that have received a key frame
    QSet<QTcpSocket*> m_snapshotClients; // pending /snapshot.jpg requests
    // PTS comes from the arrival clock, not the camera's advertised fps: VBR
    // cameras lie about the rate, and a wrong PTS pace makes the player drift
    // (growing delay or constant rebuffering).
    QElapsedTimer m_clock;
    bool m_upstreamRunning = false;
};

#endif // SOFIAMEDIASERVER_H
