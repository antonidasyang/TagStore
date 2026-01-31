#include "DatabaseManager.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QDebug>
#include <QDateTime>
#include <QRegularExpression>
#include <QtConcurrent>

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
    
    if (m_initialized) return true;
    
    m_dbPath = dbPath;
    
    // Ensure directory exists
    QDir dir = QFileInfo(dbPath).absoluteDir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    
    m_database = QSqlDatabase::addDatabase("QSQLITE");
    m_database.setDatabaseName(dbPath);
    
    if (!m_database.open()) {
        qCritical() << "Error opening database:" << m_database.lastError().text();
        return false;
    }
    
        if (!createTables()) {
    
            return false;
    
        }
    
        
    
        // Reset any stuck jobs from previous runs
    
        QSqlQuery resetQuery(m_database);
    
        resetQuery.exec("UPDATE processing_queue SET status = 0 WHERE status = 1");
    
        
    
        m_initialized = true;
    
        
    
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
    
    // Files table
    if (!query.exec(R"(
        CREATE TABLE IF NOT EXISTS files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content_hash TEXT UNIQUE NOT NULL,
            filename TEXT NOT NULL,
            file_path TEXT UNIQUE NOT NULL,
            original_path TEXT,
            storage_mode INTEGER DEFAULT 0,
            is_dir INTEGER DEFAULT 0,
            created_at INTEGER
        )
    )")) {
        qCritical() << "Error creating files table:" << query.lastError().text();
        return false;
    }
    
    // Tags table
    if (!query.exec(R"(
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL
        )
    )")) {
        qCritical() << "Error creating tags table:" << query.lastError().text();
        return false;
    }
    
    // File-Tags mapping table
    if (!query.exec(R"(
        CREATE TABLE IF NOT EXISTS file_tags (
            file_id INTEGER,
            tag_id INTEGER,
            PRIMARY KEY (file_id, tag_id),
            FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
    )")) {
        qCritical() << "Error creating file_tags table:" << query.lastError().text();
        return false;
    }
    
    // Queue table
    // Re-create queue table to ensure schema consistency
    query.exec("DROP TABLE IF EXISTS processing_queue");
    
    if (!query.exec(R"(
        CREATE TABLE IF NOT EXISTS processing_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id INTEGER,
            status INTEGER DEFAULT 0,
            error_log TEXT,
            created_at INTEGER,
            FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE
        )
    )")) {
        qCritical() << "Error creating processing_queue table:" << query.lastError().text();
        return false;
    }
    
    return true;
}

bool DatabaseManager::addFile(const QString &contentHash, const QString &filename,
                              const QString &filePath, const QString &originalPath, 
                              int storageMode, bool isDir)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT INTO files (content_hash, filename, file_path, original_path, storage_mode, is_dir, created_at)
        VALUES (:hash, :name, :path, :orig, :mode, :isdir, :time)
    )");
    
    query.bindValue(":hash", contentHash);
    query.bindValue(":name", filename);
    query.bindValue(":path", filePath);
    query.bindValue(":orig", originalPath);
    query.bindValue(":mode", storageMode);
    query.bindValue(":isdir", isDir ? 1 : 0);
    query.bindValue(":time", QDateTime::currentMSecsSinceEpoch());
    
    if (query.exec()) {
        int id = query.lastInsertId().toInt();
        emit fileAdded(id);
        return true;
    }
    
    qWarning() << "Add file error:" << query.lastError().text();
    return false;
}

bool DatabaseManager::hashExists(const QString &hash)
{
    QMutexLocker locker(&m_mutex);
    QSqlQuery query(m_database);
    query.prepare("SELECT 1 FROM files WHERE content_hash = :hash");
    query.bindValue(":hash", hash);
    return query.exec() && query.next();
}

bool DatabaseManager::pathExists(const QString &path)
{
    QMutexLocker locker(&m_mutex);
    QSqlQuery query(m_database);
    query.prepare("SELECT 1 FROM files WHERE file_path = :path");
    query.bindValue(":path", path);
    return query.exec() && query.next();
}

