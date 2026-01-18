#include "TextExtractor.h"
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QProcess>
#include <QDebug>

TextExtractor::TextExtractor(QObject *parent)
    : QObject(parent)
{
}

QString TextExtractor::extractText(const QString &filePath)
{
    if (!QFile::exists(filePath)) {
        emit extractionError(filePath, "File does not exist");
        return QString();
    }
    
    QString ext = getFileExtension(filePath).toLower();
    QString text;
    
    if (ext == "pdf") {
        text = extractFromPdf(filePath);
    } else if (ext == "txt") {
        text = extractFromText(filePath);
    } else if (ext == "md" || ext == "markdown") {
        text = extractFromMarkdown(filePath);
    } else {
        // Try as plain text for unknown formats
        text = extractFromText(filePath);
    }
    
    if (!text.isEmpty()) {
        emit extractionComplete(filePath, text);
    }
    
    return text;
}

bool TextExtractor::isSupported(const QString &filePath)
{
    QString ext = getFileExtension(filePath).toLower();
    return supportedExtensions().contains(ext);
}

QStringList TextExtractor::supportedExtensions()
{
    return {"pdf", "txt", "md", "markdown", "text"};
}

QString TextExtractor::extractFromPdf(const QString &filePath)
{
    // Use pdftotext from Poppler utilities
    // This requires poppler-utils to be installed
    QProcess process;
    
    // pdftotext -layout file.pdf -
    // The "-" at the end outputs to stdout
    QStringList args;
    args << "-layout" << filePath << "-";
    
    process.start("pdftotext", args);
    
    if (!process.waitForStarted(5000)) {
        // pdftotext not available, try alternative approach
        qWarning() << "pdftotext not found. Install poppler-utils for PDF support.";
        emit extractionError(filePath, "PDF extraction requires poppler-utils (pdftotext)");
        return QString();
    }
    
    if (!process.waitForFinished(30000)) {
        process.kill();
        emit extractionError(filePath, "PDF extraction timed out");
        return QString();
    }
    
    if (process.exitCode() != 0) {
        QString error = process.readAllStandardError();
        emit extractionError(filePath, "PDF extraction failed: " + error);
        return QString();
    }
    
    QString text = QString::fromUtf8(process.readAllStandardOutput());
    return text.trimmed();
}

QString TextExtractor::extractFromText(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit extractionError(filePath, "Could not open file: " + file.errorString());
        return QString();
    }
    
    QTextStream stream(&file);
    stream.setEncoding(QStringConverter::Utf8);
    
    QString text = stream.readAll();
    file.close();
    
    return text.trimmed();
}

QString TextExtractor::extractFromMarkdown(const QString &filePath)
{
    // For markdown, we just extract as plain text
    // The LLM can handle markdown formatting
    return extractFromText(filePath);
}

QString TextExtractor::getFileExtension(const QString &filePath)
{
    return QFileInfo(filePath).suffix();
}
