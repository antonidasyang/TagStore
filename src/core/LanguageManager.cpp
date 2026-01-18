#include "LanguageManager.h"
#include <QLocale>
#include <QQmlEngine>

LanguageManager& LanguageManager::instance()
{
    static LanguageManager instance;
    return instance;
}

LanguageManager::LanguageManager(QObject *parent)
    : QObject(parent)
    , m_settings("TagStore", "TagStore")
    , m_languageMode(System)
    , m_updateTrigger(0)
{
    initTranslations();
    
    // Load saved language mode
    m_languageMode = static_cast<LanguageMode>(m_settings.value("language/mode", System).toInt());
    applyLanguage();
}

void LanguageManager::setEngine(QQmlEngine* engine)
{
    m_engine = engine;
}

int LanguageManager::languageMode() const
{
    return static_cast<int>(m_languageMode);
}

void LanguageManager::setLanguageMode(int mode)
{
    LanguageMode newMode = static_cast<LanguageMode>(mode);
    if (m_languageMode != newMode) {
        m_languageMode = newMode;
        m_settings.setValue("language/mode", mode);
        applyLanguage();
        emit languageModeChanged();
    }
}

QString LanguageManager::currentLanguage() const
{
    return m_currentLocale;
}

QStringList LanguageManager::availableLanguages() const
{
    // Return translated language names
    return {t("System"), "English", "中文"};
}

QString LanguageManager::detectSystemLanguage() const
{
    QString locale = QLocale::system().name();
    if (locale.startsWith("zh")) {
        return "zh_CN";
    }
    return "en_US";
}

void LanguageManager::applyLanguage()
{
    QString oldLocale = m_currentLocale;
    
    switch (m_languageMode) {
    case System:
        m_currentLocale = detectSystemLanguage();
        break;
    case English:
        m_currentLocale = "en_US";
        break;
    case Chinese:
        m_currentLocale = "zh_CN";
        break;
    }
    
    // Always increment trigger to force UI refresh
    m_updateTrigger++;
    emit languageChanged();
    
    // Retranslate QML
    if (m_engine) {
        m_engine->retranslate();
    }
}

QString LanguageManager::t(const QString& text) const
{
    if (m_currentLocale == "zh_CN" && m_translations.contains("zh_CN")) {
        const auto& zhMap = m_translations.value("zh_CN");
        if (zhMap.contains(text)) {
            return zhMap.value(text);
        }
    }
    return text;
}

void LanguageManager::initTranslations()
{
    // Chinese translations
    QMap<QString, QString> zh;
    
    // Main
    zh["TagStore"] = "标签仓库";
    zh["Settings"] = "设置";
    zh["Import Files"] = "导入文件";
    zh["Index Folder"] = "索引文件夹";
    
    // Header
    zh["Search files..."] = "搜索文件...";
    zh["+ Import"] = "+ 导入";
    zh["🔗 Index"] = "🔗 索引";
    
    // Tag bar
    zh["Tags:"] = "标签:";
    zh["Clear"] = "清除";
    zh["Show All"] = "显示全部";
    
    // Results
    zh["No files in library"] = "库中没有文件";
    zh["Drop files here or click Import to get started"] = "拖放文件到这里或点击导入开始";
    zh[" files"] = " 个文件";
    zh["No tags yet"] = "暂无标签";
    zh["Enter tags separated by comma..."] = "输入标签，用逗号分隔...";
    zh["All Tags"] = "全部标签";
    
    // Context menu
    zh["Open"] = "打开";
    zh["Reveal in Explorer"] = "在资源管理器中显示";
    zh["Manage Tags"] = "管理标签";
    zh["Delete"] = "删除";
    
    // Tag dialog
    zh["Tags for this file:"] = "此文件的标签:";
    zh["Add new tag..."] = "添加新标签...";
    
    // Delete dialog
    zh["Delete File"] = "删除文件";
    zh["Are you sure you want to remove this file from the library?"] = "确定要从库中移除此文件吗？";
    
    // Settings
    zh["Appearance"] = "外观";
    zh["Theme:"] = "主题:";
    zh["Light"] = "浅色";
    zh["Dark"] = "深色";
    zh["System"] = "跟随系统";
    zh["Language:"] = "语言:";
    zh["Library"] = "库";
    zh["Library Path:"] = "库路径:";
    zh["Select Library Folder"] = "选择库文件夹";
    zh["OpenAI API"] = "OpenAI API";
    zh["Base URL:"] = "基础 URL:";
    zh["API Key:"] = "API 密钥:";
    zh["Model:"] = "模型:";
    
    // Drop
    zh["Drop files here to import"] = "拖放文件到这里以导入";
    zh["Hold Alt to index without moving"] = "按住 Alt 索引而不移动文件";
    zh["Release"] = "释放";
    zh["Drop Here"] = "拖放到这里";
    
    // Conflict
    zh["Duplicate File Detected"] = "检测到重复文件";
    zh["A file with the same content already exists:"] = "已存在相同内容的文件:";
    zh["New file: "] = "新文件: ";
    zh["What would you like to do?"] = "您想要怎么做？";
    zh["Skip"] = "跳过";
    zh["Import as Copy"] = "作为副本导入";
    zh["Add as Alias"] = "添加为别名";
    
    // Common buttons
    zh["OK"] = "确定";
    zh["Cancel"] = "取消";
    zh["Yes"] = "是";
    zh["No"] = "否";
    zh["Collapse"] = "收起";
    zh["Start"] = "开始";
    zh["Apply"] = "应用";
    
    // Tag filter bar
    zh["Filters:"] = "筛选:";
    zh["Suggested:"] = "推荐:";
    zh["Clear All"] = "清除全部";
    zh["Click tags on files or search to filter"] = "点击文件上的标签或搜索来筛选";
    
    // Multi-select
    zh["Selected:"] = "已选:";
    zh["Select files"] = "选择文件";
    zh["AI Tag"] = "AI 打标签";
    zh["Manual Tag"] = "手动打标签";
    
    // Batch dialogs
    zh["AI will analyze and generate tags for selected files."] = "AI 将分析并为所选文件生成标签。";
    zh["Processing..."] = "处理中...";
    zh["Add tags to all selected files:"] = "为所有选中的文件添加标签:";
    zh["Enter tags separated by comma..."] = "输入标签，用逗号分隔...";
    zh["Existing tags from all files:"] = "现有的所有标签:";
    
    m_translations["zh_CN"] = zh;
}
