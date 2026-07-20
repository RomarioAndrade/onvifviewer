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
#include "onvifrecorder.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>

OnvifRecorder::OnvifRecorder(QObject* parent) : QObject(parent)
{
}

OnvifRecorder::~OnvifRecorder()
{
    // Never leave an orphaned ffmpeg behind when the device/app goes away.
    if (m_process) {
        m_process->disconnect(this);
        if (m_process->state() != QProcess::NotRunning) {
            m_process->terminate();
            if (!m_process->waitForFinished(3000)) {
                m_process->kill();
                m_process->waitForFinished(1000);
            }
        }
    }
}

bool OnvifRecorder::isRecording() const
{
    return m_recording;
}

QString OnvifRecorder::outputFile() const
{
    return m_outputFile;
}

QString OnvifRecorder::errorString() const
{
    return m_errorString;
}

static QString sanitizeBaseName(const QString& name)
{
    QString base = name.trimmed();
    if (base.isEmpty()) {
        base = QStringLiteral("camera");
    }
    // Keep the filename portable: collapse anything but word chars, dot and dash.
    static const QRegularExpression unsafe(QStringLiteral("[^\\w.-]+"));
    base.replace(unsafe, QStringLiteral("_"));
    return base;
}

bool OnvifRecorder::start(const QUrl& streamUri, const QString& folder, const QString& baseName,
                          int segmentSeconds)
{
    if (m_recording) {
        return true;
    }
    setErrorString(QString());

    if (!streamUri.isValid() || streamUri.isEmpty()) {
        setErrorString(tr("No stream URL to record. Is the camera connected?"));
        return false;
    }

    const QString ffmpeg = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"));
    if (ffmpeg.isEmpty()) {
        setErrorString(tr("ffmpeg was not found. Install it to enable recording."));
        return false;
    }

    QString dirPath = folder;
    if (dirPath.isEmpty()) {
        dirPath = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
    }
    QDir dir(dirPath);
    if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
        setErrorString(tr("Cannot create the recording folder: %1").arg(dirPath));
        return false;
    }

    const QString stamp = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss"));
    const QString base = sanitizeBaseName(baseName);

    // Read the RTSP feed over TCP and copy every stream through untouched, so
    // any camera codec (H.264/H.265 video, AAC/G.711 audio) is captured without
    // re-encoding. Matroska stays playable even if the process is interrupted.
    QStringList args = QStringList()
        << QStringLiteral("-nostdin")
        << QStringLiteral("-loglevel") << QStringLiteral("error")
        << QStringLiteral("-rtsp_transport") << QStringLiteral("tcp")
        << QStringLiteral("-i") << streamUri.toString(QUrl::FullyEncoded)
        << QStringLiteral("-c") << QStringLiteral("copy");

    if (segmentSeconds > 0) {
        // Split into a numbered series sharing this session's timestamp prefix,
        // e.g. camera_20260720-103400_000.mkv, _001.mkv, … Each segment is a
        // self-contained Matroska file (reset_timestamps), so a long capture
        // stays manageable and survives a crash. Stream-copy can only cut on
        // keyframes, so a segment ends on the first keyframe after the interval
        // rather than exactly on it. Report the folder as the target since the
        // recording now spans many files.
        const QString pattern =
            dir.absoluteFilePath(QStringLiteral("%1_%2_%03d.mkv").arg(base, stamp));
        args << QStringLiteral("-f") << QStringLiteral("segment")
             << QStringLiteral("-segment_time") << QString::number(segmentSeconds)
             << QStringLiteral("-segment_format") << QStringLiteral("matroska")
             << QStringLiteral("-reset_timestamps") << QStringLiteral("1")
             << QStringLiteral("-y") << pattern;
        m_outputFile = dir.absolutePath();
    } else {
        m_outputFile = dir.absoluteFilePath(QStringLiteral("%1_%2.mkv").arg(base, stamp));
        args << QStringLiteral("-f") << QStringLiteral("matroska")
             << QStringLiteral("-y") << m_outputFile;
    }
    emit outputFileChanged(m_outputFile);

    m_stopRequested = false;
    m_process = new QProcess(this);

    connect(m_process, &QProcess::started, this, [this]() {
        setRecording(true);
    });
    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            setErrorString(tr("ffmpeg failed to start."));
        }
    });
    connect(m_process, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus status) {
        // A clean stop (we sent SIGTERM) makes ffmpeg exit non-zero, which is
        // expected; only surface an error when it died on its own.
        if (!m_stopRequested && !(status == QProcess::NormalExit && exitCode == 0)) {
            const QString details = QString::fromUtf8(m_process->readAllStandardError()).trimmed();
            setErrorString(details.isEmpty()
                           ? tr("Recording stopped unexpectedly.")
                           : tr("Recording stopped: %1").arg(details));
        }
        teardownProcess();
        setRecording(false);
    });

    m_process->start(ffmpeg, args);
    return true;
}

void OnvifRecorder::stop()
{
    if (!m_process || m_process->state() == QProcess::NotRunning) {
        return;
    }
    m_stopRequested = true;
    // SIGTERM makes ffmpeg write the file trailer and exit cleanly. Arm a
    // non-blocking fallback that hard-kills it if it ignores the signal; the
    // timer is bound to the process, so it is cancelled if the process is gone.
    QProcess* proc = m_process;
    proc->terminate();
    QTimer::singleShot(4000, proc, [proc]() {
        if (proc->state() != QProcess::NotRunning) {
            proc->kill();
        }
    });
}

void OnvifRecorder::teardownProcess()
{
    if (m_process) {
        m_process->deleteLater();
        m_process = nullptr;
    }
}

void OnvifRecorder::setErrorString(const QString& error)
{
    if (m_errorString != error) {
        m_errorString = error;
        emit errorStringChanged(m_errorString);
    }
    if (!error.isEmpty()) {
        qWarning() << "OnvifRecorder:" << error;
    }
}

void OnvifRecorder::setRecording(bool recording)
{
    if (m_recording != recording) {
        m_recording = recording;
        emit isRecordingChanged(m_recording);
    }
}
