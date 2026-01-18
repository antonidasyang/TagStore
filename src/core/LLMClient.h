#ifndef LLMCLIENT_H
#define LLMCLIENT_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QNetworkAccessManager>
#include <QNetworkReply>

class LLMClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
    Q_PROPERTY(QString model READ model WRITE setModel NOTIFY modelChanged)
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY isProcessingChanged)
    
public:
    explicit LLMClient(QObject *parent = nullptr);
    ~LLMClient();
    
    // Configuration
    QString apiKey() const;
    void setApiKey(const QString &key);
    
    QString baseUrl() const;
    void setBaseUrl(const QString &url);
    
    QString model() const;
    void setModel(const QString &modelName);
    
    int maxTokens() const;
    void setMaxTokens(int tokens);
    
    double temperature() const;
    void setTemperature(double temp);
    
    bool isProcessing() const;
    
    // API calls
    Q_INVOKABLE void generateTags(const QString &documentText, int fileId = -1);
    Q_INVOKABLE void fetchModels(const QString &baseUrl, const QString &apiKey);
    Q_INVOKABLE void cancelRequest();
    Q_INVOKABLE bool isConfigured() const;
    
signals:
    void tagsGenerated(int fileId, QStringList tags);
    void errorOccurred(int fileId, QString errorMsg);
    void modelsFetched(QStringList models);
    void modelsFetchError(QString errorMsg);
    void apiKeyChanged();
    void baseUrlChanged();
    void modelChanged();
    void isProcessingChanged();
    
private slots:
    void onReplyFinished(QNetworkReply *reply);
    void onModelsReplyFinished(QNetworkReply *reply);
    
private:
    QString buildPrompt(const QString &documentText) const;
    QStringList parseTagsFromResponse(const QByteArray &response) const;
    
    QNetworkAccessManager *m_networkManager;
    QNetworkReply *m_currentReply;
    QNetworkReply *m_modelsReply;
    QString m_apiKey;
    QString m_baseUrl;
    QString m_model;
    int m_maxTokens;
    double m_temperature;
    int m_currentFileId;
    bool m_isProcessing;
};

#endif // LLMCLIENT_H
