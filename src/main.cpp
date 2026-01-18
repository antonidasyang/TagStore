#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QTranslator>
#include <QLocale>

#include "core/DatabaseManager.h"
#include "core/LibraryConfig.h"
#include "core/FileHasher.h"
#include "core/LLMClient.h"
#include "core/ThemeManager.h"
#include "core/LanguageManager.h"
#include "models/LibraryModel.h"
#include "viewmodels/FileIngestor.h"
#include "workers/LLMProcessor.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    
    app.setApplicationName("TagStore");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("TagStore");
    app.setWindowIcon(QIcon(":/icons/icon.svg"));
    
    // Initialize core components
    LibraryConfig &config = LibraryConfig::instance();
    DatabaseManager &db = DatabaseManager::instance();
    ThemeManager &theme = ThemeManager::instance();
    LanguageManager &lang = LanguageManager::instance();
    
    // Initialize database
    if (!db.initialize(config.databasePath())) {
        qCritical() << "Failed to initialize database";
        return -1;
    }
    
    // Create models and controllers
    LibraryModel libraryModel;
    FileIngestor fileIngestor;
    LLMClient llmClient;
    LLMProcessor llmProcessor(&llmClient);
    
    // Setup QML engine
    QQmlApplicationEngine engine;
    
    // Set engine for language manager
    lang.setEngine(&engine);
    
    // Expose C++ objects to QML
    engine.rootContext()->setContextProperty("libraryConfig", &config);
    engine.rootContext()->setContextProperty("databaseManager", &db);
    engine.rootContext()->setContextProperty("themeManager", &theme);
    engine.rootContext()->setContextProperty("languageManager", &lang);
    engine.rootContext()->setContextProperty("libraryModel", &libraryModel);
    engine.rootContext()->setContextProperty("fileIngestor", &fileIngestor);
    engine.rootContext()->setContextProperty("llmClient", &llmClient);
    engine.rootContext()->setContextProperty("llmProcessor", &llmProcessor);
    
    // Load main QML file
    using namespace Qt::StringLiterals;
    const QUrl url(u"qrc:/TagStore/qml/Main.qml"_s);
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);
    
    engine.load(url);
    
    if (engine.rootObjects().isEmpty()) {
        return -1;
    }
    
    // Start LLM processor to handle AI tagging queue
    llmProcessor.start();
    
    return app.exec();
}
