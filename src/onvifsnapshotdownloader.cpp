/* Copyright (C) 2018 Casper Meijn <casper@meijn.net>
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
#include "onvifsnapshotdownloader.h"

#include <QAuthenticator>
#include <QNetworkRequest>

OnvifSnapshotDownloader::OnvifSnapshotDownloader(QObject* parent) : QObject(parent)
{
    m_downloadTimer.setInterval(1000);
    m_downloadTimer.setSingleShot(true);
    connect(&m_downloadTimer, &QTimer::timeout, this, &OnvifSnapshotDownloader::startDownload);
    connect(&m_networkAccessManager, &QNetworkAccessManager::finished, this, &OnvifSnapshotDownloader::networkRequestFinished);
    connect(&m_networkAccessManager, &QNetworkAccessManager::authenticationRequired, this, &OnvifSnapshotDownloader::provideAuthentication);
}

void OnvifSnapshotDownloader::setCredentials(const QString& userName, const QString& password)
{
    m_userName = userName;
    m_password = password;
}

void OnvifSnapshotDownloader::setSnapshotUri(const QUrl& snapshotUri)
{
    m_snapshotUri = snapshotUri;
    startDownload();
}

void OnvifSnapshotDownloader::startDownload()
{
    if (m_snapshotUri.isEmpty()) {
        return;
    }
    if (m_networkReply) {
        m_networkReply->abort();
    }
    QNetworkRequest request(m_snapshotUri);
    // Don't let a stalled camera keep the request (and the "Loading…" state) open forever.
    request.setTransferTimeout(10000);
    m_networkReply = m_networkAccessManager.get(request);
}

void OnvifSnapshotDownloader::provideAuthentication(QNetworkReply* reply, QAuthenticator* authenticator)
{
    // The snapshot endpoint often demands HTTP Basic/Digest authentication.
    // Qt handles the challenge scheme; we only need to supply the credentials.
    // Only answer once per reply, otherwise wrong credentials would loop forever
    // instead of failing with AuthenticationRequiredError.
    if (reply->property("authenticationTried").toBool()) {
        return;
    }
    reply->setProperty("authenticationTried", true);

    QString userName = m_userName;
    QString password = m_password;
    // Fall back to credentials embedded in the snapshot URL, if any.
    if (userName.isEmpty() && !m_snapshotUri.userName().isEmpty()) {
        userName = m_snapshotUri.userName();
        password = m_snapshotUri.password();
    }
    if (userName.isEmpty()) {
        return;
    }
    authenticator->setUser(userName);
    authenticator->setPassword(password);
}

void OnvifSnapshotDownloader::networkRequestFinished(QNetworkReply* reply)
{
    //TODO: detect abort
    if (reply->error() == QNetworkReply::NoError) {
        auto downloadedData = reply->readAll();
        bool result = m_snapshot.loadFromData(downloadedData);
        if (!result) {
            setError("Failed to load snapshot");
        } else {
            setError(QString());
        }
        emit snapshotChanged(m_snapshot);
    } else {
        setError(reply->errorString());
    }
    reply->deleteLater();
    m_downloadTimer.start();
}

QString OnvifSnapshotDownloader::error() const
{
    return m_error;
}

void OnvifSnapshotDownloader::setInterval(QObject* key, int interval)
{
    if (interval != -1) {
        m_intervalMap.insert(key, interval);
    } else {
        m_intervalMap.remove(key);
    }
    int minInterval = std::numeric_limits<int>::max();
    for (auto interval : qAsConst(m_intervalMap)) {
        minInterval = qMin(interval, minInterval);
    }
    if (m_downloadTimer.interval() != minInterval) {
        m_downloadTimer.setInterval(minInterval);
    }
}

void OnvifSnapshotDownloader::setError(const QString& error)
{
    if (m_error == error) {
        return;
    }
    m_error = error;
    emit errorChanged(m_error);
}

QPixmap OnvifSnapshotDownloader::snapshot() const
{
    return m_snapshot;
}
