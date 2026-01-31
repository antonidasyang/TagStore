#include "LLMProcessor.h"
#include "TextExtractor.h"
#include "core/LLMClient.h"
#include "core/DatabaseManager.h"
#include <QDebug>
#include <QDateTime>

LLMProcessor::LLMProcessor(LLMClient *client, QObject *parent)
    : QObject(parent)
    , m_llmClient(client)
    , m_textExtractor(new TextExtractor()) // Worker object, no parent
    , m_workerThread(new QThread(this))
    , m_pollTimer(new QTimer(this))
    , m_isRunning(false)
    , m_isExtracting(false)
    , m_currentQueueId(-1)
    , m_currentFileId(-1)
{
    // Move extractor to worker thread
    m_textExtractor->moveToThread(m_workerThread);
    
    // Connect extraction signals
    connect(this, &LLMProcessor::startExtraction, m_textExtractor, &TextExtractor::startExtraction);
    connect(m_textExtractor, &TextExtractor::extractionFinished, this, &LLMProcessor::onExtractionFinished);
    connect(m_textExtractor, &TextExtractor::extractionError, this, &LLMProcessor::onExtractionError);
    
    // Start worker thread
    m_workerThread->start();
    
    connect(m_pollTimer, &QTimer::timeout, this, &LLMProcessor::pollQueue);
    connect(m_llmClient, &LLMClient::tagsGenerated, this, &LLMProcessor::onTagsGenerated);
    connect(m_llmClient, &LLMClient::errorOccurred, this, &LLMProcessor::onLLMError);
    connect(m_llmClient, &LLMClient::isProcessingChanged, this, &LLMProcessor::isBusyChanged);
    
    // Poll every 2 seconds
    m_pollTimer->setInterval(2000);
}

LLMProcessor::~LLMProcessor()
{
    stop();
    m_workerThread->quit();
    m_workerThread->wait();
}

bool LLMProcessor::isRunning() const
{
    return m_isRunning;
}

int LLMProcessor::pendingCount() const
{
    return DatabaseManager::instance().getPendingQueueCount();
}

void LLMProcessor::start()
{
    if (!m_isRunning) {
        m_isRunning = true;
        m_pollTimer->start();
        emit isRunningChanged();
        qInfo() << "LLM Processor started";
        
        // Process immediately if there are pending items
        pollQueue();
    }
}

void LLMProcessor::stop()
{
    if (m_isRunning) {
        m_isRunning = false;
        m_pollTimer->stop();
        m_llmClient->cancelRequest();
        emit isRunningChanged();
        qInfo() << "LLM Processor stopped";
    }
}

bool LLMProcessor::isBusy() const
{
    return m_isExtracting || (m_llmClient && m_llmClient->isProcessing());
}

void LLMProcessor::processNow()
{
    if (m_isRunning && !isBusy()) {
        pollQueue();
    }
}

void LLMProcessor::pollQueue()
{
    qDebug() << "Poll Queue: Running:" << m_isRunning << "Busy:" << isBusy() << "Configured:" << m_llmClient->isConfigured();

    if (!m_isRunning || isBusy()) {
        return;
    }
    
    if (!m_llmClient->isConfigured()) {
        // Only log once per minute to avoid spam
        static qint64 lastLog = 0;
        qint64 now = QDateTime::currentMSecsSinceEpoch();
        if (now - lastLog > 60000) {
            qDebug() << "LLM client not configured, skipping processing. "
                     << "Please configure API key, base URL, and model in Settings.";
            lastLog = now;
        }
        return;
    }
    
    // Get next pending item
    QueueItemDTO item = DatabaseManager::instance().popNextQueueItem();
    
    if (item.id > 0) {
        qInfo() << "Processing queue item" << item.id << "for file" << item.fileId;
        processItem(item.id, item.fileId);
        emit pendingCountChanged();
    }
}

void LLMProcessor::processItem(int queueId, int fileId)
{
    m_currentQueueId = queueId;
    m_currentFileId = fileId;
    m_isExtracting = true;
    emit isBusyChanged();
    
    // Update status to processing
    DatabaseManager::instance().updateQueueStatus(queueId, 1); // 1 = Processing
    
    // Get file info
    FileDTO file = DatabaseManager::instance().getFileById(fileId);
    if (file.id < 0) {
        m_isExtracting = false;
        onLLMError(fileId, "File not found in database");
        return;
    }
    
    emit processingStarted(fileId);
    
    // Start extraction in worker thread
    emit startExtraction(fileId, file.filePath);
}

void LLMProcessor::onExtractionFinished(int fileId, const QString &text)
{
    qDebug() << "Entering onExtractionFinished for file" << fileId << "Text length:" << text.length();
    if (fileId != m_currentFileId) return;
    
    m_isExtracting = false;
    emit isBusyChanged();
    
    if (m_isRunning) {
        QString finalText = text;
        if (finalText.isEmpty()) {
             // Fallback
             FileDTO file = DatabaseManager::instance().getFileById(fileId);
             finalText = QString("Filename: %1").arg(file.filename);
        }
        
        // Get top 100 existing tags to guide the AI
        QStringList existingTags;
        QVariantList tags = DatabaseManager::instance().getAllTags();
        int tagLimit = qMin(tags.size(), 100);
        for (int i = 0; i < tagLimit; ++i) {
            existingTags.append(tags.at(i).toMap()["name"].toString());
        }
        
        qDebug() << "Calling generateTags for file" << fileId;
        m_llmClient->generateTags(finalText, fileId, existingTags);
    }
}

void LLMProcessor::onExtractionError(int fileId, const QString &error)
{
    if (fileId != m_currentFileId) return;
    
    qWarning() << "Extraction error for file" << fileId << ":" << error;
    m_isExtracting = false;
    emit isBusyChanged();
    
    // Fallback on error
    if (m_isRunning) {
        FileDTO file = DatabaseManager::instance().getFileById(fileId);
        QString finalText = QString("Filename: %1").arg(file.filename);
        
        // Get top 100 existing tags
        QStringList existingTags;
        QVariantList tags = DatabaseManager::instance().getAllTags();
        int tagLimit = qMin(tags.size(), 100);
        for (int i = 0; i < tagLimit; ++i) {
            existingTags.append(tags.at(i).toMap()["name"].toString());
        }
        
        qDebug() << "Calling generateTags for file" << fileId;
        m_llmClient->generateTags(finalText, fileId, existingTags);
    }
}

void LLMProcessor::onTagsGenerated(int fileId, const QStringList &tags)
{
    if (fileId != m_currentFileId) {
        return;
    }
    
    // Add tags to database
    if (!tags.isEmpty()) {
        DatabaseManager::instance().addTagsToFile(fileId, tags);
    }
    
    // Update queue status to completed
    DatabaseManager::instance().updateQueueStatus(m_currentQueueId, 2); // 2 = Done
    
    emit processingComplete(fileId, tags);
    emit pendingCountChanged();
    
    m_currentQueueId = -1;
    m_currentFileId = -1;
    
    qInfo() << "Tags generated for file" << fileId << ":" << tags;
}

void LLMProcessor::onLLMError(int fileId, const QString &error)
{
    if (fileId != m_currentFileId && m_currentFileId > 0) {
        return;
    }
    
    // Update queue status with error
    DatabaseManager::instance().updateQueueStatus(m_currentQueueId, 2, error); // 2 = Done (with error)
    
    emit processingError(fileId, error);
    emit pendingCountChanged();
    
    m_currentQueueId = -1;
    m_currentFileId = -1;
    
    qWarning() << "LLM processing error for file" << fileId << ":" << error;
}
