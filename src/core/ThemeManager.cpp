#include "ThemeManager.h"
#include <QGuiApplication>
#include <QStyleHints>

ThemeManager& ThemeManager::instance()
{
    static ThemeManager instance;
    return instance;
}

ThemeManager::ThemeManager(QObject *parent)
    : QObject(parent)
    , m_settings("TagStore", "TagStore")
    , m_themeMode(System)
    , m_isDark(false)
{
    // Load saved theme mode
    m_themeMode = static_cast<ThemeMode>(m_settings.value("theme/mode", System).toInt());
    
    // Connect to system theme changes
    if (QGuiApplication::styleHints()) {
        connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged,
                this, [this]() {
                    if (m_themeMode == System) {
                        updateSystemTheme();
                    }
                });
    }
    
    applyTheme();
}

int ThemeManager::themeMode() const
{
    return static_cast<int>(m_themeMode);
}

void ThemeManager::setThemeMode(int mode)
{
    ThemeMode newMode = static_cast<ThemeMode>(mode);
    if (m_themeMode != newMode) {
        m_themeMode = newMode;
        m_settings.setValue("theme/mode", mode);
        applyTheme();
        emit themeModeChanged();
    }
}

bool ThemeManager::isDark() const
{
    return m_isDark;
}

void ThemeManager::updateSystemTheme()
{
    bool wasDark = m_isDark;
    m_isDark = detectSystemDarkMode();
    
    if (wasDark != m_isDark) {
        emit isDarkChanged();
        emit colorsChanged();
    }
}

void ThemeManager::applyTheme()
{
    bool wasDark = m_isDark;
    
    switch (m_themeMode) {
    case Light:
        m_isDark = false;
        break;
    case Dark:
        m_isDark = true;
        break;
    case System:
        m_isDark = detectSystemDarkMode();
        break;
    }
    
    if (wasDark != m_isDark) {
        emit isDarkChanged();
    }
    emit colorsChanged();
}

bool ThemeManager::detectSystemDarkMode() const
{
    if (QGuiApplication::styleHints()) {
        return QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    }
    return false;
}

// Color getters
QColor ThemeManager::background() const { return m_isDark ? m_dark.background : m_light.background; }
QColor ThemeManager::surface() const { return m_isDark ? m_dark.surface : m_light.surface; }
QColor ThemeManager::surfaceHover() const { return m_isDark ? m_dark.surfaceHover : m_light.surfaceHover; }
QColor ThemeManager::primary() const { return m_isDark ? m_dark.primary : m_light.primary; }
QColor ThemeManager::primaryHover() const { return m_isDark ? m_dark.primaryHover : m_light.primaryHover; }
QColor ThemeManager::primaryLight() const { return m_isDark ? m_dark.primaryLight : m_light.primaryLight; }
QColor ThemeManager::textPrimary() const { return m_isDark ? m_dark.textPrimary : m_light.textPrimary; }
QColor ThemeManager::textSecondary() const { return m_isDark ? m_dark.textSecondary : m_light.textSecondary; }
QColor ThemeManager::textMuted() const { return m_isDark ? m_dark.textMuted : m_light.textMuted; }
QColor ThemeManager::border() const { return m_isDark ? m_dark.border : m_light.border; }
QColor ThemeManager::borderLight() const { return m_isDark ? m_dark.borderLight : m_light.borderLight; }
QColor ThemeManager::success() const { return m_isDark ? m_dark.success : m_light.success; }
QColor ThemeManager::purple() const { return m_isDark ? m_dark.purple : m_light.purple; }
QColor ThemeManager::shadow() const { return m_isDark ? m_dark.shadow : m_light.shadow; }
