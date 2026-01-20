#include "FileIngestor.h"
#include "core/FileHasher.h"
#include "core/LibraryConfig.h"
#include "core/DatabaseManager.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>
#include <QUuid>
#include <QDebug>
#include <QGuiApplication>

FileIngestor::FileIngestor(QObject *parent)
    : QObject(parent)
    , m_hasher(new FileHasher(this))
    , m_currentMode(Managed)
    , m_totalFiles(0)
    , m_processedFiles(0)
    , m_isProcessing(false)
{
    // Use QueuedConnection to ensure slots run in main thread
    connect(m_hasher, &FileHasher::hashComputed, this, &FileIngestor::onHashComputed, Qt::QueuedConnection);
    connect(m_hasher, &FileHasher::hashError, this, &FileIngestor::onHashError, Qt::QueuedConnection);
}

FileIngestor::~FileIngestor()
{
    cancelPendingJobs();
}

bool FileIngestor::isProcessing() const
{
    return m_isProcessing;
}

void FileIngestor::processDroppedFiles(const QList<QUrl> &urls, int mode)
{
    // Check for directories
    bool hasDir = false;
    for (const QUrl &url : urls) {
        if (QFileInfo(url.toLocalFile()).isDir()) {
            hasDir = true;
            break;
        }
    }
    
    if (hasDir) {
        emit askFolderHandling(urls, mode);
        return;
    }
    
    processFilesWithFolderOption(urls, mode, false);
}

