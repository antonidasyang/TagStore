#include "LibraryConfig.h"
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QFileInfo>
#include <QCoreApplication>

LibraryConfig& LibraryConfig::instance()
{
    static LibraryConfig instance;
    return instance;
}

LibraryConfig::LibraryConfig(QObject *parent)
    : QObject(parent)
    , m_settings("TagStore", "TagStore")
    , m_maxTokens(1000)
    , m_temperature(0.3)
{
    loadSettings();
}

void LibraryConfig::loadSettings()
{
    m_libraryPath = m_settings.value("library/path", getDefaultLibraryPath()).toString();
    m_apiBaseUrl = m_settings.value("api/baseUrl", "https://api.openai.com/v1").toString();
    m_apiKey = m_settings.value("api/key", qEnvironmentVariable("OPENAI_API_KEY")).toString();
    m_model = m_settings.value("api/model", "gpt-4o-mini").toString();
    m_maxTokens = m_settings.value("api/maxTokens", 1000).toInt();
    m_temperature = m_settings.value("api/temperature", 0.3).toDouble();
    m_cachedModels = m_settings.value("api/cachedModels", QStringList{"gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"}).toStringList();
    
    // Window settings
    m_windowX = m_settings.value("window/x", -1).toInt();
    m_windowY = m_settings.value("window/y", -1).toInt();
    m_windowWidth = m_settings.value("window/width", 1200).toInt();
    m_windowHeight = m_settings.value("window/height", 800).toInt();
    m_windowMaximized = m_settings.value("window/maximized", 0).toInt();
    
    // AI settings
    m_autoAiTag = m_settings.value("ai/autoTag", true).toBool();
    
    // Import settings
    m_defaultImportMode = m_settings.value("import/defaultMode", 0).toInt();
    
    // Startup settings
    m_startMinimized = m_settings.value("startup/minimized", false).toBool();
    
    // Ensure library directory exists
    ensureDirectoryExists(m_libraryPath);
}

void LibraryConfig::saveSettings()
{
    m_settings.setValue("library/path", m_libraryPath);
    m_settings.setValue("api/baseUrl", m_apiBaseUrl);
    m_settings.setValue("api/key", m_apiKey);
    m_settings.setValue("api/model", m_model);
    m_settings.setValue("api/maxTokens", m_maxTokens);
    m_settings.setValue("api/temperature", m_temperature);
    m_settings.setValue("api/cachedModels", m_cachedModels);
    
    m_settings.setValue("window/x", m_windowX);
    m_settings.setValue("window/y", m_windowY);
    m_settings.setValue("window/width", m_windowWidth);
    m_settings.setValue("window/height", m_windowHeight);
    m_settings.setValue("window/maximized", m_windowMaximized);
    
    m_settings.setValue("ai/autoTag", m_autoAiTag);
    m_settings.setValue("import/defaultMode", m_defaultImportMode);
    m_settings.setValue("startup/minimized", m_startMinimized);
    
    m_settings.sync();
}

QString LibraryConfig::getDefaultLibraryPath() const
{
    QString documentsPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    return QDir(documentsPath).filePath("TagStore_Library");
}

QString LibraryConfig::libraryPath() const
{
    return m_libraryPath;
}

void LibraryConfig::setLibraryPath(const QString &path)
{
    if (m_libraryPath != path) {
        m_libraryPath = path;
        ensureDirectoryExists(m_libraryPath);
        saveSettings();
        emit libraryPathChanged();
    }
}

QString LibraryConfig::databasePath() const
{
    return QDir(m_libraryPath).filePath("tagstore.db");
}

QString LibraryConfig::generateStoragePath(const QString &filename) const
{
    // Generate path in YYYY/MM/ structure
    QDateTime now = QDateTime::currentDateTime();
    QString year = now.toString("yyyy");
    QString month = now.toString("MM");
    
    QString relativePath = QDir(m_libraryPath).filePath(year);
    relativePath = QDir(relativePath).filePath(month);
    
    ensureDirectoryExists(relativePath);
    
    // Handle filename collisions
    QString baseName = QFileInfo(filename).completeBaseName();
    QString suffix = QFileInfo(filename).suffix();
    QString targetPath = QDir(relativePath).filePath(filename);
    
    int counter = 1;
    while (QFile::exists(targetPath)) {
        QString newFilename = QString("%1 (%2).%3").arg(baseName).arg(counter).arg(suffix);
        targetPath = QDir(relativePath).filePath(newFilename);
        counter++;
    }
    
    return targetPath;
}