QList<FileDTO> DatabaseManager::getFilesByHash(const QString &hash)
{
    QMutexLocker locker(&m_mutex);
    QList<FileDTO> list;
    
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM files WHERE content_hash = :hash");
    query.bindValue(":hash", hash);
    
    if (query.exec()) {
        while (query.next()) {
            FileDTO f;
            f.id = query.value("id").toInt();
            f.contentHash = query.value("content_hash").toString();
            f.filename = query.value("filename").toString();
            f.filePath = query.value("file_path").toString();
            f.originalPath = query.value("original_path").toString();
            f.storageMode = query.value("storage_mode").toInt();
            f.isDir = query.value("is_dir").toBool();
            f.createdAt = query.value("created_at").toLongLong();
            list.append(f);
        }
    }
    return list;
}

FileDTO DatabaseManager::getFileById(int id)
{
    QMutexLocker locker(&m_mutex);
    FileDTO f;
    
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM files WHERE id = :id");
    query.bindValue(":id", id);
    
    if (query.exec() && query.next()) {
        f.id = query.value("id").toInt();
        f.contentHash = query.value("content_hash").toString();
        f.filename = query.value("filename").toString();
        f.filePath = query.value("file_path").toString();
        f.originalPath = query.value("original_path").toString();
        f.storageMode = query.value("storage_mode").toInt();
        f.isDir = query.value("is_dir").toBool();
        f.createdAt = query.value("created_at").toLongLong();
    }
    return f;
}

FileDTO DatabaseManager::getFileByPath(const QString &path)
{
    QMutexLocker locker(&m_mutex);
    FileDTO f;
    
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM files WHERE file_path = :path");
    query.bindValue(":path", path);
    
    if (query.exec() && query.next()) {
        f.id = query.value("id").toInt();
        f.contentHash = query.value("content_hash").toString();
        f.filename = query.value("filename").toString();
        f.filePath = query.value("file_path").toString();
        f.originalPath = query.value("original_path").toString();
        f.storageMode = query.value("storage_mode").toInt();
        f.isDir = query.value("is_dir").toBool();
        f.createdAt = query.value("created_at").toLongLong();
    }
    return f;
}

bool DatabaseManager::removeFile(int fileId)
{
    FileDTO file = getFileById(fileId);
    if (file.id < 0) return false;
    
    if (file.storageMode == 0) { // Managed
        QFile::moveToTrash(file.filePath);
    }
    
    QMutexLocker locker(&m_mutex);
    QSqlQuery query(m_database);
    query.prepare("DELETE FROM files WHERE id = :id");
    query.bindValue(":id", fileId);
    
    if (query.exec()) {
        emit fileRemoved(fileId);
        invalidateTagCache();
        return true;
    }
    return false;
}

bool DatabaseManager::restoreFile(int fileId)
{
    FileDTO file = getFileById(fileId);
    if (file.id < 0) return false;
    
    if (file.storageMode == 0) { // Managed
        if (!file.originalPath.isEmpty()) {
            QDir().mkpath(QFileInfo(file.originalPath).absolutePath());
            if (QFile::rename(file.filePath, file.originalPath)) {
                // Success
            } else {
                qWarning() << "Failed to restore file to" << file.originalPath;
                return false;
            }
        }
    }
    
    QMutexLocker locker(&m_mutex);
    QSqlQuery query(m_database);
    query.prepare("DELETE FROM files WHERE id = :id");
    query.bindValue(":id", fileId);
    
    if (query.exec()) {
        emit fileRemoved(fileId);
        invalidateTagCache();
        return true;
    }
    return false;
}

