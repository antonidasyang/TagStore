#include "DatabaseManager.h"
#include <QSqlError>
#include <QSqlRecord>
#include <QDateTime>
#include <QDebug>
#include <QDir>

DatabaseManager& DatabaseManager::instance()
{
    static DatabaseManager instance;
    return instance;
}

DatabaseManager::DatabaseManager(QObject *parent)
    : QObject(parent)
{
}

DatabaseManager::~DatabaseManager()
{
    close();
}

bool DatabaseManager::initialize(const QString &dbPath)
{
    QMutexLocker locker(&m_mutex);
    
    if (m_initialized) {
        return true;
    }
    
    m_dbPath = dbPath;
    
    // Ensure directory exists
    QDir dir = QFileInfo(dbPath).absoluteDir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    
    m_database = QSqlDatabase::addDatabase("QSQLITE", "TagStoreConnection");
    m_database.setDatabaseName(dbPath);
    
    if (!m_database.open()) {
        emit databaseError(m_database.lastError().text());
        return false;
    }
    
    if (!createTables()) {
        return false;
    }
    
    m_initialized = true;
    qInfo() << "Database initialized at:" << dbPath;
    return true;
}

void DatabaseManager::close()
{
    QMutexLocker locker(&m_mutex);
    
    if (m_database.isOpen()) {
        m_database.close();
    }
    m_initialized = false;
}

bool DatabaseManager::createTables()
{
    QSqlQuery query(m_database);
    
    // FILES table
    QString createFiles = R"(
        CREATE TABLE IF NOT EXISTS files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content_hash TEXT NOT NULL,
            filename TEXT NOT NULL,
            file_path TEXT UNIQUE NOT NULL,
            storage_mode INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
        )
    )";
    
    if (!query.exec(createFiles)) {
        emit databaseError("Failed to create files table: " + query.lastError().text());
        return false;
    }
    
    // Create index on content_hash
    query.exec("CREATE INDEX IF NOT EXISTS idx_content_hash ON files(content_hash)");
    
    // TAGS table
    QString createTags = R"(
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL
        )
    )";
    
    if (!query.exec(createTags)) {
        emit databaseError("Failed to create tags table: " + query.lastError().text());
        return false;
    }
    
    // FILE_TAGS junction table
    QString createFileTags = R"(
        CREATE TABLE IF NOT EXISTS file_tags (
            file_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            PRIMARY KEY (file_id, tag_id),
            FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
    )";
    
    if (!query.exec(createFileTags)) {
        emit databaseError("Failed to create file_tags table: " + query.lastError().text());
        return false;
    }
    
    // PROCESSING_QUEUE table
    QString createQueue = R"(
        CREATE TABLE IF NOT EXISTS processing_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id INTEGER NOT NULL,
            status INTEGER DEFAULT 0,
            error_log TEXT,
            FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE
        )
    )";
    
    if (!query.exec(createQueue)) {
        emit databaseError("Failed to create processing_queue table: " + query.lastError().text());
        return false;
    }
    
    // Enable foreign keys
    query.exec("PRAGMA foreign_keys = ON");
    
    return true;
}

bool DatabaseManager::executeQuery(QSqlQuery &query)
{
    if (!query.exec()) {
        emit databaseError(query.lastError().text());
        return false;
    }
    return true;
}

bool DatabaseManager::addFile(const QString &contentHash, const QString &filename,
                              const QString &filePath, int storageMode)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT INTO files (content_hash, filename, file_path, storage_mode, created_at)
        VALUES (:hash, :name, :path, :mode, :time)
    )");
    
    query.bindValue(":hash", contentHash);
    query.bindValue(":name", filename);
    query.bindValue(":path", filePath);
    query.bindValue(":mode", storageMode);
    query.bindValue(":time", QDateTime::currentSecsSinceEpoch());
    
    if (!executeQuery(query)) {
        return false;
    }
    
    int fileId = query.lastInsertId().toInt();
    emit fileAdded(fileId);
    return true;
}

bool DatabaseManager::hashExists(const QString &hash)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("SELECT COUNT(*) FROM files WHERE content_hash = :hash");
    query.bindValue(":hash", hash);
    
    if (query.exec() && query.next()) {
        return query.value(0).toInt() > 0;
    }
    return false;
}

bool DatabaseManager::pathExists(const QString &path)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("SELECT COUNT(*) FROM files WHERE file_path = :path");
    query.bindValue(":path", path);
    
    if (query.exec() && query.next()) {
        return query.value(0).toInt() > 0;
    }
    return false;
}

QList<FileDTO> DatabaseManager::getFilesByHash(const QString &hash)
{
    QMutexLocker locker(&m_mutex);
    QList<FileDTO> files;
    
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM files WHERE content_hash = :hash");
    query.bindValue(":hash", hash);
    
    if (query.exec()) {
        while (query.next()) {
            FileDTO file;
            file.id = query.value("id").toInt();
            file.contentHash = query.value("content_hash").toString();
            file.filename = query.value("filename").toString();
            file.filePath = query.value("file_path").toString();
            file.storageMode = query.value("storage_mode").toInt();
            file.createdAt = query.value("created_at").toLongLong();
            files.append(file);
        }
    }
    
    return files;
}

