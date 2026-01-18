#ifndef LIBRARYCONFIG_H
#define LIBRARYCONFIG_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QSettings>

class LibraryConfig : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString libraryPath READ libraryPath WRITE setLibraryPath NOTIFY libraryPathChanged)
    Q_PROPERTY(QString apiBaseUrl READ apiBaseUrl WRITE setApiBaseUrl NOTIFY apiBaseUrlChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString model READ model WRITE setModel NOTIFY modelChanged)
    Q_PROPERTY(QStringList cachedModels READ cachedModels WRITE setCachedModels NOTIFY cachedModelsChanged)
    
public:
    static LibraryConfig& instance();
    
    // Library paths
    QString libraryPath() const;
    Q_INVOKABLE void setLibraryPath(const QString &path);
    Q_INVOKABLE QString databasePath() const;
    Q_INVOKABLE QString generateStoragePath(const QString &filename) const;
    Q_INVOKABLE bool ensureDirectoryExists(const QString &path) const;
    
    // OpenAI API configuration
    QString apiBaseUrl() const;
    Q_INVOKABLE void setApiBaseUrl(const QString &url);
    
    QString apiKey() const;
    Q_INVOKABLE void setApiKey(const QString &key);
    
    QString model() const;
    Q_INVOKABLE void setModel(const QString &modelName);
    
    Q_INVOKABLE int maxTokens() const;
    Q_INVOKABLE void setMaxTokens(int tokens);
    
    Q_INVOKABLE double temperature() const;
    Q_INVOKABLE void setTemperature(double temp);
    
    // Cached models list
    QStringList cachedModels() const;
    Q_INVOKABLE void setCachedModels(const QStringList &models);
    
signals:
    void libraryPathChanged();
    void apiBaseUrlChanged();
    void apiKeyChanged();
    void modelChanged();
    void cachedModelsChanged();
    
private:
    LibraryConfig(QObject *parent = nullptr);
    ~LibraryConfig() = default;
    
    LibraryConfig(const LibraryConfig&) = delete;
    LibraryConfig& operator=(const LibraryConfig&) = delete;
    
    void loadSettings();
    void saveSettings();
    QString getDefaultLibraryPath() const;
    
    QSettings m_settings;
    QString m_libraryPath;
    QString m_apiBaseUrl;
    QString m_apiKey;
    QString m_model;
    int m_maxTokens;
    double m_temperature;
    QStringList m_cachedModels;
};

#endif // LIBRARYCONFIG_H
