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
#include "mpegtsmuxer.h"

static constexpr int TS_PACKET = 188;
static constexpr quint16 PMT_PID = 0x1000;
static constexpr quint16 VIDEO_PID = 0x0100;

static quint32 crc32Mpeg(const QByteArray& data)
{
    quint32 crc = 0xFFFFFFFFu;
    for (uchar b : data) {
        crc ^= static_cast<quint32>(b) << 24;
        for (int i = 0; i < 8; ++i) {
            crc = (crc & 0x80000000u) ? (crc << 1) ^ 0x04C11DB7u : (crc << 1);
        }
    }
    return crc;
}

// Wrap a PSI section (without pointer_field) into one 188-byte TS packet.
static QByteArray psiPacket(quint16 pid, quint8& cc, const QByteArray& section)
{
    QByteArray pkt;
    pkt.append(char(0x47));
    pkt.append(char(0x40 | ((pid >> 8) & 0x1F))); // payload_unit_start=1
    pkt.append(char(pid & 0xFF));
    pkt.append(char(0x10 | (cc & 0x0F)));         // payload only
    cc = (cc + 1) & 0x0F;
    pkt.append(char(0x00));                        // pointer_field
    pkt.append(section);
    while (pkt.size() < TS_PACKET) {
        pkt.append(char(0xFF));
    }
    return pkt;
}

static void finishSection(QByteArray& body)
{
    // body starts at table_id; patch the 12-bit section_length (bytes 1..2 low
    // nibble) = remaining length after those two bytes, including the CRC.
    const int sectionLength = body.size() - 3 + 4; // +4 for the CRC to append
    body[1] = char(0xB0 | ((sectionLength >> 8) & 0x0F));
    body[2] = char(sectionLength & 0xFF);
    const quint32 crc = crc32Mpeg(body);
    body.append(char((crc >> 24) & 0xFF));
    body.append(char((crc >> 16) & 0xFF));
    body.append(char((crc >> 8) & 0xFF));
    body.append(char(crc & 0xFF));
}

MpegTsMuxer::MpegTsMuxer(const QString& codec) { setCodec(codec); }

void MpegTsMuxer::setCodec(const QString& codec)
{
    m_streamType = (codec == QStringLiteral("h265") || codec == QStringLiteral("hevc"))
                       ? 0x24 : 0x1B;
}

void MpegTsMuxer::reset()
{
    m_ccPat = m_ccPmt = m_ccVideo = 0;
}

QByteArray MpegTsMuxer::buildPat()
{
    QByteArray s;
    s.append(char(0x00));                  // table_id (PAT)
    s.append(char(0xB0)).append(char(0x00)); // section_length placeholder
    s.append(char(0x00)).append(char(0x01)); // transport_stream_id
    s.append(char(0xC1));                  // version 0, current_next=1
    s.append(char(0x00));                  // section_number
    s.append(char(0x00));                  // last_section_number
    s.append(char(0x00)).append(char(0x01)); // program_number 1
    s.append(char(0xE0 | ((PMT_PID >> 8) & 0x1F)));
    s.append(char(PMT_PID & 0xFF));
    finishSection(s);
    return psiPacket(0x0000, m_ccPat, s);
}

QByteArray MpegTsMuxer::buildPmt()
{
    QByteArray s;
    s.append(char(0x02));                  // table_id (PMT)
    s.append(char(0xB0)).append(char(0x00)); // section_length placeholder
    s.append(char(0x00)).append(char(0x01)); // program_number 1
    s.append(char(0xC1));                  // version 0, current_next=1
    s.append(char(0x00));                  // section_number
    s.append(char(0x00));                  // last_section_number
    s.append(char(0xE0 | ((VIDEO_PID >> 8) & 0x1F)));
    s.append(char(VIDEO_PID & 0xFF));      // PCR_PID
    s.append(char(0xF0)).append(char(0x00)); // program_info_length 0
    s.append(char(m_streamType));          // stream_type
    s.append(char(0xE0 | ((VIDEO_PID >> 8) & 0x1F)));
    s.append(char(VIDEO_PID & 0xFF));      // elementary_PID
    s.append(char(0xF0)).append(char(0x00)); // ES_info_length 0
    finishSection(s);
    return psiPacket(PMT_PID, m_ccPmt, s);
}

