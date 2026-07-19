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

// Minimal MPEG-TS muxer for a single H.264/H.265 video track. Wraps coded
// access units (Annex-B) into 188-byte TS packets with PAT/PMT and PES + PTS,
// so a raw elementary stream (e.g. from SofiaVideoStream) can be served as a
// self-describing MPEG-TS a standard FFmpeg-based player will accept.
#ifndef MPEGTSMUXER_H
#define MPEGTSMUXER_H

#include <QByteArray>
#include <QString>

class MpegTsMuxer
{
public:
    explicit MpegTsMuxer(const QString& codec = QStringLiteral("h264"));

    void setCodec(const QString& codec); // "h264" or "h265"
    void reset();

    // PAT + PMT packets; emit at stream start and periodically (each key frame).
    QByteArray patPmt();
    // TS packets for one access unit at the given 90 kHz presentation timestamp.
    QByteArray muxAccessUnit(const QByteArray& accessUnit, bool keyFrame, quint64 pts90k);

private:
    QByteArray buildPat();
    QByteArray buildPmt();
    void appendPacketised(QByteArray& out, const QByteArray& pes, bool withPcr, quint64 pcr90k);

    quint8 m_streamType = 0x1B; // 0x1B = H.264, 0x24 = H.265
    quint8 m_ccPat = 0;
    quint8 m_ccPmt = 0;
    quint8 m_ccVideo = 0;
    quint8 m_patVersion = 0;
};

#endif // MPEGTSMUXER_H
