#include "FileHasher.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
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
    QFileInfo info(filePath);
    if (info.isDir()) {
        QDir dir(filePath);
        dir.setSorting(QDir::Name | QDir::DirsFirst | QDir::IgnoreCase);
        dir.setFilter(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
        
        QFileInfoList list = dir.entryInfoList();
        QCryptographicHash hash(QCryptographicHash::Sha256);
        
        // Add dirname itself to differentiate empty folders with different names? 
        // Or just content? If content identical, they are duplicate folders.
        // Let's stick to content listing.
        for (const QFileInfo &fi : list) {
            QString meta = fi.fileName() + QString::number(fi.size()) + fi.lastModified().toString(Qt::ISODate);
            hash.addData(meta.toUtf8());
        }
        return hash.result().toHex();
    }

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
        
        // Use the static synchronous method
        QString hash = FileHasher::computeHash(filePath);
        if (hash.isEmpty()) {
             // Check if it was empty because of error or empty file? 
             // computeHash returns empty on open error.
             QFileInfo info(filePath);
             if (info.exists() && (info.isDir() || info.size() == 0)) {
                 // Empty file/dir is valid hash (e3b0...) handled by computeHash?
                 // Wait, computeHash returns hash.result().toHex().
                 // If file open fails, it returns QString().
                 // If empty file, SHA256 of empty is "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855".
                 // So empty return means error.
                 result.error = "Failed to open file or directory";
             } else {
                 result.hash = hash;
             }
        } else {
            result.hash = hash;
        }
        
        // If hash is still empty and no error set, it failed
        if (result.hash.isEmpty() && result.error.isEmpty()) {
             result.error = "Failed to compute hash";
        }
        
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