FileDTO DatabaseManager::getFileById(int id)
{
    QMutexLocker locker(&m_mutex);
    FileDTO file;
    
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM files WHERE id = :id");
    query.bindValue(":id", id);
    
    if (query.exec() && query.next()) {
        file.id = query.value("id").toInt();
        file.contentHash = query.value("content_hash").toString();
        file.filename = query.value("filename").toString();
        file.filePath = query.value("file_path").toString();
        file.storageMode = query.value("storage_mode").toInt();
        file.createdAt = query.value("created_at").toLongLong();
    }
    
    return file;
}

FileDTO DatabaseManager::getFileByPath(const QString &path)
{
    QMutexLocker locker(&m_mutex);
    FileDTO file;
    
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM files WHERE file_path = :path");
    query.bindValue(":path", path);
    
    if (query.exec() && query.next()) {
        file.id = query.value("id").toInt();
        file.contentHash = query.value("content_hash").toString();
        file.filename = query.value("filename").toString();
        file.filePath = query.value("file_path").toString();
        file.storageMode = query.value("storage_mode").toInt();
        file.createdAt = query.value("created_at").toLongLong();
    }
    
    return file;
}

bool DatabaseManager::removeFile(int fileId)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("DELETE FROM files WHERE id = :id");
    query.bindValue(":id", fileId);
    
    if (!executeQuery(query)) {
        return false;
    }
    
    emit fileRemoved(fileId);
    return true;
}

int DatabaseManager::getOrCreateTag(const QString &tagName)
{
    QMutexLocker locker(&m_mutex);
    
    QString normalizedName = tagName.trimmed().toLower();
    
    // Try to find existing tag
    QSqlQuery query(m_database);
    query.prepare("SELECT id FROM tags WHERE name = :name");
    query.bindValue(":name", normalizedName);
    
    if (query.exec() && query.next()) {
        return query.value(0).toInt();
    }
    
    // Create new tag
    query.prepare("INSERT INTO tags (name) VALUES (:name)");
    query.bindValue(":name", normalizedName);
    
    if (query.exec()) {
        return query.lastInsertId().toInt();
    }
    
    return -1;
}

bool DatabaseManager::addTagToFile(int fileId, int tagId)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("INSERT OR IGNORE INTO file_tags (file_id, tag_id) VALUES (:fid, :tid)");
    query.bindValue(":fid", fileId);
    query.bindValue(":tid", tagId);
    
    if (!executeQuery(query)) {
        return false;
    }
    
    emit tagsUpdated(fileId);
    return true;
}

bool DatabaseManager::addTagsToFile(int fileId, const QStringList &tagNames)
{
    for (const QString &tagName : tagNames) {
        // Split by comma in case a comma-separated string was passed as one item
        QStringList splitTags = tagName.split(',', Qt::SkipEmptyParts);
        for (const QString &tag : splitTags) {
            QString trimmedTag = tag.trimmed();
            if (trimmedTag.isEmpty()) continue;
            
            int tagId = getOrCreateTag(trimmedTag);
            if (tagId > 0) {
                // Need to unlock mutex temporarily since addTagToFile also locks
                QSqlQuery query(m_database);
                query.prepare("INSERT OR IGNORE INTO file_tags (file_id, tag_id) VALUES (:fid, :tid)");
                query.bindValue(":fid", fileId);
                query.bindValue(":tid", tagId);
                query.exec();
            }
        }
    }
    
    emit tagsUpdated(fileId);
    return true;
}

QStringList DatabaseManager::getTagsForFile(int fileId)
{
    QMutexLocker locker(&m_mutex);
    QStringList tags;
    
    QSqlQuery query(m_database);
    query.prepare(R"(
        SELECT t.name FROM tags t
        INNER JOIN file_tags ft ON t.id = ft.tag_id
        WHERE ft.file_id = :fid
        ORDER BY t.name
    )");
    query.bindValue(":fid", fileId);
    
    if (query.exec()) {
        while (query.next()) {
            tags.append(query.value(0).toString());
        }
    }
    
    return tags;
}

QVariantList DatabaseManager::getAllTags()
{
    QMutexLocker locker(&m_mutex);
    QVariantList tags;
    
    QSqlQuery query(m_database);
    query.prepare(R"(
        SELECT t.id, t.name, COUNT(ft.file_id) as count
        FROM tags t
        LEFT JOIN file_tags ft ON t.id = ft.tag_id
        GROUP BY t.id
        ORDER BY count DESC, t.name
    )");
    
    if (query.exec()) {
        while (query.next()) {
            QVariantMap tag;
            tag["id"] = query.value("id").toInt();
            tag["name"] = query.value("name").toString();
            tags.append(tag);
        }
    }
    
    return tags;
}

