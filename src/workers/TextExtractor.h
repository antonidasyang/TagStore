#ifndef TEXTEXTRACTOR_H
#define TEXTEXTRACTOR_H

#include <QObject>
#include <QString>
#include <QProcess>

class TextExtractor : public QObject
{
    Q_OBJECT
    
public:
    explicit TextExtractor(QObject *parent = nullptr);
    ~TextExtractor();
    
    // Check if file type is supported
    Q_INVOKABLE static bool isSupported(const QString &filePath);
    Q_INVOKABLE static QStringList supportedExtensions();
    
public slots:
    // Start async extraction
    void startExtraction(int fileId, const QString &filePath);
    
signals:
    void extractionFinished(int fileId, const QString &text);
    void extractionError(int fileId, const QString &error);
    
private slots:
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessError(QProcess::ProcessError error);
    
private:
    void extractFromPdf(const QString &filePath);
    void extractFromText(const QString &filePath);
    void extractFromMarkdown(const QString &filePath);
    void extractFromDirectory(const QString &filePath);
    
    static QString getFileExtension(const QString &filePath);
    
    QProcess *m_process;
    int m_currentFileId;
};

#endif // TEXTEXTRACTOR_H