bool LibraryConfig::ensureDirectoryExists(const QString &path) const
{
    QDir dir(path);
    if (!dir.exists()) {
        return dir.mkpath(".");
    }
    return true;
}

QString LibraryConfig::apiBaseUrl() const
{
    return m_apiBaseUrl;
}

void LibraryConfig::setApiBaseUrl(const QString &url)
{
    if (m_apiBaseUrl != url) {
        m_apiBaseUrl = url;
        saveSettings();
        emit apiBaseUrlChanged();
    }
}

QString LibraryConfig::apiKey() const
{
    return m_apiKey;
}

void LibraryConfig::setApiKey(const QString &key)
{
    if (m_apiKey != key) {
        m_apiKey = key;
        saveSettings();
        emit apiKeyChanged();
    }
}

QString LibraryConfig::model() const
{
    return m_model;
}

void LibraryConfig::setModel(const QString &modelName)
{
    if (m_model != modelName) {
        m_model = modelName;
        saveSettings();
        emit modelChanged();
    }
}

int LibraryConfig::maxTokens() const
{
    return m_maxTokens;
}

void LibraryConfig::setMaxTokens(int tokens)
{
    if (m_maxTokens != tokens) {
        m_maxTokens = tokens;
        saveSettings();
    }
}

double LibraryConfig::temperature() const
{
    return m_temperature;
}

void LibraryConfig::setTemperature(double temp)
{
    if (m_temperature != temp) {
        m_temperature = temp;
        saveSettings();
    }
}

QStringList LibraryConfig::cachedModels() const
{
    return m_cachedModels;
}

void LibraryConfig::setCachedModels(const QStringList &models)
{
    if (m_cachedModels != models) {
        m_cachedModels = models;
        saveSettings();
        emit cachedModelsChanged();
    }
}

int LibraryConfig::windowX() const { return m_windowX; }
void LibraryConfig::setWindowX(int x)
{
    if (m_windowX != x) {
        m_windowX = x;
        saveSettings();
        emit windowXChanged();
    }
}

int LibraryConfig::windowY() const { return m_windowY; }
void LibraryConfig::setWindowY(int y)
{
    if (m_windowY != y) {
        m_windowY = y;
        saveSettings();
        emit windowYChanged();
    }
}

int LibraryConfig::windowWidth() const { return m_windowWidth; }
void LibraryConfig::setWindowWidth(int w)
{
    if (m_windowWidth != w) {
        m_windowWidth = w;
        saveSettings();
        emit windowWidthChanged();
    }
}

int LibraryConfig::windowHeight() const { return m_windowHeight; }
void LibraryConfig::setWindowHeight(int h)
{
    if (m_windowHeight != h) {
        m_windowHeight = h;
        saveSettings();
        emit windowHeightChanged();
    }
}

int LibraryConfig::windowMaximized() const { return m_windowMaximized; }
void LibraryConfig::setWindowMaximized(int maximized)
{
    if (m_windowMaximized != maximized) {
        m_windowMaximized = maximized;
        saveSettings();
        emit windowMaximizedChanged();
    }
}

bool LibraryConfig::autoAiTag() const { return m_autoAiTag; }
void LibraryConfig::setAutoAiTag(bool enable)
{
    if (m_autoAiTag != enable) {
        m_autoAiTag = enable;
        saveSettings();
        emit autoAiTagChanged();
    }
}

int LibraryConfig::defaultImportMode() const { return m_defaultImportMode; }
void LibraryConfig::setDefaultImportMode(int mode)
{
    if (m_defaultImportMode != mode) {
        m_defaultImportMode = mode;
        saveSettings();
        emit defaultImportModeChanged();
    }
}

bool LibraryConfig::startMinimized() const { return m_startMinimized; }
void LibraryConfig::setStartMinimized(bool enable)
{
    if (m_startMinimized != enable) {
        m_startMinimized = enable;
        saveSettings();
        emit startMinimizedChanged();
    }
}
