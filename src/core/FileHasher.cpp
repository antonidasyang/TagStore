#include "FileHasher.h"
#include <QFile>
#include <QCryptographicHash>
#include <QtConcurrent>
#include <QDebug>

FileHasher::FileHasher(QObject *parent)
    : QObject(parent)
    , m_watcher(new QFutureWatcher<HashResult>(this))
    , m_processing(false)
{
    // Use QueuedConnection to ensure slot runs in main thread
    connect(m_watcher, &QFutureWatcher<HashResult>::finished,
            this, &FileHasher::onHashFinished, Qt::QueuedConnection);
}

FileHasher::~FileHasher()
{
    cancel();
}

QString FileHasher::computeHash(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open file for hashing:" << filePath;
        return QString();
    }
    
    QCryptographicHash hash(QCryptographicHash::Sha256);
    
    // Read in chunks for better performance with large files
    const qint64 bufferSize = 1024 * 1024; // 1MB chunks
    QByteArray buffer;
    
    while (!file.atEnd()) {
        buffer = file.read(bufferSize);
        if (!buffer.isEmpty()) {
            hash.addData(buffer);
        }
    }
    
    file.close();
    return hash.result().toHex();
}

void FileHasher::computeHashAsync(const QString &filePath)
{
    if (m_processing) {
        emit hashError(filePath, "Another hash operation is in progress");
        return;
    }
    
    m_processing = true;
    m_currentFilePath = filePath;
    
    // Qt 6 syntax for QtConcurrent::run
    QFuture<HashResult> future = QtConcurrent::run([filePath]() -> HashResult {
        HashResult result;
        result.filePath = filePath;
        
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly)) {
            result.error = "Failed to open file: " + file.errorString();
            return result;
        }
        
        QCryptographicHash hash(QCryptographicHash::Sha256);
        
        const qint64 bufferSize = 1024 * 1024; // 1MB chunks
        QByteArray buffer;
        
        while (!file.atEnd()) {
            buffer = file.read(bufferSize);
            if (!buffer.isEmpty()) {
                hash.addData(buffer);
            }
        }
        
        file.close();
        result.hash = hash.result().toHex();
        return result;
    });
    
    m_watcher->setFuture(future);
}

FileHasher::HashResult FileHasher::computeHashInternal(const QString &filePath)
{
    HashResult result;
    result.filePath = filePath;
    
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        result.error = "Failed to open file: " + file.errorString();
        return result;
    }
    
    QCryptographicHash hash(QCryptographicHash::Sha256);
    
    const qint64 bufferSize = 1024 * 1024; // 1MB chunks
    QByteArray buffer;
    
    while (!file.atEnd()) {
        buffer = file.read(bufferSize);
        if (!buffer.isEmpty()) {
            hash.addData(buffer);
        }
    }
    
    file.close();
    result.hash = hash.result().toHex();
    return result;
}

void FileHasher::onHashFinished()
{
    m_processing = false;
    
    if (m_watcher->isCanceled()) {
        return;
    }
    
    HashResult result = m_watcher->result();
    
    if (!result.error.isEmpty()) {
        emit hashError(result.filePath, result.error);
    } else {
        emit hashComputed(result.filePath, result.hash);
    }
}

void FileHasher::cancel()
{
    if (m_processing) {
        m_watcher->cancel();
        if (m_watcher->isRunning()) {
            m_watcher->waitForFinished();
        }
        m_processing = false;
    }
}

bool FileHasher::isProcessing() const
{
    return m_processing;
}