bool DatabaseManager::renameFile(int fileId, const QString &newName)
{
    FileDTO file = getFileById(fileId);
    if (file.id < 0) return false;
    
    // 1. Validate name
    if (newName.contains(QRegularExpression(R"([\/:*?"<>|])"))) {
        emit databaseError("Invalid characters in filename");
        return false;
    }

    QString oldPath = file.filePath;
    QFileInfo info(oldPath);
    QString newPath = info.absoluteDir().filePath(newName);
    
    if (QFile::exists(newPath) && QFileInfo(newPath).canonicalFilePath() != QFileInfo(oldPath).canonicalFilePath()) {
        emit databaseError("Destination already exists");
        return false;
    }
    
    // 2. Perform disk rename WITHOUT holding DB mutex
    bool renamed = false;
    QString errorString;
    bool isCaseChange = (oldPath.toLower() == newPath.toLower()) && (oldPath != newPath);
    
    if (isCaseChange) {
        QString tempPath = newPath + ".rename_tmp";
        QFile f(oldPath);
        if (f.rename(tempPath)) {
            if (f.rename(newPath)) {
                renamed = true;
            } else {
                errorString = f.errorString();
                f.rename(oldPath); // Rollback
            }
        } else {
            errorString = f.errorString();
        }
    } else {
        // Use QFile for both file and dir rename to capture errorString
        QFile f(oldPath);
        renamed = f.rename(newPath);
        if (!renamed) errorString = f.errorString();
    }
    
    if (!renamed) {
        qWarning() << "Failed to rename:" << oldPath << "to" << newPath << "Error:" << errorString;
        emit databaseError("Rename failed: " + (errorString.isEmpty() ? "Unknown error" : errorString));
        return false;
    }
    
    // 3. Update DB while holding mutex
    bool dbSuccess = false;
    {
        QMutexLocker locker(&m_mutex);
        QSqlQuery query(m_database);
        query.prepare("UPDATE files SET filename = :name, file_path = :path WHERE id = :id");
        query.bindValue(":name", newName);
        query.bindValue(":path", newPath);
        query.bindValue(":id", fileId);
        dbSuccess = query.exec();
    }
    
    if (dbSuccess) {
        emit fileRenamed(fileId);
        return true;
    } else {
        // Rollback disk rename on DB failure
        if (file.isDir) QDir().rename(newPath, oldPath);
        else QFile::rename(newPath, oldPath);
        emit databaseError("Failed to update database");
        return false;
    }
}

int DatabaseManager::getOrCreateTag(const QString &tagName)
{
    QMutexLocker locker(&m_mutex);
    QString normalized = tagName.trimmed().toLower();
    if (normalized.isEmpty()) return -1;
    
    QSqlQuery check(m_database);
    check.prepare("SELECT id FROM tags WHERE name = :name");
    check.bindValue(":name", normalized);
    if (check.exec() && check.next()) {
        return check.value(0).toInt();
    }
    
    QSqlQuery query(m_database);
    query.prepare("INSERT INTO tags (name) VALUES (:name)");
    query.bindValue(":name", normalized);
    
    if (query.exec()) {
        invalidateTagCache();
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
    
    if (query.exec()) {
        invalidateTagCache();
        emit tagsUpdated(fileId);
        return true;
    }
    return false;
}

bool DatabaseManager::addTagsToFile(int fileId, const QStringList &tagNames)
{
    for (const QString &tagName : tagNames) {
        QStringList splitTags = tagName.split(',', Qt::SkipEmptyParts);
        for (const QString &tag : splitTags) {
            QString trimmedTag = tag.trimmed();
            if (trimmedTag.isEmpty()) continue;
            
            int tagId = getOrCreateTag(trimmedTag);
            if (tagId > 0) {
                QMutexLocker locker(&m_mutex);
                QSqlQuery query(m_database);
                query.prepare("INSERT OR IGNORE INTO file_tags (file_id, tag_id) VALUES (:fid, :tid)");
                query.bindValue(":fid", fileId);
                query.bindValue(":tid", tagId);
                query.exec();
            }
        }
    }
    
    invalidateTagCache();
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
    
    if (!m_tagCacheValid) {
        refreshTagCache();
    }
    
    QVariantList tags;
    tags.reserve(m_tagCache.size());
    for (const TagDTO& tag : m_tagCache) {
        QVariantMap map;
        map["id"] = tag.id;
        map["name"] = tag.name;
        map["count"] = tag.count;
        tags.append(map);
    }
    
    return tags;
}

void DatabaseManager::invalidateTagCache()
{
    m_tagCacheValid = false;
    emit globalTagsChanged();
}

void DatabaseManager::refreshTagCache()
{
    m_tagCache.clear();
    
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
            TagDTO tag;
            tag.id = query.value("id").toInt();
            tag.name = query.value("name").toString();
            tag.count = query.value("count").toInt();
            m_tagCache.append(tag);
        }
    }
    m_tagCacheValid = true;
}

