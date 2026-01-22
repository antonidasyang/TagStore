#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QTranslator>
#include <QLocale>
#include <QLocalServer>
#include <QLocalSocket>
#include <QTextStream>
#include <QWindow>

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
    
    // --- Singleton Check ---
    const QString serverName = "TagStoreLocalServer";
    QLocalSocket socket;
    socket.connectToServer(serverName);
    
    if (socket.waitForConnected(500)) {
        // Instance exists, send command to show window
        QTextStream stream(&socket);
        stream << "SHOW";
        stream.flush();
        socket.waitForBytesWritten(1000);
        return 0; // Exit this instance
    }
    
    // Cleanup potentially stale server
    QLocalServer::removeServer(serverName);
    
    // Start Local Server
    QLocalServer server;
    if (!server.listen(serverName)) {
        qWarning() << "Failed to start local server:" << server.errorString();
    }
    // -----------------------

    app.setApplicationName("TagStore");
#ifdef APP_VERSION
    app.setApplicationVersion(APP_VERSION);
#else
    app.setApplicationVersion("1.0.0");
#endif
    app.setOrganizationName("TagStore");
    app.setWindowIcon(QIcon(":/icons/icon.png"));
    
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
    
    // --- Handle Singleton Commands ---
    QObject::connect(&server, &QLocalServer::newConnection, &app, [&server, &engine]() {
        QLocalSocket *clientConnection = server.nextPendingConnection();
        QObject::connect(clientConnection, &QLocalSocket::readyRead, [clientConnection, &engine]() {
            QTextStream stream(clientConnection);
            QString cmd = stream.readAll();
            
            if (cmd == "SHOW") {
                // Find main window and show it
                QObject *root = engine.rootObjects().first();
                QWindow *window = qobject_cast<QWindow*>(root);
                if (window) {
                    // We need to call show() and requestActivate()
                    // But if it's minimized to tray (visible=false), show() is needed.
                    // Invoking QML methods is safer if logic is complex.
                    
                    // Simple approach: set properties
                    window->setVisible(true);
                    window->requestActivate();
                    
                    // Also raise/alert
                    window->alert(0);
                }
            }
            clientConnection->deleteLater();
        });
    });
    // ---------------------------------
    
    // Ensure app quits when window closes
    app.setQuitOnLastWindowClosed(true);
    QObject::connect(&engine, &QQmlApplicationEngine::quit, &app, &QGuiApplication::quit);
    
    // Stop processor on exit
    QObject::connect(&app, &QGuiApplication::aboutToQuit, &llmProcessor, &LLMProcessor::stop);
    
    // Start LLM processor to handle AI tagging queue
    llmProcessor.start();
    
    return app.exec();
}