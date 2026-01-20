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
    
    // Window geometry and state
    Q_PROPERTY(int windowX READ windowX WRITE setWindowX NOTIFY windowXChanged)
    Q_PROPERTY(int windowY READ windowY WRITE setWindowY NOTIFY windowYChanged)
    Q_PROPERTY(int windowWidth READ windowWidth WRITE setWindowWidth NOTIFY windowWidthChanged)
    Q_PROPERTY(int windowHeight READ windowHeight WRITE setWindowHeight NOTIFY windowHeightChanged)
    Q_PROPERTY(int windowMaximized READ windowMaximized WRITE setWindowMaximized NOTIFY windowMaximizedChanged)
    
    // AI Settings
    Q_PROPERTY(bool autoAiTag READ autoAiTag WRITE setAutoAiTag NOTIFY autoAiTagChanged)
    
    // Import Settings
    Q_PROPERTY(int defaultImportMode READ defaultImportMode WRITE setDefaultImportMode NOTIFY defaultImportModeChanged)
    Q_PROPERTY(bool startMinimized READ startMinimized WRITE setStartMinimized NOTIFY startMinimizedChanged)
    
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
    
    // Window geometry and state getters/setters
    int windowX() const;
    void setWindowX(int x);
    int windowY() const;
    void setWindowY(int y);
    int windowWidth() const;
    void setWindowWidth(int w);
    int windowHeight() const;
    void setWindowHeight(int h);
    int windowMaximized() const;
    void setWindowMaximized(int maximized);
    
    // AI Settings
    bool autoAiTag() const;
    Q_INVOKABLE void setAutoAiTag(bool enable);
    
    // Import Settings
    int defaultImportMode() const;
    Q_INVOKABLE void setDefaultImportMode(int mode);
    
    bool startMinimized() const;
    Q_INVOKABLE void setStartMinimized(bool enable);
    
signals:
    void libraryPathChanged();
    void apiBaseUrlChanged();
    void apiKeyChanged();
    void modelChanged();
    void cachedModelsChanged();
    void windowXChanged();
    void windowYChanged();
    void windowWidthChanged();
    void windowHeightChanged();
    void windowMaximizedChanged();
    void autoAiTagChanged();
    void defaultImportModeChanged();
    void startMinimizedChanged();
    
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
    
    int m_windowX;
    int m_windowY;
    int m_windowWidth;
    int m_windowHeight;
    int m_windowMaximized;
    
    bool m_autoAiTag;
    int m_defaultImportMode;
    bool m_startMinimized;
};

#endif // LIBRARYCONFIG_H
