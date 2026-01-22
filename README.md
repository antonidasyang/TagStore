# TagStore: AI-Powered Digital Asset Management (DAM)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Framework](https://img.shields.io/badge/Qt-6.10+-41cd52.svg?logo=qt)](https://www.qt.io/)
[![Language](https://img.shields.io/badge/C++-20-00599C.svg?logo=c%2B%2B)](https://isocpp.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](https://github.com/)

[English](README.md) | [中文 (Chinese)](README_zh_CN.md)

**TagStore** is a modern, open-source **Digital Asset Management (DAM)** tool and **File Organizer** designed for researchers, creatives, and data hoarders. It decouples logical retrieval from physical storage using **AI-powered auto-tagging** and semantic categorization.

Stop wasting time organizing folders. Let TagStore build your **Personal Knowledge Management (PKM)** system locally.

---

## 🚀 Key Features

### 📂 Smart File Organization
- **Dual Import Modes**:
  - **Managed Mode**: Functions as a secure vault (like Eagle/Billfish), moving files to a centralized library (`~/Documents/TagStore_Library`).
  - **Referenced Mode**: Indexes files in-place without moving them (Alt + Drop), perfect for large datasets on NAS or external drives.
- **Folder Support**: Seamlessly import entire directory structures recursively or as single reference items.
- **Recycle Bin Integration**: Safe file deletion that respects your OS recycle bin.

### 🧠 AI & Automation
- **AI Auto-Tagging**: Connects to **OpenAI-compatible APIs** (OpenAI, Azure, LocalAI, Ollama) to automatically analyze and tag documents.
- **Content Extraction**: Built-in engine extracts text from **PDF, Markdown, TXT, and Code** files for context-aware tagging.
- **Batch Processing**: Background job queue for processing thousands of files without UI freezing.

### 🔍 Search & Retrieval
- **Faceted Search**: Combine multiple tags (AND/OR logic) with keyword search.
- **Debounced Filtering**: Instant search results with a 300ms debounce for performance.
- **Visual Distinction**: Clear UI indicators for managed vs. referenced files.

### 🖥️ Modern Experience
- **Cross-Platform**: Native performance on Windows, macOS, and Linux using **Qt 6 / QML**.
- **System Integration**: 
  - **Start with Windows**: Option to launch automatically on startup.
  - **Singleton**: Ensures only one instance runs; focuses the existing window on launch.
  - **Tray Icon**: Minimizes to system tray for unobtrusive background operation.
- **Drop Balloon**: A floating desktop widget ("Drop Zone") for drag-and-drop imports while the main app is minimized.
- **Adaptive UI**: Responsive Grid and List views with dark/light mode support.
- **Context Menu Integration**: Right-click actions for quick management (Move vs. Link options).

---

## 🛠️ Tech Stack

Built for performance and longevity.

| Component | Technology | Description |
|-----------|------------|-------------|
| **Core** | C++20 | High-performance backend logic |
| **Framework** | Qt 6.10+ | Cross-platform application framework |
| **UI** | QML (Qt Quick) | Fluid, GPU-accelerated interface |
| **Data** | SQLite | Serverless, zero-config metadata storage |
| **AI** | REST API | OpenAI-compatible client for LLM integration |

---

## 📦 Build & Installation

### Prerequisites
- **Qt 6.10+** (Modules: Core, Quick, Sql, Network, Concurrent)
- **CMake 3.16+**
- **C++ Compiler** (MSVC 2019+, GCC 11+, Clang 12+, or LLVM-MinGW)
- **Ninja** (Recommended build system)

### Quick Start (Windows PowerShell)

```powershell
# 1. Clone the repository
git clone https://github.com/your-username/TagStore.git
cd TagStore

# 2. Configure build (Example using LLVM-MinGW)
mkdir build; cd build
cmake .. -G "Ninja" -DCMAKE_BUILD_TYPE=Release

# 3. Compile
cmake --build .

# 4. Deploy (Windows only)
windeployqt.exe --qmldir ..\qml .\TagStore.exe
```

---

## ⚙️ Configuration

### 🤖 LLM Setup (For Auto-Tagging)
TagStore works with any OpenAI-compatible provider.
1. Go to **Settings** (⚙️).
2. Enter your **API Key** and **Base URL**.
   - *OpenAI*: `https://api.openai.com/v1`
   - *LocalAI/Ollama*: `http://localhost:8080/v1`
3. Select your model (e.g., `gpt-4o`, `llama3`).

### 🖱️ Drag & Drop Behavior
Customize how you want to import files by default in **Settings > Import Options**:
- **Default Action**: Move to Library OR Link to Original.
- **Right-Click Drop**: Always prompts for choice.

---

## 🗺️ Roadmap

- [x] Basic CRUD & Tagging
- [x] AI Auto-Tagging (Text/PDF)
- [x] System Tray & Drop Balloon
- [ ] Image Recognition / OCR
- [ ] Plugin System
- [ ] WebDAV Sync

## 🤝 Contributing

Contributions are welcome! Please submit Pull Requests or open Issues for bug reports.

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.