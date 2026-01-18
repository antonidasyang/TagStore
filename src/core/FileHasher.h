#ifndef FILEHASHER_H
#define FILEHASHER_H

#include <QObject>
#include <QString>
#include <QFuture>
#include <QFutureWatcher>

class FileHasher : public QObject
{
    Q_OBJECT
    
public:
    explicit FileHasher(QObject *parent = nullptr);
    ~FileHasher();
    
    // Synchronous hash computation
    Q_INVOKABLE static QString computeHash(const QString &filePath);
    
    // Asynchronous hash computation
    Q_INVOKABLE void computeHashAsync(const QString &filePath);
    
    // Cancel ongoing async operation
    Q_INVOKABLE void cancel();
    
    // Check if currently processing
    Q_INVOKABLE bool isProcessing() const;
    
signals:
    void hashComputed(const QString &filePath, const QString &hash);
    void hashError(const QString &filePath, const QString &error);
    void progressChanged(const QString &filePath, int percent);
    
private slots:
    void onHashFinished();
    
private:
    struct HashResult {
        QString filePath;
        QString hash;
        QString error;
    };
    
    static HashResult computeHashInternal(const QString &filePath);
    
    QFutureWatcher<HashResult> *m_watcher;
    QString m_currentFilePath;
    bool m_processing;
};

#endif // FILEHASHER_H
