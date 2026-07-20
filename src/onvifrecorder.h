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
#ifndef ONVIFRECORDER_H
#define ONVIFRECORDER_H

#include <QObject>
#include <QString>
#include <QUrl>

class QProcess;

// Records an ONVIF RTSP stream to a file by driving an `ffmpeg` subprocess in
// stream-copy mode (no re-encode): it captures exactly what the camera sends,
// video and audio, independent of what the live preview is doing. This is the
// ONVIF path only; Sofia cameras have their own (video-only) local pipeline.
class OnvifRecorder : public QObject
{
    Q_OBJECT
public:
    explicit OnvifRecorder(QObject* parent = nullptr);
    ~OnvifRecorder() override;

    bool isRecording() const;
    QString outputFile() const;
    QString errorString() const;

    // Spawns ffmpeg to copy `streamUri` into `folder`/`baseName`_<timestamp>.mkv.
    // Returns false (and sets errorString) on an immediate failure: no ffmpeg on
    // PATH, an empty/invalid URI, or an unwritable folder. A successful start is
    // confirmed asynchronously through isRecordingChanged.
    bool start(const QUrl& streamUri, const QString& folder, const QString& baseName);
    void stop();

signals:
    void isRecordingChanged(bool isRecording);
    void outputFileChanged(const QString& outputFile);
    void errorStringChanged(const QString& errorString);

private:
    void setErrorString(const QString& error);
    void setRecording(bool recording);
    void teardownProcess();

    QProcess* m_process = nullptr;
    QString m_outputFile;
    QString m_errorString;
    bool m_recording = false;
    bool m_stopRequested = false;
};

#endif // ONVIFRECORDER_H
