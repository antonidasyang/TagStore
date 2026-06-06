#include "Updater.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QSettings>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QCryptographicHash>
#include <QProcess>
#include <QDesktopServices>
#include <QUrl>
#include <QDebug>

namespace {
// Default location of the update manifest + packages: a public MinIO bucket.
// Overridable via QSettings("TagStore","TagStore") key "update/baseUrl" so the
// endpoint can be changed without recompiling.
const QString kDefaultBaseUrl = QStringLiteral("https://oss.d2ssoft.com/tagstore-updates/");
}

Updater::Updater(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    QSettings settings("TagStore", "TagStore");
    m_baseUrl = settings.value("update/baseUrl", kDefaultBaseUrl).toString();
    if (!m_baseUrl.endsWith('/'))
        m_baseUrl += '/';
}

Updater::~Updater() = default;

QString Updater::currentVersion() const
{
#ifdef APP_VERSION
    return QStringLiteral(APP_VERSION);
#else
    return QCoreApplication::applicationVersion();
#endif
}

int Updater::compareVersions(const QString &a, const QString &b)
{
    const QStringList pa = a.split('.', Qt::SkipEmptyParts);
    const QStringList pb = b.split('.', Qt::SkipEmptyParts);
    const int n = qMax(pa.size(), pb.size());
    for (int i = 0; i < n; ++i) {
        const int va = i < pa.size() ? pa.at(i).toInt() : 0;
        const int vb = i < pb.size() ? pb.at(i).toInt() : 0;
        if (va != vb)
            return va < vb ? -1 : 1;
    }
    return 0;
}

QString Updater::platformKey() const
{
#if defined(Q_OS_WIN)
    return QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    return QStringLiteral("macos");
#else
    return QStringLiteral("linux");
#endif
}

QString Updater::statusKey() const
{
    switch (m_state) {
    case Checking:       return QStringLiteral("checking");
    case UpToDate:       return QStringLiteral("uptodate");
    case Available:      return QStringLiteral("available");
    case Downloading:    return QStringLiteral("downloading");
    case ReadyToInstall: return QStringLiteral("installing");
    case Error:          return QStringLiteral("error");
    case Idle:
    default:             return QStringLiteral("idle");
    }
}

void Updater::setState(State s)
{
    if (m_state == s)
        return;
    m_state = s;
    emit stateChanged();
}

void Updater::fail(const QString &message)
{
    m_errorString = message;
    qWarning() << "[Updater]" << message;
    setState(Error);
}

void Updater::cancel()
{
    if (m_reply) {
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }
    m_progress = 0.0;
    emit progressChanged();
    setState(Idle);
}

void Updater::checkForUpdates(bool silent)
{
    if (m_state == Checking || m_state == Downloading)
        return;

    m_silent = silent;
    m_errorString.clear();
    setState(Checking);

    QNetworkRequest req{QUrl(m_baseUrl + "latest.json")};
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    // Bypass any caching proxy so we always see the freshest manifest.
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                     QNetworkRequest::AlwaysNetwork);

    m_reply = m_nam->get(req);
    connect(m_reply, &QNetworkReply::finished, this, [this]() {
        QNetworkReply *reply = m_reply;
        m_reply = nullptr;
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            if (m_silent) {
                qWarning() << "[Updater] silent check failed:" << reply->errorString();
                setState(Idle);
            } else {
                fail(tr("Could not reach the update server: %1").arg(reply->errorString()));
            }
            return;
        }

        const QByteArray body = reply->readAll();
        QJsonParseError perr;
        const QJsonDocument doc = QJsonDocument::fromJson(body, &perr);
        if (perr.error != QJsonParseError::NoError || !doc.isObject()) {
            if (m_silent) { setState(Idle); return; }
            fail(tr("The update manifest is invalid."));
            return;
        }

        const QJsonObject root = doc.object();
        m_latestVersion = root.value("version").toString();
        m_releaseNotes = root.value("notes").toString();

        const QJsonObject platforms = root.value("platforms").toObject();
        const QJsonObject p = platforms.value(platformKey()).toObject();
        m_downloadUrl = p.value("url").toString();
        m_sha256 = p.value("sha256").toString().trimmed().toLower();

        if (m_latestVersion.isEmpty()) {
            if (m_silent) { setState(Idle); return; }
            fail(tr("The update manifest is missing a version."));
            return;
        }

        const bool newer = compareVersions(currentVersion(), m_latestVersion) < 0;
        if (newer && !m_downloadUrl.isEmpty()) {
            setState(Available);
            emit updateFound();
        } else {
            // Either up to date, or no package built for this platform yet.
            setState(UpToDate);
        }
    });
}

void Updater::downloadAndInstall()
{
    if (m_downloadUrl.isEmpty()) {
        fail(tr("No download is available for this platform."));
        return;
    }
    if (m_state == Downloading)
        return;

    m_errorString.clear();
    m_progress = 0.0;
    emit progressChanged();
    setState(Downloading);

    const QString fileName = QFileInfo(QUrl(m_downloadUrl).path()).fileName();
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    const QString target = QDir(dir).filePath(fileName.isEmpty()
                                                  ? QStringLiteral("TagStoreUpdate.bin")
                                                  : fileName);

    QNetworkRequest req{QUrl(m_downloadUrl)};
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    m_reply = m_nam->get(req);

    connect(m_reply, &QNetworkReply::downloadProgress, this,
            [this](qint64 received, qint64 total) {
                m_progress = total > 0 ? double(received) / double(total) : 0.0;
                emit progressChanged();
            });

    connect(m_reply, &QNetworkReply::finished, this, [this, target]() {
        QNetworkReply *reply = m_reply;
        m_reply = nullptr;
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            fail(tr("Download failed: %1").arg(reply->errorString()));
            return;
        }

        const QByteArray data = reply->readAll();

        if (!m_sha256.isEmpty()) {
            const QString got = QString::fromLatin1(
                QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
            if (got != m_sha256) {
                fail(tr("The downloaded file is corrupt (checksum mismatch)."));
                return;
            }
        }

        QFile f(target);
        if (!f.open(QIODevice::WriteOnly)) {
            fail(tr("Could not save the update to %1").arg(target));
            return;
        }
        f.write(data);
        f.close();
#ifndef Q_OS_WIN
        QFile::setPermissions(target, QFile::permissions(target) | QFile::ExeOwner);
#endif

        m_progress = 1.0;
        emit progressChanged();
        setState(ReadyToInstall);
        applyPackage(target);
    });
}

void Updater::applyPackage(const QString &localPath)
{
#if defined(Q_OS_WIN)
    // Launch the Inno Setup installer detached, then quit so it can replace the
    // running executable. "/SILENT" shows only a progress bar; drop it for a
    // fully interactive install.
    const bool started = QProcess::startDetached(
        localPath, QStringList{"/SILENT", "/NOCANCEL"});
    if (!started) {
        fail(tr("Could not launch the installer."));
        return;
    }
    QCoreApplication::quit();
#else
    // macOS / Linux have no in-app packaging pipeline yet: hand the downloaded
    // package (.dmg / .pkg / .tar.gz / .AppImage) to the OS so the user can
    // finish the install, then quit so any bundle swap isn't blocked.
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(localPath))) {
        fail(tr("Downloaded to %1, but could not open it automatically.").arg(localPath));
        return;
    }
    QCoreApplication::quit();
#endif
}