void FileIngestor::processFilesWithFolderOption(const QList<QUrl> &urls, int mode, bool recursive)
{
    for (const QUrl &url : urls) {
        QString localPath = url.toLocalFile();
        QFileInfo info(localPath);
        
        if (!localPath.isEmpty() && info.exists()) {
            if (info.isDir()) {
                if (recursive) {
                    // Recursive scan
                    QDirIterator it(localPath, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
                    while (it.hasNext()) {
                        m_pendingFiles.append({it.next(), mode});
                    }
                } else {
                    // Import directory as item (Referenced mode only)
                    m_pendingFiles.append({localPath, Referenced});
                }
            } else {
                // Regular file
                m_pendingFiles.append({localPath, mode});
            }
        }
    }
    
    m_totalFiles = m_pendingFiles.count();
    m_processedFiles = 0;
    
    if (!m_isProcessing && !m_pendingFiles.isEmpty()) {
        m_isProcessing = true;
        emit isProcessingChanged();
        processNextFile();
    }
}

void FileIngestor::processDroppedFile(const QUrl &url, int mode)
{
    processDroppedFiles({url}, mode);
}

void FileIngestor::resolveConflict(const QString &jobId, int resolution)
{
    if (!m_conflictJobs.contains(jobId)) {
        qWarning() << "Unknown conflict job:" << jobId;
        return;
    }
    
    PendingJob job = m_conflictJobs.take(jobId);
    
    switch (resolution) {
    case Reject:
        qInfo() << "Import rejected for:" << job.filename;
        break;
        
    case ImportAsCopy:
        importFile(job.sourcePath, job.hash, job.mode);
        break;
        
    case MergeAlias: {
        // Add filename as alias tag to existing file
        QList<FileDTO> existing = DatabaseManager::instance().getFilesByHash(job.hash);
        if (!existing.isEmpty()) {
            DatabaseManager::instance().addTagsToFile(existing.first().id, 
                                                       {QFileInfo(job.filename).completeBaseName()});
        }
        break;
    }
    }
    
    m_processedFiles++;
    emit progressChanged(m_processedFiles, m_totalFiles);
    
    // Continue processing
    if (!m_pendingFiles.isEmpty()) {
        processNextFile();
    } else if (m_conflictJobs.isEmpty()) {
        m_isProcessing = false;
        emit isProcessingChanged();
        emit allFilesProcessed();
    }
}

void FileIngestor::cancelPendingJobs()
{
    m_hasher->cancel();
    m_pendingFiles.clear();
    m_conflictJobs.clear();
    
    if (m_isProcessing) {
        m_isProcessing = false;
        emit isProcessingChanged();
    }
}

void FileIngestor::processNextFile()
{
    if (m_pendingFiles.isEmpty()) {
        if (m_conflictJobs.isEmpty()) {
            m_isProcessing = false;
            emit isProcessingChanged();
            emit allFilesProcessed();
        }
        return;
    }
    
    auto [path, mode] = m_pendingFiles.takeFirst();
    m_currentFilePath = path;
    m_currentMode = mode;
    
    QString filename = QFileInfo(path).fileName();
    emit fileProcessingStarted(filename);
    
    // Compute hash asynchronously
    m_hasher->computeHashAsync(path);
}

void FileIngestor::onHashComputed(const QString &filePath, const QString &hash)
{
    if (filePath != m_currentFilePath) {
        return;
    }
    
    QString filename = QFileInfo(filePath).fileName();
    
    // Check for duplicates
    if (DatabaseManager::instance().hashExists(hash)) {
        // Conflict detected
        QString jobId = generateJobId();
        PendingJob job;
        job.jobId = jobId;
        job.sourcePath = filePath;
        job.filename = filename;
        job.hash = hash;
        job.mode = m_currentMode;
        m_conflictJobs[jobId] = job;
        
        QList<FileDTO> existing = DatabaseManager::instance().getFilesByHash(hash);
        QString existingPath = existing.isEmpty() ? "" : existing.first().filePath;
        
        emit conflictDetected(jobId, filename, existingPath, hash);
        
        // Process next file while waiting for resolution
        processNextFile();
    } else {
        // No conflict, proceed with import
        importFile(filePath, hash, m_currentMode);
        
        m_processedFiles++;
        emit progressChanged(m_processedFiles, m_totalFiles);
        
        // Process next file
        processNextFile();
    }
}

void FileIngestor::onHashError(const QString &filePath, const QString &error)
{
    QString filename = QFileInfo(filePath).fileName();
    emit processingError(filename, error);
    
    m_processedFiles++;
    emit progressChanged(m_processedFiles, m_totalFiles);
    
    // Continue with next file
    processNextFile();
}

void FileIngestor::importFile(const QString &sourcePath, const QString &hash, int mode)
{
    QFileInfo sourceInfo(sourcePath);
    QString filename = sourceInfo.fileName();
    QString targetPath;
    bool isDir = sourceInfo.isDir();
    
    if (mode == Managed && !isDir) {
        // Generate storage path and move file
        targetPath = LibraryConfig::instance().generateStoragePath(filename);
        
        if (!moveFileToLibrary(sourcePath, targetPath)) {
            emit processingError(filename, "Failed to move file to library");
            return;
        }
    } else {
        // Referenced mode (or Directory) - keep file in place
        targetPath = sourcePath;
    }
    
    // Add to database
    if (DatabaseManager::instance().addFile(hash, filename, targetPath, sourcePath, mode, isDir)) {
        // Get the new file ID
        FileDTO file = DatabaseManager::instance().getFileByPath(targetPath);
        if (file.id > 0) {
            // Push to AI processing queue if auto-tag is enabled
            if (LibraryConfig::instance().autoAiTag()) {
                DatabaseManager::instance().pushToQueue(file.id);
            }
            emit fileAdded(file.id, filename);
        }
    } else {
        emit processingError(filename, "Failed to add file to database");
        
        // If we moved the file, try to move it back
        if (mode == Managed && targetPath != sourcePath) {
            QFile::rename(targetPath, sourcePath);
        }
    }
}

bool FileIngestor::moveFileToLibrary(const QString &sourcePath, const QString &targetPath)
{
    QFileInfo targetInfo(targetPath);
    QDir targetDir = targetInfo.absoluteDir();
    
    if (!targetDir.exists()) {
        if (!targetDir.mkpath(".")) {
            qWarning() << "Failed to create directory:" << targetDir.path();
            return false;
        }
    }
    
    // Try to rename (move) first - it's faster if on same filesystem
    if (QFile::rename(sourcePath, targetPath)) {
        return true;
    }
    
    // Fallback to copy + delete
    if (QFile::copy(sourcePath, targetPath)) {
        if (QFile::remove(sourcePath)) {
            return true;
        } else {
            // Copy succeeded but delete failed
            qWarning() << "Failed to remove source file after copy:" << sourcePath;
            return true; // Still consider success, file is in library
        }
    }
    
    qWarning() << "Failed to copy file:" << sourcePath << "to" << targetPath;
    return false;
}

QString FileIngestor::generateJobId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

int FileIngestor::mouseButtons() const
{
    return QGuiApplication::mouseButtons();
}
