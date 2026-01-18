#ifndef THEMEMANAGER_H
#define THEMEMANAGER_H

#include <QObject>
#include <QColor>
#include <QSettings>

class ThemeManager : public QObject
{
    Q_OBJECT
    
    // Theme mode
    Q_PROPERTY(int themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
    Q_PROPERTY(bool isDark READ isDark NOTIFY isDarkChanged)
    
    // Colors
    Q_PROPERTY(QColor background READ background NOTIFY colorsChanged)
    Q_PROPERTY(QColor surface READ surface NOTIFY colorsChanged)
    Q_PROPERTY(QColor surfaceHover READ surfaceHover NOTIFY colorsChanged)
    Q_PROPERTY(QColor primary READ primary NOTIFY colorsChanged)
    Q_PROPERTY(QColor primaryHover READ primaryHover NOTIFY colorsChanged)
    Q_PROPERTY(QColor primaryLight READ primaryLight NOTIFY colorsChanged)
    Q_PROPERTY(QColor textPrimary READ textPrimary NOTIFY colorsChanged)
    Q_PROPERTY(QColor textSecondary READ textSecondary NOTIFY colorsChanged)
    Q_PROPERTY(QColor textMuted READ textMuted NOTIFY colorsChanged)
    Q_PROPERTY(QColor border READ border NOTIFY colorsChanged)
    Q_PROPERTY(QColor borderLight READ borderLight NOTIFY colorsChanged)
    Q_PROPERTY(QColor success READ success NOTIFY colorsChanged)
    Q_PROPERTY(QColor purple READ purple NOTIFY colorsChanged)
    Q_PROPERTY(QColor shadow READ shadow NOTIFY colorsChanged)
    
public:
    enum ThemeMode {
        Light = 0,
        Dark = 1,
        System = 2
    };
    Q_ENUM(ThemeMode)
    
    static ThemeManager& instance();
    
    int themeMode() const;
    Q_INVOKABLE void setThemeMode(int mode);
    
    bool isDark() const;
    
    // Color getters
    QColor background() const;
    QColor surface() const;
    QColor surfaceHover() const;
    QColor primary() const;
    QColor primaryHover() const;
    QColor primaryLight() const;
    QColor textPrimary() const;
    QColor textSecondary() const;
    QColor textMuted() const;
    QColor border() const;
    QColor borderLight() const;
    QColor success() const;
    QColor purple() const;
    QColor shadow() const;
    
signals:
    void themeModeChanged();
    void isDarkChanged();
    void colorsChanged();
    
private:
    ThemeManager(QObject *parent = nullptr);
    void updateSystemTheme();
    void applyTheme();
    bool detectSystemDarkMode() const;
    
    QSettings m_settings;
    ThemeMode m_themeMode;
    bool m_isDark;
    
    // Light theme colors
    struct LightColors {
        QColor background{"#f8fafc"};
        QColor surface{"#ffffff"};
        QColor surfaceHover{"#f1f5f9"};
        QColor primary{"#2563eb"};
        QColor primaryHover{"#1d4ed8"};
        QColor primaryLight{"#eff6ff"};
        QColor textPrimary{"#1e293b"};
        QColor textSecondary{"#475569"};
        QColor textMuted{"#94a3b8"};
        QColor border{"#e2e8f0"};
        QColor borderLight{"#f1f5f9"};
        QColor success{"#10b981"};
        QColor purple{"#8b5cf6"};
        QColor shadow{"#10000000"};
    } m_light;
    
    // Dark theme colors
    struct DarkColors {
        QColor background{"#0f172a"};
        QColor surface{"#1e293b"};
        QColor surfaceHover{"#334155"};
        QColor primary{"#3b82f6"};
        QColor primaryHover{"#60a5fa"};
        QColor primaryLight{"#1e3a5f"};
        QColor textPrimary{"#f1f5f9"};
        QColor textSecondary{"#cbd5e1"};
        QColor textMuted{"#64748b"};
        QColor border{"#334155"};
        QColor borderLight{"#1e293b"};
        QColor success{"#34d399"};
        QColor purple{"#a78bfa"};
        QColor shadow{"#40000000"};
    } m_dark;
};

#endif // THEMEMANAGER_H
