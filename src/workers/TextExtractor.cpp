#include "TextExtractor.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QTextStream>
#include <QDebug>

TextExtractor::TextExtractor(QObject *parent)
    : QObject(parent)
    , m_process(new QProcess(this))
    , m_currentFileId(-1)
{
    connect(m_process, &QProcess::finished, this, &TextExtractor::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred, this, &TextExtractor::onProcessError);
}

TextExtractor::~TextExtractor()
{
    if (m_process->state() != QProcess::NotRunning) {
        m_process->kill();
        m_process->waitForFinished(1000);
    }
}

void TextExtractor::startExtraction(int fileId, const QString &filePath)
{
    m_currentFileId = fileId;
    
    QFileInfo info(filePath);
    if (!info.exists()) {
        emit extractionError(fileId, "File does not exist");
        return;
    }
    
    if (info.isDir()) {
        extractFromDirectory(filePath);
        return;
    }
    
    QString ext = getFileExtension(filePath).toLower();
    
    if (ext == "pdf") {
        extractFromPdf(filePath);
    } else if (ext == "txt" || ext == "text" || ext == "md" || ext == "markdown" ||
               ext == "json" || ext == "xml" || ext == "ini" || ext == "log" ||
               ext == "cpp" || ext == "h" || ext == "c" || ext == "hpp" || 
               ext == "py" || ext == "js" || ext == "ts" || ext == "html" || ext == "css") {
        extractFromText(filePath);
    } else {
        // Unsupported format - fallback to filename strategy via error
        emit extractionError(fileId, "Unsupported file type for content extraction: " + ext);
    }
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

void TextExtractor::extractFromPdf(const QString &filePath)
{
    if (m_process->state() != QProcess::NotRunning) {
        m_process->kill();
        m_process->waitForFinished();
    }
    
    QStringList args;
    args << "-layout" << filePath << "-";
    
    m_process->start("pdftotext", args);
}

void TextExtractor::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (exitStatus == QProcess::CrashExit) {
        // aborted or crashed
        return;
    }
    
    if (exitCode != 0) {
        QString error = m_process->readAllStandardError();
        emit extractionError(m_currentFileId, "PDF extraction failed: " + error);
        return;
    }
    
    QString text = QString::fromUtf8(m_process->readAllStandardOutput());
    emit extractionFinished(m_currentFileId, text.trimmed());
}

void TextExtractor::onProcessError(QProcess::ProcessError error)
{
    if (error == QProcess::Crashed) return; // handled in finished
    emit extractionError(m_currentFileId, "Process error: " + m_process->errorString());
}

void TextExtractor::extractFromText(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit extractionError(m_currentFileId, "Could not open file: " + file.errorString());
        return;
    }
    
    QTextStream stream(&file);
    stream.setEncoding(QStringConverter::Utf8);
    
    QString text = stream.readAll();
    file.close();
    
    emit extractionFinished(m_currentFileId, text.trimmed());
}

void TextExtractor::extractFromMarkdown(const QString &filePath)
{
    extractFromText(filePath);
}

void TextExtractor::extractFromDirectory(const QString &filePath)
{
    QDir dir(filePath);
    dir.setFilter(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
    dir.setSorting(QDir::Name | QDir::DirsFirst | QDir::IgnoreCase);
    QFileInfoList list = dir.entryInfoList();
    
    QString text = "Directory Name: " + dir.dirName() + "\n";
    text += "Path: " + filePath + "\n";
    text += "Contents:\n";
    
    int count = 0;
    const int maxItems = 50;
    
    for (const QFileInfo &fi : list) {
        if (count >= maxItems) {
            text += "... (and more)\n";
            break;
        }
        text += (fi.isDir() ? "[DIR] " : "") + fi.fileName() + "\n";
        count++;
    }
    
    emit extractionFinished(m_currentFileId, text);
}

QString TextExtractor::getFileExtension(const QString &filePath)
{
    return QFileInfo(filePath).suffix();
}
