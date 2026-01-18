#include "LLMProcessor.h"
#include "TextExtractor.h"
#include "core/LLMClient.h"
#include "core/DatabaseManager.h"
#include <QDebug>
#include <QDateTime>

LLMProcessor::LLMProcessor(LLMClient *client, QObject *parent)
    : QObject(parent)
    , m_llmClient(client)
    , m_textExtractor(new TextExtractor(this))
    , m_pollTimer(new QTimer(this))
    , m_isRunning(false)
    , m_currentQueueId(-1)
    , m_currentFileId(-1)
{
    connect(m_pollTimer, &QTimer::timeout, this, &LLMProcessor::pollQueue);
    connect(m_llmClient, &LLMClient::tagsGenerated, this, &LLMProcessor::onTagsGenerated);
    connect(m_llmClient, &LLMClient::errorOccurred, this, &LLMProcessor::onLLMError);
    
    // Poll every 2 seconds
    m_pollTimer->setInterval(2000);
}

LLMProcessor::~LLMProcessor()
{
    stop();
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

void LLMProcessor::processNow()
{
    if (m_isRunning && !m_llmClient->isProcessing()) {
        pollQueue();
    }
}

void LLMProcessor::pollQueue()
{
    if (!m_isRunning || m_llmClient->isProcessing()) {
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
    
    // Update status to processing
    DatabaseManager::instance().updateQueueStatus(queueId, 1); // 1 = Processing
    
    // Get file info
    FileDTO file = DatabaseManager::instance().getFileById(fileId);
    if (file.id < 0) {
        onLLMError(fileId, "File not found in database");
        return;
    }
    
    emit processingStarted(fileId);
    
    // Extract text from file
    QString text = m_textExtractor->extractText(file.filePath);
    
    if (text.isEmpty()) {
        // If extraction failed, use filename and any available metadata
        text = QString("Filename: %1").arg(file.filename);
    }
    
    // Send to LLM for tag generation
    m_llmClient->generateTags(text, fileId);
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
