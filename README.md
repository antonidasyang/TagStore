# TagStore

A cross-platform Digital Asset Management (DAM) tool for personal high-volume file organization. TagStore decouples physical storage from logical retrieval using AI-powered auto-tagging.

## Features

- **Dual Import Modes**
  - **Managed Mode**: Move files to centralized library (`~/Documents/TagStore_Library/YYYY/MM/`)
  - **Referenced Mode**: Index files in-place without moving (Alt + Drop)

- **Smart Deduplication**
  - SHA-256 content hashing
  - Conflict resolution: Reject / Import as Copy / Merge as Alias

- **AI Auto-Tagging** (OpenAI Compatible API)
  - Automatic text extraction (PDF, TXT, MD)
  - LLM-powered tag generation
  - Supports OpenAI, Azure OpenAI, and compatible services

- **Faceted Search**
  - Keyword search with 300ms debounce
  - Tag filtering (AND/OR logic)
  - Visual distinction for referenced vs managed files

- **Modern UI**
  - Floating drop balloon for quick imports
  - Adaptive grid layout with thumbnails
  - Dark theme with smooth animations

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Qt 6.10+ (C++20) |
| UI | QML |
| Database | SQLite |
| Architecture | MVVM |
| LLM | OpenAI-compatible API |

## Build

### Prerequisites

- Qt 6.10+ with modules: Core, Quick, Sql, Network, Concurrent
- CMake 3.16+
- Ninja (recommended) or other build system
- LLVM-MinGW or MinGW compiler

### Build Steps

```powershell
# Clone and enter directory
cd TagStore

# Create build directory
mkdir build && cd build

# Configure (LLVM-MinGW example)
$env:PATH = "D:\Qt\Tools\llvm-mingw1706_64\bin;D:\Qt\Tools\CMake_64\bin;D:\Qt\Tools\Ninja;" + $env:PATH

cmake .. -G "Ninja" `
  -DCMAKE_PREFIX_PATH="D:\Qt\6.10.1\llvm-mingw_64" `
  -DCMAKE_CXX_COMPILER="clang++.exe"

# Build
cmake --build . --config Release

# Deploy dependencies
D:\Qt\6.10.1\llvm-mingw_64\bin\windeployqt.exe --qmldir ..\qml .\TagStore.exe

# Copy LLVM runtime (if using LLVM-MinGW)
Copy-Item "D:\Qt\Tools\llvm-mingw1706_64\bin\libc++.dll" .
Copy-Item "D:\Qt\Tools\llvm-mingw1706_64\bin\libunwind.dll" .
```

## Configuration

### OpenAI API Setup

1. Click the **Settings** (⚙️) button
2. Configure:
   - **API Base URL**: `https://api.openai.com/v1` (or compatible endpoint)
   - **API Key**: Your API key
   - **Model**: `gpt-4o-mini`, `gpt-3.5-turbo`, etc.

Alternatively, set environment variable:
```powershell
$env:OPENAI_API_KEY = "sk-..."
```

### Library Path

Default: `~/Documents/TagStore_Library`

Configurable in Settings. The database (`tagstore.db`) resides in the library root for portability.

## Usage

### Import Files

| Action | Mode |
|--------|------|
| Drag & Drop | Managed (move to library) |
| Alt + Drag & Drop | Referenced (index in-place) |
| Click **+ Import** | File picker (Managed) |
| Click **🔗 Index** | Folder picker (Referenced) |

### Search & Filter

- Type in search box for keyword search
- Click tag chips to filter by tags
- Multiple tags = AND logic

### File Actions (Right-click)

- Open
- Reveal in Explorer
- Manage Tags
- Delete

## Project Structure

```
TagStore/
├── CMakeLists.txt
├── src/
│   ├── main.cpp
│   ├── core/
│   │   ├── DatabaseManager.h/cpp    # SQLite operations
│   │   ├── FileHasher.h/cpp         # SHA-256 async hashing
│   │   ├── LibraryConfig.h/cpp      # Configuration management
│   │   └── LLMClient.h/cpp          # OpenAI API client
│   ├── models/
│   │   └── LibraryModel.h/cpp       # QAbstractListModel for GridView
│   ├── viewmodels/
│   │   └── FileIngestor.h/cpp       # File import controller
│   └── workers/
│       ├── LLMProcessor.h/cpp       # Background AI processing
│       └── TextExtractor.h/cpp      # PDF/text extraction
└── qml/
    ├── Main.qml                     # Main window
    ├── DropBalloon.qml              # Floating import widget
    └── components/
        ├── GlobalHeader.qml
        ├── TagFilterBar.qml
        ├── TagChip.qml
        ├── ResultsGrid.qml
        └── FileCard.qml
```

## Database Schema

```sql
-- Files table
files (id, content_hash, filename, file_path UNIQUE, storage_mode, created_at)

-- Tags table  
tags (id, name UNIQUE)

-- Junction table
file_tags (file_id, tag_id, PRIMARY KEY)

-- AI processing queue
processing_queue (id, file_id, status, error_log)
```

## License

MIT License

Copyright (c) 2024 TagStore Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
