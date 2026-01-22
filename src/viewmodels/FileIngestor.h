#ifndef FILEINGESTOR_H
#define FILEINGESTOR_H

#include <QObject>
#include <QUrl>
#include <QList>
#include <QString>
#include <QVariantMap>

class FileHasher;

class FileIngestor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY isProcessingChanged)
    
public:
    enum ImportMode {
        Managed = 0,    // Move file to library
        Referenced = 1  // Keep file in original location
    };
    Q_ENUM(ImportMode)
    
    enum ConflictResolution {
        Reject = 0,       // Cancel import
        ImportAsCopy = 1, // Import as distinct copy
        MergeAlias = 2    // Add filename as tag to existing
    };
    Q_ENUM(ConflictResolution)
    
    explicit FileIngestor(QObject *parent = nullptr);
    ~FileIngestor();
    
    bool isProcessing() const;
    
    // Main import methods
    Q_INVOKABLE void processDroppedFiles(const QList<QUrl> &urls, int mode = Managed);
    Q_INVOKABLE void processDroppedFile(const QUrl &url, int mode = Managed);
    Q_INVOKABLE void processFilesWithFolderOption(const QList<QUrl> &urls, int mode, bool recursive);
    Q_INVOKABLE void resolveConflict(const QString &jobId, int resolution);
    Q_INVOKABLE void cancelPendingJobs();
    
    // Helper to get global mouse buttons (workaround for QML issues)
    Q_INVOKABLE int mouseButtons() const;
    
signals:
    void isProcessingChanged();
    void askFolderHandling(const QList<QUrl> &urls, int mode);
    void fileProcessingStarted(const QString &filename);
    void fileAdded(int fileId, const QString &filename);
    void conflictDetected(const QString &jobId, const QString &newFilename, 
                          const QString &existingPath, const QString &hash);
    void processingError(const QString &filename, const QString &error);
    void allFilesProcessed();
    void progressChanged(int current, int total);
    
private slots:
    void onHashComputed(const QString &filePath, const QString &hash);
    void onHashError(const QString &filePath, const QString &error);
    
private:
    struct PendingJob {
        QString jobId;
        QString sourcePath;
        QString filename;
        QString hash;
        int mode;
    };
    
    void processNextFile();
    void importFile(const QString &sourcePath, const QString &hash, int mode);
    bool moveFileToLibrary(const QString &sourcePath, const QString &targetPath);
    bool copyRecursively(const QString &src, const QString &dst);
    QString generateJobId();
    
    FileHasher *m_hasher;
    QList<QPair<QString, int>> m_pendingFiles; // (path, mode) pairs
    QMap<QString, PendingJob> m_conflictJobs;
    QString m_currentFilePath;
    int m_currentMode;
    int m_totalFiles;
    int m_processedFiles;
    bool m_isProcessing;
};

#endif // FILEINGESTOR_H
