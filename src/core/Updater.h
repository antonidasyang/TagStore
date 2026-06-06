#ifndef UPDATER_H
#define UPDATER_H

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QNetworkReply>

// Self-update client.
//
// Checks a static manifest (latest.json) hosted on an S3-compatible bucket
// (MinIO at https://oss.d2ssoft.com), compares the advertised version against
// the compiled-in APP_VERSION, and — if newer — downloads the platform package
// and hands it off to the OS to apply.
//
// There is no server-side logic: the "update service" is just two static
// objects in a public bucket (latest.json + the installer/package).
class Updater : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY stateChanged)
    Q_PROPERTY(QString releaseNotes READ releaseNotes NOTIFY stateChanged)
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY stateChanged)
    // Per-state convenience flags so QML (which binds the instance via a context
    // property, not the typed module) can react without naming enum constants.
    Q_PROPERTY(bool isBusy READ isBusy NOTIFY stateChanged)
    Q_PROPERTY(QString statusKey READ statusKey NOTIFY stateChanged)
    Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY progressChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY stateChanged)

public:
    enum State {
        Idle,
        Checking,
        UpToDate,
        Available,
        Downloading,
        ReadyToInstall,
        Error
    };
    Q_ENUM(State)

    explicit Updater(QObject *parent = nullptr);
    ~Updater() override;

    QString currentVersion() const;
    QString latestVersion() const { return m_latestVersion; }
    QString releaseNotes() const { return m_releaseNotes; }
    State state() const { return m_state; }
    bool updateAvailable() const { return m_state == Available
                                       || m_state == Downloading
                                       || m_state == ReadyToInstall; }
    double downloadProgress() const { return m_progress; }
    QString errorString() const { return m_errorString; }
    bool isBusy() const { return m_state == Checking || m_state == Downloading; }
    // Stable, untranslated status key for QML to map through its own t() lookup:
    // "idle" | "checking" | "uptodate" | "available" | "downloading" |
    // "installing" | "error".
    QString statusKey() const;

    // Compare two dotted version strings ("1.0.0.5"). Returns <0, 0, >0.
    static int compareVersions(const QString &a, const QString &b);

public slots:
    // Fetch latest.json and evaluate. When silent, a network/parse failure is
    // swallowed quietly (used for the automatic check on startup).
    Q_INVOKABLE void checkForUpdates(bool silent = false);
    // Download the platform package and launch it; quits the app on Windows so
    // the installer can replace the running binary.
    Q_INVOKABLE void downloadAndInstall();
    Q_INVOKABLE void cancel();

signals:
    void stateChanged();
    void progressChanged();
    // Emitted only when a newer version is actually found, so QML can pop the
    // update dialog from a startup (silent) check without nagging on no-op runs.
    void updateFound();

private:
    void setState(State s);
    void fail(const QString &message);
    QString platformKey() const;          // "windows" | "macos" | "linux"
    void applyPackage(const QString &localPath);

    QNetworkAccessManager *m_nam;
    QNetworkReply *m_reply = nullptr;
    QString m_baseUrl;                    // ends with '/'
    State m_state = Idle;
    QString m_latestVersion;
    QString m_releaseNotes;
    QString m_downloadUrl;
    QString m_sha256;                     // optional; empty = skip verification
    QString m_errorString;
    double m_progress = 0.0;
    bool m_silent = false;
};

#endif // UPDATER_H
