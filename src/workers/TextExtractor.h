#ifndef TEXTEXTRACTOR_H
#define TEXTEXTRACTOR_H

#include <QObject>
#include <QString>

class TextExtractor : public QObject
{
    Q_OBJECT
    
public:
    explicit TextExtractor(QObject *parent = nullptr);
    
    // Extract text from various file types
    Q_INVOKABLE QString extractText(const QString &filePath);
    
    // Check if file type is supported
    Q_INVOKABLE static bool isSupported(const QString &filePath);
    Q_INVOKABLE static QStringList supportedExtensions();
    
signals:
    void extractionComplete(const QString &filePath, const QString &text);
    void extractionError(const QString &filePath, const QString &error);
    
private:
    QString extractFromPdf(const QString &filePath);
    QString extractFromText(const QString &filePath);
    QString extractFromMarkdown(const QString &filePath);
    
    static QString getFileExtension(const QString &filePath);
};

#endif // TEXTEXTRACTOR_H
