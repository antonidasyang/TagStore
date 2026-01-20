#ifndef LLMPROCESSOR_H
#define LLMPROCESSOR_H

#include <QObject>
#include <QTimer>
#include <QThread>

class LLMClient;
class TextExtractor;

class LLMProcessor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY pendingCountChanged)
    Q_PROPERTY(bool isBusy READ isBusy NOTIFY isBusyChanged)
    
public:
    explicit LLMProcessor(LLMClient *client, QObject *parent = nullptr);
    ~LLMProcessor();
    
    bool isRunning() const;
    int pendingCount() const;
    bool isBusy() const;
    
    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void processNow();
    
signals:
    void isRunningChanged();
    void pendingCountChanged();
    void isBusyChanged();
    void processingStarted(int fileId);
    void processingComplete(int fileId, const QStringList &tags);
    void processingError(int fileId, const QString &error);
    
    // Internal signal to worker
    void startExtraction(int fileId, const QString &filePath);
    
private slots:
    void pollQueue();
    void onTagsGenerated(int fileId, const QStringList &tags);
    void onLLMError(int fileId, const QString &error);
    
    // From worker
    void onExtractionFinished(int fileId, const QString &text);
    void onExtractionError(int fileId, const QString &error);
    
private:
    void processItem(int queueId, int fileId);
    
    LLMClient *m_llmClient;
    TextExtractor *m_textExtractor;
    QThread *m_workerThread;
    QTimer *m_pollTimer;
    bool m_isRunning;
    bool m_isExtracting = false;
    int m_currentQueueId;
    int m_currentFileId;
};

#endif // LLMPROCESSOR_H
