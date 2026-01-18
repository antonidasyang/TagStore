#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QMutex>
#include <QString>
#include <QList>
#include <QVariant>
#include <QVariantMap>
#include <QVariantList>

struct FileDTO {
    int id = -1;
    QString contentHash;
    QString filename;
    QString filePath;
    int storageMode = 0; // 0=Managed, 1=Referenced
    qint64 createdAt = 0;
};

struct TagDTO {
    int id = -1;
    QString name;
};

struct QueueItemDTO {
    int id = -1;
    int fileId = -1;
    int status = 0; // 0=Pending, 1=Processing, 2=Done
    QString errorLog;
};

class DatabaseManager : public QObject
{
    Q_OBJECT
    
public:
    static DatabaseManager& instance();
    
    bool initialize(const QString &dbPath);
    void close();
    
    // File operations
    Q_INVOKABLE bool addFile(const QString &contentHash, const QString &filename,
                             const QString &filePath, int storageMode);
    Q_INVOKABLE bool hashExists(const QString &hash);
    Q_INVOKABLE bool pathExists(const QString &path);
    Q_INVOKABLE QList<FileDTO> getFilesByHash(const QString &hash);
    Q_INVOKABLE FileDTO getFileById(int id);
    Q_INVOKABLE FileDTO getFileByPath(const QString &path);
    Q_INVOKABLE bool removeFile(int fileId);
    
    // Tag operations
    Q_INVOKABLE int getOrCreateTag(const QString &tagName);
    Q_INVOKABLE bool addTagToFile(int fileId, int tagId);
    Q_INVOKABLE bool addTagsToFile(int fileId, const QStringList &tagNames);
    Q_INVOKABLE QStringList getTagsForFile(int fileId);
    Q_INVOKABLE QVariantList getAllTags();
    Q_INVOKABLE QVariantList searchTags(const QString &keyword);
    Q_INVOKABLE bool removeTagFromFile(int fileId, int tagId);
    
    // Search operations
    Q_INVOKABLE QList<FileDTO> search(const QString &keyword, const QList<int> &tagIds);
    Q_INVOKABLE QList<FileDTO> getAllFiles();
    
    // Queue operations
    Q_INVOKABLE bool pushToQueue(int fileId);
    Q_INVOKABLE QueueItemDTO popNextQueueItem();
    Q_INVOKABLE bool updateQueueStatus(int queueId, int status, const QString &errorLog = QString());
    Q_INVOKABLE int getPendingQueueCount();
    
signals:
    void fileAdded(int fileId);
    void fileRemoved(int fileId);
    void tagsUpdated(int fileId);
    void databaseError(const QString &error);
    
private:
    DatabaseManager(QObject *parent = nullptr);
    ~DatabaseManager();
    
    DatabaseManager(const DatabaseManager&) = delete;
    DatabaseManager& operator=(const DatabaseManager&) = delete;
    
    bool createTables();
    bool executeQuery(QSqlQuery &query);
    
    QSqlDatabase m_database;
    QMutex m_mutex;
    QString m_dbPath;
    bool m_initialized = false;
};

#endif // DATABASEMANAGER_H
