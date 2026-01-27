# TagStore：AI 驱动的本地数字资产管理工具 (DAM)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Framework](https://img.shields.io/badge/Qt-6.10+-41cd52.svg?logo=qt)](https://www.qt.io/)
[![Language](https://img.shields.io/badge/C++-20-00599C.svg?logo=c%2B%2B)](https://isocpp.org/)

[English](README.md) | [中文](README_zh_CN.md)

**TagStore** 是一款现代化的、开源的**数字资产管理 (DAM)** 和**文件整理工具**。它专为研究人员、设计师和数据收集爱好者打造，旨在替代传统文件夹层级管理。

通过集成 **AI 自动打标**和大语言模型 (LLM)，TagStore 将您的本地文件转化为一个可语义检索的**个人知识库 (PKM)**。

---

## 🚀 核心功能

### 📂 智能文件管理
- **双重导入模式**：
  - **托管模式 (Managed)**：像 Eagle/Billfish 一样，将文件移动到加密库中统一管理 (`~/Documents/TagStore_Library`)。
  - **引用模式 (Referenced)**：**按住 Alt 拖入**，仅建立索引而不移动文件，适合 NAS 或大容量素材库。
- **文件夹支持**：支持递归扫描文件夹或将其作为单个引用项导入。
- **安全删除**：内置回收站集成，防止误删文件。

### 🧠 本地 AI 与自动化
- **AI 自动标签**：支持连接 **OpenAI**、**Azure** 或本地的 **Ollama/LocalAI**，自动分析文档内容并生成标签。
- **内容提取**：内置解析引擎，支持从 **PDF, Markdown, TXT, 代码文件** 中提取文本。
- **批量处理**：后台队列处理机制，支持一次性导入数千个文件而不卡顿。

### 🔍 极速检索
- **分面搜索**：支持标签组合过滤 (AND/OR) + 全文关键词搜索。
- **秒级响应**：基于 SQLite 和 C++ 优化，搜索结果即时呈现。
- **可视化分类**：直观区分"托管文件"与"引用文件"。

### 🖥️ 现代化体验
- **跨平台原生体验**：基于 **Qt 6 / QML** 开发，在 Windows, macOS, Linux 上均拥有极致性能。
- **系统集成**：
  - **开机自启**：支持随系统启动。
  - **单例模式**：防止多开，重复运行自动唤醒主窗口。
  - **托盘常驻**：最小化至系统托盘，后台静默运行。
- **悬浮拖放气球**：独创的"Drop Balloon"设计，即使主窗口最小化，也能随时拖拽收集文件。
- **右键智能菜单**：拖拽时使用**鼠标右键**，可弹出菜单选择"移动"或"链接"。
- **自适应主题**：完美支持深色/浅色模式切换。

---

## 🛠️ 技术栈

| 组件 | 技术方案 | 说明 |
|------|----------|------|
| **核心** | C++20 | 高性能后端逻辑 |
| **框架** | Qt 6.10+ | 跨平台应用框架 |
| **界面** | QML (Qt Quick) | GPU 加速的流畅 UI |
| **数据** | SQLite | 无需配置的本地数据库 |
| **AI** | REST API | 兼容 OpenAI 接口的 LLM 客户端 |

---

## 📦 下载与构建

### 环境要求
- **Qt 6.10+** (组件：Core, Quick, Sql, Network, Concurrent)
- **CMake 3.16+**
- **C++ 编译器** (MSVC 2019+, GCC 11+, Clang 12+, 或 LLVM-MinGW)
- **Ninja** (推荐)

### 快速开始 (Windows 命令行)

```powershell
# 1. 克隆仓库
git clone https://github.com/your-username/TagStore.git
cd TagStore

# 2. 配置构建 (以 LLVM-MinGW 为例)
mkdir build; cd build
cmake .. -G "Ninja" -DCMAKE_BUILD_TYPE=Release

# 3. 编译
cmake --build .

# 4. 部署依赖
windeployqt.exe --qmldir ..\qml .\TagStore.exe
```

---

## ⚙️ 配置指南

### 🤖 配置 AI 助手
1. 点击主界面的 **设置** (⚙️) 按钮。
2. 填写您的 LLM 服务商信息：
   - **API Base URL**: `https://api.openai.com/v1` (或任何兼容 OpenAI 格式的中转/本地地址)
   - **API Key**: 您的密钥
   - **Model**: `gpt-4o`, `qwen2.5`, `llama3` 等
3. **自定义提示词**：您可以修改系统提示词 (System Prompt)，让 AI 按照您的偏好生成标签（例如："总是使用蛇形命名法"）。
4. 勾选"自动使用 AI 打标签"。

### 🖱️ 交互习惯
在**设置 > 导入选项**中，您可以自定义默认的拖拽行为：
- **默认操作**：选择"移动到库"或"链接到原始位置"。
- **启动设置**：支持开机后直接最小化到托盘。

---

## 🤝 贡献与支持

欢迎提交 Issue 反馈 Bug 或提交 Pull Request 贡献代码。让我们一起打造最好用的开源文件管理工具！

## 📄 许可证

本项目基于 **MIT 许可证** 开源 - 详情请参阅 [LICENSE](LICENSE) 文件。