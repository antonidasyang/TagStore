#ifndef LANGUAGEMANAGER_H
#define LANGUAGEMANAGER_H

#include <QObject>
#include <QTranslator>
#include <QSettings>
#include <QGuiApplication>

class QQmlEngine;

class LanguageManager : public QObject
{
    Q_OBJECT
    
    Q_PROPERTY(int languageMode READ languageMode WRITE setLanguageMode NOTIFY languageModeChanged)
    Q_PROPERTY(QString currentLanguage READ currentLanguage NOTIFY languageChanged)
    Q_PROPERTY(QStringList availableLanguages READ availableLanguages NOTIFY languageChanged)
    Q_PROPERTY(int updateTrigger READ updateTrigger NOTIFY languageChanged)
    
public:
    enum LanguageMode {
        System = 0,
        English = 1,
        Chinese = 2
    };
    Q_ENUM(LanguageMode)
    
    static LanguageManager& instance();
    
    void setEngine(QQmlEngine* engine);
    
    int languageMode() const;
    Q_INVOKABLE void setLanguageMode(int mode);
    
    QString currentLanguage() const;
    QStringList availableLanguages() const;
    int updateTrigger() const { return m_updateTrigger; }
    
    Q_INVOKABLE QString t(const QString& text) const;
    
signals:
    void languageModeChanged();
    void languageChanged();
    
private:
    LanguageManager(QObject *parent = nullptr);
    void loadTranslation(const QString& locale);
    QString detectSystemLanguage() const;
    void applyLanguage();
    
    QSettings m_settings;
    QTranslator m_translator;
    QQmlEngine* m_engine = nullptr;
    LanguageMode m_languageMode;
    QString m_currentLocale;
    int m_updateTrigger = 0;
    
    // Simple translation map for embedded translations
    QMap<QString, QMap<QString, QString>> m_translations;
    void initTranslations();
};

#endif // LANGUAGEMANAGER_H