QByteArray MpegTsMuxer::patPmt()
{
    return buildPat() + buildPmt();
}

// Encode a 33-bit timestamp (PTS) as the 5-byte PES field.
static void appendPts(QByteArray& out, quint64 pts)
{
    out.append(char(0x21 | ((pts >> 29) & 0x0E)));       // '0010' + PTS[32..30] + marker
    out.append(char((pts >> 22) & 0xFF));                // PTS[29..22]
    out.append(char(((pts >> 14) & 0xFE) | 0x01));       // PTS[21..15] + marker
    out.append(char((pts >> 7) & 0xFF));                 // PTS[14..7]
    out.append(char(((pts << 1) & 0xFE) | 0x01));        // PTS[6..0] + marker
}

void MpegTsMuxer::appendPacketised(QByteArray& out, const QByteArray& pes,
                                   bool withPcr, quint64 pcr90k)
{
    int offset = 0;
    bool first = true;
    while (offset < pes.size()) {
        const int remaining = pes.size() - offset;
        const bool needPcr = first && withPcr;

        QByteArray pkt;
        pkt.append(char(0x47));
        pkt.append(char((first ? 0x40 : 0x00) | ((VIDEO_PID >> 8) & 0x1F)));
        pkt.append(char(VIDEO_PID & 0xFF));

        if (!needPcr && remaining >= TS_PACKET - 4) {
            // Whole packet is payload (no adaptation field): 4 + 184 = 188.
            pkt.append(char(0x10 | (m_ccVideo & 0x0F)));
            m_ccVideo = (m_ccVideo + 1) & 0x0F;
            pkt.append(pes.mid(offset, TS_PACKET - 4));
            offset += TS_PACKET - 4;
        } else {
            // Adaptation field: carries the PCR (key frames) and/or the stuffing
            // that pads the final short packet. Layout: 4 header + 1 length byte
            // + (1 flags + pcr + stuffing) + payload = 188.
            const int pcrBytes = needPcr ? 6 : 0;
            const int maxPayload = (TS_PACKET - 4) - 2 - pcrBytes; // 1 len + 1 flags
            const int take = qMin(remaining, maxPayload);
            const int stuffing = maxPayload - take;

            pkt.append(char(0x30 | (m_ccVideo & 0x0F))); // adaptation + payload
            m_ccVideo = (m_ccVideo + 1) & 0x0F;
            pkt.append(char(1 + pcrBytes + stuffing));   // adaptation_field_length
            pkt.append(char(needPcr ? 0x10 : 0x00));     // flags (bit4 = PCR)
            if (needPcr) {
                const quint64 base = pcr90k;
                pkt.append(char((base >> 25) & 0xFF));
                pkt.append(char((base >> 17) & 0xFF));
                pkt.append(char((base >> 9) & 0xFF));
                pkt.append(char((base >> 1) & 0xFF));
                pkt.append(char(((base & 1) << 7) | 0x7E));
                pkt.append(char(0x00));
            }
            for (int i = 0; i < stuffing; ++i) {
                pkt.append(char(0xFF));
            }
            pkt.append(pes.mid(offset, take));
            offset += take;
        }
        first = false;
        out.append(pkt); // pkt.size() is always 188 here
    }
}

QByteArray MpegTsMuxer::muxAccessUnit(const QByteArray& accessUnit, bool keyFrame,
                                      quint64 pts90k)
{
    // Build the PES packet: header + PTS + the coded access unit.
    QByteArray pes;
    pes.append(char(0x00)).append(char(0x00)).append(char(0x01)); // start code
    pes.append(char(0xE0));                    // stream_id (video)
    pes.append(char(0x00)).append(char(0x00)); // PES_packet_length = 0 (unbounded)
    pes.append(char(0x80));                    // marker '10', no scrambling/flags
    pes.append(char(0x80));                    // PTS_DTS_flags = '10' (PTS only)
    pes.append(char(0x05));                    // PES_header_data_length
    appendPts(pes, pts90k);
    pes.append(accessUnit);

    QByteArray out;
    appendPacketised(out, pes, /*withPcr=*/keyFrame, pts90k);
    return out;
}
