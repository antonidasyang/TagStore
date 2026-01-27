#include "LLMClient.h"
#include "LibraryConfig.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QDebug>

LLMClient::LLMClient(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_currentReply(nullptr)
    , m_modelsReply(nullptr)
    , m_maxTokens(1000)
    , m_temperature(0.3)
    , m_currentFileId(-1)
    , m_isProcessing(false)
{
    // Load settings from LibraryConfig
    LibraryConfig &config = LibraryConfig::instance();
    m_apiKey = config.apiKey();
    m_baseUrl = config.apiBaseUrl();
    m_model = config.model();
    m_maxTokens = config.maxTokens();
    m_temperature = config.temperature();
}

LLMClient::~LLMClient()
{
    cancelRequest();
}

QString LLMClient::apiKey() const
{
    return m_apiKey;
}

void LLMClient::setApiKey(const QString &key)
{
    if (m_apiKey != key) {
        m_apiKey = key;
        LibraryConfig::instance().setApiKey(key);
        emit apiKeyChanged();
    }
}

QString LLMClient::baseUrl() const
{
    return m_baseUrl;
}

void LLMClient::setBaseUrl(const QString &url)
{
    if (m_baseUrl != url) {
        m_baseUrl = url;
        LibraryConfig::instance().setApiBaseUrl(url);
        emit baseUrlChanged();
    }
}

QString LLMClient::model() const
{
    return m_model;
}

void LLMClient::setModel(const QString &modelName)
{
    if (m_model != modelName) {
        m_model = modelName;
        LibraryConfig::instance().setModel(modelName);
        emit modelChanged();
    }
}

int LLMClient::maxTokens() const
{
    return m_maxTokens;
}

void LLMClient::setMaxTokens(int tokens)
{
    m_maxTokens = tokens;
    LibraryConfig::instance().setMaxTokens(tokens);
}

double LLMClient::temperature() const
{
    return m_temperature;
}

void LLMClient::setTemperature(double temp)
{
    m_temperature = temp;
    LibraryConfig::instance().setTemperature(temp);
}

bool LLMClient::isProcessing() const
{
    return m_isProcessing;
}

bool LLMClient::isConfigured() const
{
    return !m_apiKey.isEmpty() && !m_baseUrl.isEmpty() && !m_model.isEmpty();
}

void LLMClient::generateTags(const QString &documentText, int fileId)
{
    if (m_isProcessing) {
        emit errorOccurred(fileId, "Another request is in progress");
        return;
    }
    
    if (!isConfigured()) {
        emit errorOccurred(fileId, "API not configured. Please set API key, base URL, and model.");
        return;
    }
    
    if (documentText.trimmed().isEmpty()) {
        emit errorOccurred(fileId, "Document text is empty");
        return;
    }
    
    m_currentFileId = fileId;
    m_isProcessing = true;
    emit isProcessingChanged();
    
    // Build the request
    QUrl url(m_baseUrl + "/chat/completions");
    QNetworkRequest request(url);
    
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", QString("Bearer %1").arg(m_apiKey).toUtf8());
    
    // Build the JSON payload
    QJsonObject payload;
    payload["model"] = m_model;
    payload["max_tokens"] = m_maxTokens;
    payload["temperature"] = m_temperature;
    
    // Response format for JSON
    QJsonObject responseFormat;
    responseFormat["type"] = "json_object";
    payload["response_format"] = responseFormat;
    
    // Messages array
    QJsonArray messages;
    
    QJsonObject systemMessage;
    systemMessage["role"] = "system";
    systemMessage["content"] = LibraryConfig::instance().systemPrompt();
    messages.append(systemMessage);
    
    QJsonObject userMessage;
    userMessage["role"] = "user";
    // Truncate very long documents to avoid token limits
    QString truncatedText = documentText.left(8000);
    userMessage["content"] = QString("Extract tags from this document:\n\n%1").arg(truncatedText);
    messages.append(userMessage);
    
    payload["messages"] = messages;
    
    QJsonDocument doc(payload);
    QByteArray data = doc.toJson(QJsonDocument::Compact);
    
    qDebug() << "Sending request to:" << url.toString();
    m_currentReply = m_networkManager->post(request, data);
    connect(m_currentReply, &QNetworkReply::finished, this, [this]() {
        onReplyFinished(m_currentReply);
    });
}

void LLMClient::fetchModels(const QString &baseUrl, const QString &apiKey)
{
    if (baseUrl.isEmpty()) {
        emit modelsFetchError("Base URL is empty");
        return;
    }
    
    // Cancel any existing models request
    if (m_modelsReply && m_modelsReply->isRunning()) {
        m_modelsReply->abort();
        m_modelsReply->deleteLater();
        m_modelsReply = nullptr;
    }
    
    QUrl url(baseUrl + "/models");
    QNetworkRequest request(url);
    
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    if (!apiKey.isEmpty()) {
        request.setRawHeader("Authorization", QString("Bearer %1").arg(apiKey).toUtf8());
    }
    
    qDebug() << "Fetching models from:" << url.toString();
    m_modelsReply = m_networkManager->get(request);
    connect(m_modelsReply, &QNetworkReply::finished, this, [this]() {
        onModelsReplyFinished(m_modelsReply);
    });
}

void LLMClient::onModelsReplyFinished(QNetworkReply *reply)
{
    if (reply != m_modelsReply) {
        reply->deleteLater();
        return;
    }
    
    m_modelsReply = nullptr;
    
    if (reply->error() != QNetworkReply::NoError) {
        QString errorMsg = reply->errorString();
        
        QByteArray responseData = reply->readAll();
        if (!responseData.isEmpty()) {
            QJsonDocument doc = QJsonDocument::fromJson(responseData);
            if (doc.isObject()) {
                QJsonObject error = doc.object()["error"].toObject();
                if (!error.isEmpty()) {
                    errorMsg = error["message"].toString();
                }
            }
        }
        
        qWarning() << "Models fetch error:" << errorMsg;
        emit modelsFetchError(errorMsg);
        reply->deleteLater();
        return;
    }
    
    QByteArray responseData = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(responseData);
    
    QStringList models;
    
    if (doc.isObject()) {
        QJsonObject root = doc.object();
        QJsonArray data = root["data"].toArray();
        
        for (const QJsonValue &val : data) {
            QJsonObject modelObj = val.toObject();
            QString modelId = modelObj["id"].toString();
            if (!modelId.isEmpty()) {
                models.append(modelId);
            }
        }
    }
    
    // Sort models alphabetically
    models.sort();
    
    qDebug() << "Fetched models:" << models;
    emit modelsFetched(models);
    
    reply->deleteLater();
}

void LLMClient::cancelRequest()
{
    if (m_currentReply && m_currentReply->isRunning()) {
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }
    
    if (m_isProcessing) {
        m_isProcessing = false;
        emit isProcessingChanged();
    }
}

void LLMClient::onReplyFinished(QNetworkReply *reply)
{
    if (reply != m_currentReply || reply == m_modelsReply) {
        return;
    }
    
    m_isProcessing = false;
    emit isProcessingChanged();
    
    int fileId = m_currentFileId;
    m_currentFileId = -1;
    m_currentReply = nullptr;
    
    if (reply->error() != QNetworkReply::NoError) {
        QString errorMsg = reply->errorString();
        
        // Try to parse error from response body
        QByteArray responseData = reply->readAll();
        if (!responseData.isEmpty()) {
            QJsonDocument doc = QJsonDocument::fromJson(responseData);
            if (doc.isObject()) {
                QJsonObject error = doc.object()["error"].toObject();
                if (!error.isEmpty()) {
                    errorMsg = error["message"].toString();
                }
            }
        }
        
        qWarning() << "API Error:" << errorMsg;
        emit errorOccurred(fileId, errorMsg);
        reply->deleteLater();
        return;
    }
    
    QByteArray responseData = reply->readAll();
    QStringList tags = parseTagsFromResponse(responseData);
    
    if (tags.isEmpty()) {
        emit errorOccurred(fileId, "Failed to parse tags from response");
    } else {
        emit tagsGenerated(fileId, tags);
    }
    
    reply->deleteLater();
}

QStringList LLMClient::parseTagsFromResponse(const QByteArray &response) const
{
    QStringList tags;
    
    QJsonDocument doc = QJsonDocument::fromJson(response);
    if (!doc.isObject()) {
        qWarning() << "Invalid JSON response";
        return tags;
    }
    
    QJsonObject root = doc.object();
    
    // Navigate to choices[0].message.content
    QJsonArray choices = root["choices"].toArray();
    if (choices.isEmpty()) {
        qWarning() << "No choices in response";
        return tags;
    }
    
    QJsonObject firstChoice = choices[0].toObject();
    QJsonObject message = firstChoice["message"].toObject();
    QString content = message["content"].toString();
    
    // Parse the content as JSON
    QJsonDocument contentDoc = QJsonDocument::fromJson(content.toUtf8());
    if (!contentDoc.isObject()) {
        qWarning() << "Invalid content JSON:" << content;
        return tags;
    }
    
    QJsonObject contentObj = contentDoc.object();
    QJsonArray tagsArray = contentObj["tags"].toArray();
    
    for (const QJsonValue &val : tagsArray) {
        QString tag = val.toString().trimmed().toLower();
        if (!tag.isEmpty()) {
            tags.append(tag);
        }
    }
    
    qDebug() << "Parsed tags:" << tags;
    return tags;
}