QVariantList DatabaseManager::searchTags(const QString &keyword)
{
    QMutexLocker locker(&m_mutex);
    
    if (!m_tagCacheValid) {
        refreshTagCache();
    }
    
    QVariantList tags;
    if (keyword.isEmpty()) {
        for (const TagDTO& tag : m_tagCache) {
            QVariantMap map;
            map["id"] = tag.id;
            map["name"] = tag.name;
            map["count"] = tag.count;
            tags.append(map);
        }
        return tags;
    }
    
    for (const TagDTO& tag : m_tagCache) {
        if (tag.name.contains(keyword, Qt::CaseInsensitive)) {
            QVariantMap map;
            map["id"] = tag.id;
            map["name"] = tag.name;
            map["count"] = tag.count;
            tags.append(map);
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
    bool success = query.exec();
    
    if (success) {
        invalidateTagCache();
        emit tagsUpdated(fileId);
    }
    
    return success;
}

bool DatabaseManager::deleteTag(int tagId)
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("DELETE FROM tags WHERE id = :id");
    query.bindValue(":id", tagId);
    
    if (query.exec()) {
        invalidateTagCache();
        return true;
    }
    return false;
}

bool DatabaseManager::renameTag(int tagId, const QString &newName)
{
    QMutexLocker locker(&m_mutex);
    QString normalized = newName.trimmed().toLower();
    if (normalized.isEmpty()) return false;
    
    QSqlQuery check(m_database);
    check.prepare("SELECT id FROM tags WHERE name = :name");
    check.bindValue(":name", normalized);
    if (check.exec() && check.next()) {
        return false;
    }
    
    QSqlQuery query(m_database);
    query.prepare("UPDATE tags SET name = :name WHERE id = :id");
    query.bindValue(":name", normalized);
    query.bindValue(":id", tagId);
    
    if (query.exec()) {
        invalidateTagCache();
        return true;
    }
    return false;
}

bool DatabaseManager::mergeTags(int targetTagId, const QList<int> &sourceTagIds)
{
    QMutexLocker locker(&m_mutex);
    m_database.transaction();
    
    bool success = true;
    
    for (int sourceId : sourceTagIds) {
        if (sourceId == targetTagId) continue;
        
        QSqlQuery update(m_database);
        update.prepare("UPDATE OR IGNORE file_tags SET tag_id = :target WHERE tag_id = :source");
        update.bindValue(":target", targetTagId);
        update.bindValue(":source", sourceId);
        if (!update.exec()) success = false;
        
        QSqlQuery delAssoc(m_database);
        delAssoc.prepare("DELETE FROM file_tags WHERE tag_id = :source");
        delAssoc.bindValue(":source", sourceId);
        if (!delAssoc.exec()) success = false;
        
        QSqlQuery delTag(m_database);
        delTag.prepare("DELETE FROM tags WHERE id = :source");
        delTag.bindValue(":source", sourceId);
        if (!delTag.exec()) success = false;
    }
    
    if (success) {
        m_database.commit();
        invalidateTagCache();
        return true;
    } else {
        m_database.rollback();
        return false;
    }
}

bool DatabaseManager::removeEmptyTags()
{
    QMutexLocker locker(&m_mutex);
    
    QSqlQuery query(m_database);
    query.prepare("DELETE FROM tags WHERE id NOT IN (SELECT DISTINCT tag_id FROM file_tags)");
    
    if (query.exec()) {
        if (query.numRowsAffected() > 0) {
            invalidateTagCache();
        }
        return true;
    }
    return false;
}

QList<FileDTO> DatabaseManager::search(const QString &keyword, const QList<int> &tagIds)
{
    QMutexLocker locker(&m_mutex);
    QList<FileDTO> results;
    
    QString sql = "SELECT DISTINCT f.* FROM files f ";
    
    if (!tagIds.isEmpty()) {
        sql += "INNER JOIN file_tags ft ON f.id = ft.file_id ";
    }
    
    QStringList conditions;
    
    if (!keyword.isEmpty()) {
        conditions << "(f.filename LIKE :kw OR f.content_hash LIKE :kw)";
    }
    
    if (!tagIds.isEmpty()) {
        for (int id : tagIds) {
             conditions << QString("EXISTS (SELECT 1 FROM file_tags WHERE file_id = f.id AND tag_id = %1)").arg(id);
        }
    }
    
    if (!conditions.isEmpty()) {
        sql += " WHERE " + conditions.join(" AND ");
    }
    
    sql += " ORDER BY f.created_at DESC";
    
    QSqlQuery query(m_database);
    query.prepare(sql);
    
    if (!keyword.isEmpty()) {
        query.bindValue(":kw", "%" + keyword + "%");
    }
    
    if (query.exec()) {
        while (query.next()) {
            FileDTO f;
            f.id = query.value("id").toInt();
            f.contentHash = query.value("content_hash").toString();
            f.filename = query.value("filename").toString();
            f.filePath = query.value("file_path").toString();
            f.originalPath = query.value("original_path").toString();
            f.storageMode = query.value("storage_mode").toInt();
            f.isDir = query.value("is_dir").toBool();
            f.createdAt = query.value("created_at").toLongLong();
            results.append(f);
        }
    }
    
    return results;
}

QList<FileDTO> DatabaseManager::getAllFiles()
{
    return search("", {});
}

QVariantList DatabaseManager::getRecommendedTags(const QString &keyword, const QList<int> &tagIds)
{
    QMutexLocker locker(&m_mutex);
    if (!m_tagCacheValid) refreshTagCache();
    
    QVariantList results;
    int limit = 10;
    int count = 0;
    
    for (const TagDTO &tag : m_tagCache) {
        if (tagIds.contains(tag.id)) continue;
        if (!keyword.isEmpty() && !tag.name.contains(keyword, Qt::CaseInsensitive)) continue;
        
        QVariantMap map;
        map["id"] = tag.id;
        map["name"] = tag.name;
        map["count"] = tag.count;
        results.append(map);
        
        count++;
        if (count >= limit) break;
    }
    
    return results;
}

bool DatabaseManager::pushToQueue(int fileId)
{
    QMutexLocker locker(&m_mutex);
    QSqlQuery query(m_database);
    query.prepare("INSERT INTO processing_queue (file_id, created_at) VALUES (:fid, :time)");
    query.bindValue(":fid", fileId);
    query.bindValue(":time", QDateTime::currentMSecsSinceEpoch());
    bool success = query.exec();
    if (success) {
        qDebug() << "DB: Pushed file" << fileId << "to queue. Insert ID:" << query.lastInsertId().toInt();
    } else {
        qWarning() << "DB: Failed to push to queue:" << query.lastError().text();
    }
    return success;
}

QueueItemDTO DatabaseManager::popNextQueueItem()
{
    QMutexLocker locker(&m_mutex);
    QueueItemDTO item;
    
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM processing_queue WHERE status = 0 ORDER BY created_at ASC LIMIT 1");
    
    if (query.exec()) {
        if (query.next()) {
            item.id = query.value("id").toInt();
            item.fileId = query.value("file_id").toInt();
            item.status = 0;
            qDebug() << "DB: Popped item" << item.id << "for file" << item.fileId;
        } else {
            // qDebug() << "DB: No pending items.";
        }
    } else {
        qWarning() << "DB: Failed to pop item:" << query.lastError().text();
    }
    
    return item;
}

bool DatabaseManager::updateQueueStatus(int queueId, int status, const QString &errorLog)
{
    QMutexLocker locker(&m_mutex);
    QSqlQuery query(m_database);
    query.prepare("UPDATE processing_queue SET status = :status, error_log = :error WHERE id = :id");
    query.bindValue(":status", status);
    query.bindValue(":error", errorLog);
    query.bindValue(":id", queueId);
    return query.exec();
}

int DatabaseManager::getPendingQueueCount()
{
    QMutexLocker locker(&m_mutex);
    QSqlQuery query(m_database);
    if (query.exec("SELECT COUNT(*) FROM processing_queue WHERE status = 0 OR status = 1")) {
        if (query.next()) {
            return query.value(0).toInt();
        }
    }
    return 0;
}
