#ifndef LIBRARYMODEL_H
#define LIBRARYMODEL_H

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QHash>

struct FileItem {
    int id = -1;
    QString filename;
    QString filePath;
    QString contentHash;
    int storageMode = 0; // 0=Managed, 1=Referenced
    qint64 createdAt = 0;
    QStringList tags;
    bool isAITagged = false;
    bool isDir = false;
};

class LibraryModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString searchKeyword READ searchKeyword WRITE setSearchKeyword NOTIFY searchKeywordChanged)
    Q_PROPERTY(QList<int> selectedTagIds READ selectedTagIds WRITE setSelectedTagIds NOTIFY selectedTagIdsChanged)
    Q_PROPERTY(QVariantList recommendedTags READ recommendedTags NOTIFY recommendedTagsChanged)
    
public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        FilenameRole,
        FilePathRole,
        ContentHashRole,
        StorageModeRole,
        IsReferencedRole,
        CreatedAtRole,
        TagsRole,
        IsAITaggedRole,
        ThumbnailRole,
        IsDirRole
    };
    Q_ENUM(Roles)
    
    explicit LibraryModel(QObject *parent = nullptr);
    
    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    
    // Properties
    int count() const;
    QString searchKeyword() const;
    void setSearchKeyword(const QString &keyword);
    QList<int> selectedTagIds() const;
    void setSelectedTagIds(const QList<int> &tagIds);
    QVariantList recommendedTags() const;
    
    // Public methods
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void search();
    Q_INVOKABLE FileItem getFileAt(int index) const;
    Q_INVOKABLE int getFileIdAt(int index) const;
    Q_INVOKABLE QString getFilePathAt(int index) const;
    Q_INVOKABLE void updateFileTags(int fileId);
    
signals:
    void countChanged();
    void searchKeywordChanged();
    void selectedTagIdsChanged();
    void recommendedTagsChanged();
    void modelRefreshed();
    
public slots:
    void onFileAdded(int fileId);
    void onFileRemoved(int fileId);
    void onTagsUpdated(int fileId);
    
private:
    void loadAllFiles();
    void performSearch();
    FileItem fileFromDTO(int fileId);
    
    QList<FileItem> m_files;
    QString m_searchKeyword;
    QList<int> m_selectedTagIds;
    QVariantList m_recommendedTags;
};

#endif // LIBRARYMODEL_H
