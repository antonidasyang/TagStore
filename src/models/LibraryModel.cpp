#include "LibraryModel.h"
#include "core/DatabaseManager.h"
#include <QDebug>

LibraryModel::LibraryModel(QObject *parent)
    : QAbstractListModel(parent)
{
    // Connect to database signals with QueuedConnection for thread safety
    DatabaseManager &db = DatabaseManager::instance();
    connect(&db, &DatabaseManager::fileAdded, this, &LibraryModel::onFileAdded, Qt::QueuedConnection);
    connect(&db, &DatabaseManager::fileRemoved, this, &LibraryModel::onFileRemoved, Qt::QueuedConnection);
    connect(&db, &DatabaseManager::tagsUpdated, this, &LibraryModel::onTagsUpdated, Qt::QueuedConnection);
    connect(&db, &DatabaseManager::globalTagsChanged, this, &LibraryModel::refresh, Qt::QueuedConnection);
    
    // Initial load
    loadAllFiles();
}

int LibraryModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_files.count();
}

QVariant LibraryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_files.count()) {
        return QVariant();
    }
    
    const FileItem &file = m_files.at(index.row());
    
    switch (role) {
    case IdRole:
        return file.id;
    case FilenameRole:
        return file.filename;
    case FilePathRole:
        return file.filePath;
    case ContentHashRole:
        return file.contentHash;
    case StorageModeRole:
        return file.storageMode;
    case IsReferencedRole:
        return file.storageMode == 1;
    case CreatedAtRole:
        return file.createdAt;
    case TagsRole:
        return file.tags;
    case IsAITaggedRole:
        return file.isAITagged;
    case ThumbnailRole:
        // Return file path for now, thumbnail generation can be added later
        return file.filePath;
    case IsDirRole:
        return file.isDir;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> LibraryModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IdRole] = "fileId";
    roles[FilenameRole] = "filename";
    roles[FilePathRole] = "filePath";
    roles[ContentHashRole] = "contentHash";
    roles[StorageModeRole] = "storageMode";
    roles[IsReferencedRole] = "isReferenced";
    roles[CreatedAtRole] = "createdAt";
    roles[TagsRole] = "tags";
    roles[IsAITaggedRole] = "isAITagged";
    roles[ThumbnailRole] = "thumbnail";
    roles[IsDirRole] = "isDir";
    return roles;
}

int LibraryModel::count() const
{
    return m_files.count();
}

QString LibraryModel::searchKeyword() const
{
    return m_searchKeyword;
}

void LibraryModel::setSearchKeyword(const QString &keyword)
{
    if (m_searchKeyword != keyword) {
        m_searchKeyword = keyword;
        emit searchKeywordChanged();
        performSearch();
    }
}

QList<int> LibraryModel::selectedTagIds() const
{
    return m_selectedTagIds;
}

void LibraryModel::setSelectedTagIds(const QList<int> &tagIds)
{
    if (m_selectedTagIds != tagIds) {
        m_selectedTagIds = tagIds;
        emit selectedTagIdsChanged();
        performSearch();
    }
}

QVariantList LibraryModel::recommendedTags() const
{
    return m_recommendedTags;
}

void LibraryModel::refresh()
{
    if (m_searchKeyword.isEmpty() && m_selectedTagIds.isEmpty()) {
        loadAllFiles();
    } else {
        performSearch();
    }
    emit modelRefreshed();
}

void LibraryModel::search()
{
    performSearch();
}

FileItem LibraryModel::getFileAt(int index) const
{
    if (index >= 0 && index < m_files.count()) {
        return m_files.at(index);
    }
    return FileItem();
}

int LibraryModel::getFileIdAt(int index) const
{
    if (index >= 0 && index < m_files.count()) {
        return m_files.at(index).id;
    }
    return -1;
}

QString LibraryModel::getFilePathAt(int index) const
{
    if (index >= 0 && index < m_files.count()) {
        return m_files.at(index).filePath;
    }
    return QString();
}

void LibraryModel::updateFileTags(int fileId)
{
    for (int i = 0; i < m_files.count(); ++i) {
        if (m_files[i].id == fileId) {
            m_files[i].tags = DatabaseManager::instance().getTagsForFile(fileId);
            m_files[i].isAITagged = !m_files[i].tags.isEmpty();
            QModelIndex idx = index(i);
            emit dataChanged(idx, idx, {TagsRole, IsAITaggedRole});
            break;
        }
    }
}

void LibraryModel::onFileAdded(int fileId)
{
    FileItem item = fileFromDTO(fileId);
    if (item.id > 0) {
        beginInsertRows(QModelIndex(), 0, 0);
        m_files.prepend(item);
        endInsertRows();
        emit countChanged();
    }
}

void LibraryModel::onFileRemoved(int fileId)
{
    for (int i = 0; i < m_files.count(); ++i) {
        if (m_files[i].id == fileId) {
            beginRemoveRows(QModelIndex(), i, i);
            m_files.removeAt(i);
            endRemoveRows();
            emit countChanged();
            break;
        }
    }
}

void LibraryModel::onTagsUpdated(int fileId)
{
    updateFileTags(fileId);
}

void LibraryModel::loadAllFiles()
{
    beginResetModel();
    m_files.clear();
    
    QList<FileDTO> dtos = DatabaseManager::instance().getAllFiles();
    for (const FileDTO &dto : dtos) {
        FileItem item;
        item.id = dto.id;
        item.filename = dto.filename;
        item.filePath = dto.filePath;
        item.contentHash = dto.contentHash;
        item.storageMode = dto.storageMode;
        item.createdAt = dto.createdAt;
        item.isDir = dto.isDir;
        item.tags = DatabaseManager::instance().getTagsForFile(dto.id);
        item.isAITagged = !item.tags.isEmpty();
        m_files.append(item);
    }
    
    m_recommendedTags = DatabaseManager::instance().getRecommendedTags(QString(), QList<int>());
    emit recommendedTagsChanged();
    
    endResetModel();
    emit countChanged();
}

void LibraryModel::performSearch()
{
    beginResetModel();
    m_files.clear();
    
    QList<FileDTO> dtos = DatabaseManager::instance().search(m_searchKeyword, m_selectedTagIds);
    for (const FileDTO &dto : dtos) {
        FileItem item;
        item.id = dto.id;
        item.filename = dto.filename;
        item.filePath = dto.filePath;
        item.contentHash = dto.contentHash;
        item.storageMode = dto.storageMode;
        item.createdAt = dto.createdAt;
        item.isDir = dto.isDir;
        item.tags = DatabaseManager::instance().getTagsForFile(dto.id);
        item.isAITagged = !item.tags.isEmpty();
        m_files.append(item);
    }
    
    m_recommendedTags = DatabaseManager::instance().getRecommendedTags(m_searchKeyword, m_selectedTagIds);
    emit recommendedTagsChanged();
    
    endResetModel();
    emit countChanged();
}

FileItem LibraryModel::fileFromDTO(int fileId)
{
    FileItem item;
    FileDTO dto = DatabaseManager::instance().getFileById(fileId);
    
    if (dto.id > 0) {
        item.id = dto.id;
        item.filename = dto.filename;
        item.filePath = dto.filePath;
        item.contentHash = dto.contentHash;
        item.storageMode = dto.storageMode;
        item.createdAt = dto.createdAt;
        item.isDir = dto.isDir;
        item.tags = DatabaseManager::instance().getTagsForFile(dto.id);
        item.isAITagged = !item.tags.isEmpty();
    }
    
    return item;
}