QVariantList DatabaseManager::searchTags(const QString &keyword)
{
    QMutexLocker locker(&m_mutex);
    QVariantList tags;
    
    if (keyword.isEmpty()) {
        return tags;
    }
    
    QSqlQuery query(m_database);
    query.prepare(R"(
        SELECT t.id, t.name, COUNT(ft.file_id) as count
        FROM tags t
        LEFT JOIN file_tags ft ON t.id = ft.tag_id
        WHERE t.name LIKE :keyword
        GROUP BY t.id
        ORDER BY count DESC, t.name
    )");
    query.bindValue(":keyword", "%" + keyword + "%");
    
    if (query.exec()) {
        while (query.next()) {
            QVariantMap tag;
            tag["id"] = query.value("id").toInt();
            tag["name"] = query.value("name").toString();
            tags.append(tag);
        }
    }
    
    return tags;
}

bool DatabaseManager::removeTagFromFile(int fileId, int tagId)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("DELETE FROM file_tags WHERE file_id = :fid AND tag_id = :tid");
    query.bindValue(":fid", fileId);
    query.bindValue(":tid", tagId);
    
    if (!executeQuery(query)) {
        return false;
    }
    
    emit tagsUpdated(fileId);
    return true;
}

QList<FileDTO> DatabaseManager::search(const QString &keyword, const QList<int> &tagIds)
{
    QMutexLocker locker(&m_mutex);
    QList<FileDTO> files;
    
    // Search in both filename and tag names
    QString sql = "SELECT DISTINCT f.* FROM files f "
                  "LEFT JOIN file_tags ft ON f.id = ft.file_id "
                  "LEFT JOIN tags t ON ft.tag_id = t.id";
    
    QStringList conditions;
    
    if (!keyword.isEmpty()) {
        // Search in both filename AND tag name
        conditions << "(f.filename LIKE :keyword OR t.name LIKE :keyword)";
    }
    
    if (!tagIds.isEmpty()) {
        // For tag filtering, we need files that have ALL selected tags
        QStringList tagPlaceholders;
        for (int i = 0; i < tagIds.size(); ++i) {
            tagPlaceholders << QString(":tag%1").arg(i);
        }
        conditions << QString("f.id IN (SELECT file_id FROM file_tags WHERE tag_id IN (%1) "
                             "GROUP BY file_id HAVING COUNT(DISTINCT tag_id) = %2)")
                      .arg(tagPlaceholders.join(", "))
                      .arg(tagIds.size());
    }
    
    if (!conditions.isEmpty()) {
        sql += " WHERE " + conditions.join(" AND ");
    }
    
    sql += " GROUP BY f.id ORDER BY f.created_at DESC";
    
    QSqlQuery query(m_database);
    query.prepare(sql);
    
    if (!keyword.isEmpty()) {
        query.bindValue(":keyword", "%" + keyword + "%");
    }
    
    for (int i = 0; i < tagIds.size(); ++i) {
        query.bindValue(QString(":tag%1").arg(i), tagIds[i]);
    }
    
    if (query.exec()) {
        while (query.next()) {
            FileDTO file;
            file.id = query.value("id").toInt();
            file.contentHash = query.value("content_hash").toString();
            file.filename = query.value("filename").toString();
            file.filePath = query.value("file_path").toString();
            file.storageMode = query.value("storage_mode").toInt();
            file.createdAt = query.value("created_at").toLongLong();
            files.append(file);
        }
    }
    
    return files;
}

QList<FileDTO> DatabaseManager::getAllFiles()
{
    QMutexLocker locker(&m_mutex);
    QList<FileDTO> files;
    
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM files ORDER BY created_at DESC");
    
    if (query.exec()) {
        while (query.next()) {
            FileDTO file;
            file.id = query.value("id").toInt();
            file.contentHash = query.value("content_hash").toString();
            file.filename = query.value("filename").toString();
            file.filePath = query.value("file_path").toString();
            file.storageMode = query.value("storage_mode").toInt();
            file.createdAt = query.value("created_at").toLongLong();
            files.append(file);
        }
    }
    
    return files;
}

bool DatabaseManager::pushToQueue(int fileId)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("INSERT INTO processing_queue (file_id, status) VALUES (:fid, 0)");
    query.bindValue(":fid", fileId);
    
    return executeQuery(query);
}

QueueItemDTO DatabaseManager::popNextQueueItem()
{
    QMutexLocker locker(&m_mutex);
    QueueItemDTO item;
    
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM processing_queue WHERE status = 0 ORDER BY id LIMIT 1");
    
    if (query.exec() && query.next()) {
        item.id = query.value("id").toInt();
        item.fileId = query.value("file_id").toInt();
        item.status = query.value("status").toInt();
        item.errorLog = query.value("error_log").toString();
    }
    
    return item;
}

bool DatabaseManager::updateQueueStatus(int queueId, int status, const QString &errorLog)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("UPDATE processing_queue SET status = :status, error_log = :log WHERE id = :id");
    query.bindValue(":status", status);
    query.bindValue(":log", errorLog);
    query.bindValue(":id", queueId);
    
    return executeQuery(query);
}

int DatabaseManager::getPendingQueueCount()
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("SELECT COUNT(*) FROM processing_queue WHERE status = 0");
    
    if (query.exec() && query.next()) {
        return query.value(0).toInt();
    }
    
    return 0;
}
