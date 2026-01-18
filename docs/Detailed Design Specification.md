# Detailed Design Specification

**Project:** TagStore (TS-2026)

**Type:** Technical Implementation Guide

## 1. System Architecture

The backend is structured around an MVVM pattern with dedicated worker agents for I/O operations.

### 1.1 High-Level Block Diagram

```mermaid
graph TD
    User[User / UI Layer]
    VM[ViewModel Layer C++]

    subgraph Backend [Core Backend]
        Ingest[File Ingestor]
        Search[Search Engine]
        AI[AI Manager]
    end

    FS[File System]
    DB[(SQLite Database)]
    Tools[Poppler / OCR]
    LLM[LLM Service]

    %% Connections
    User <-->|Signals| VM
    VM <--> Ingest
    VM <--> Search
    VM <--> AI

    Ingest <-->|Read Write| FS
    Ingest <-->|Check Hash| DB

    Search <-->|Query| DB

    AI <-->|Queue| DB
    AI <-->|Extract| Tools
    AI <-->|Gen Tags| LLM

```

## 2. Data Design (Schema)

The database uses a **"Flat Model"** optimization: Hashes are indexed but not unique (allowing physical copies), while file paths are unique.

### 2.1 Entity Relationship Diagram (ERD)

```mermaid
erDiagram
    FILES ||--o{ FILE_TAGS : has
    TAGS ||--o{ FILE_TAGS : belongs_to
    FILES ||--o{ PROCESSING_QUEUE : queues

    FILES {
        int id PK
        string content_hash "Index (Non-Unique)"
        string filename
        string file_path "Unique"
        int storage_mode "0=Managed, 1=Ref"
        int created_at "Timestamp"
    }

    TAGS {
        int id PK
        string name "Unique"
    }

    FILE_TAGS {
        int file_id PK
        int tag_id PK
    }

    PROCESSING_QUEUE {
        int id PK
        int file_id FK
        int status "0=Pending, 1=Done"
        text error_log
    }

```

## 3. Class Design (C++)

### 3.1 `DatabaseManager` (Singleton)

Responsible for thread-safe SQLite access.

```cpp
class DatabaseManager : public QObject {
    Q_OBJECT
public:
    static DatabaseManager& instance();
    bool addFile(const FileDTO &file);
    bool hashExists(const QString &hash);
    QList<FileDTO> getFilesByHash(const QString &hash);
    
    // Dynamic SQL Generation for Faceted Search
    QSqlQueryModel* search(const QString &keyword, const QList<int> &tagIds);
    
    // Queue Management
    void pushToQueue(int fileId);
    int popNextQueueItem(); 
};

```

### 3.2 `FileIngestor` (Controller)

Orchestrates the ingestion logic and conflict resolution.

```cpp
class FileIngestor : public QObject {
    Q_OBJECT
public:
    enum ImportMode { Managed, Referenced };
    enum ConflictResolution { Reject, ImportAsCopy, MergeAlias };

    Q_INVOKABLE void processDroppedFiles(const QList<QUrl> &urls, ImportMode mode);
    Q_INVOKABLE void resolveConflict(QString jobId, ConflictResolution resolution);

signals:
    void conflictDetected(QString jobId, QString newName, QString existingPath);
    void fileAdded(); 
};

```

### 3.3 `LLMProcessor` (Worker Agent)

Handles background text extraction and LLM API calls.

```cpp
class LLMProcessor : public QObject {
    Q_OBJECT
public slots:
    void startLoop(); // Infinite loop checking processing_queue

private:
    void processItem(int fileId) {
        QString context = extractText(fileId); // via Poppler
        QStringList tags = m_llmProvider->generateTags(context);
        DatabaseManager::instance().addTags(fileId, tags, "AI_Generated");
    }
};

```

## 4. Workflow Sequence Diagrams

### 4.1 Ingestion Pipeline (Managed Mode)

```mermaid
sequenceDiagram
    participant UI as QML View
    participant Ingest as FileIngestor
    participant Worker as Background Thread
    participant DB as Database
    participant FS as File System

    UI->>Ingest: processDroppedFiles(url, Mode=Managed)
    Ingest->>Worker: Run Task

    Worker->>FS: Read File & Compute Hash
    Worker->>DB: hashExists(hash)?
    DB-->>Worker: False (New File)

    Worker->>FS: Generate Path (~/Lib/2026/01/file.pdf)
    Worker->>FS: Move (Rename) Source -> Target

    Worker->>DB: INSERT File Record
    Worker->>DB: INSERT into processing_queue (For AI)

    Worker-->>Ingest: Task Done
    Ingest-->>UI: emit fileAdded()
    UI->>UI: Grid shows new file (Loading Icon)

```

### 4.2 AI Analysis Pipeline (Lazy Loading)

```mermaid
sequenceDiagram
    participant Agent as LLMProcessor
    participant DB as Database
    participant Ext as TextExtractor
    participant API as LLM Service (Ollama)

    loop Every 2 Seconds
        Agent->>DB: Pop Next Job (Status=Pending)

        opt Job Found
            Agent->>DB: Set Status=Processing

            Agent->>Ext: Extract Text (Target Path)
            Ext-->>Agent: "Invoice #001..."

            Agent->>API: POST /generate (Prompt + Text)
            API-->>Agent: JSON ["Invoice", "2026"]

            Agent->>DB: INSERT Tags
            Agent->>DB: Set Status=Completed

            Agent-->>UI: emit tagsUpdated(fileId)
        end
    end

```

## 5. Implementation Roadmap

1. **Phase 1 (Skeleton):**
* Implement `LibraryConfig` (`~/Documents` path logic).
* Initialize SQLite Schema.
* Implement `FileHasher` and valid SHA-256 output.


2. **Phase 2 (Ingestion):**
* Implement `FileIngestor` (Move vs. Link).
* Implement the floating `DropBalloon` in QML.


3. **Phase 3 (Core UI):**
* Build `GridView` and `LibraryModel`.
* Implement Dynamic SQL for Faceted Search.


4. **Phase 4 (Intelligence):**
* Integrate Poppler (Text Extraction).
* Connect to local Ollama API.