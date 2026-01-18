# TagStore

[English](README.md) | [中文](README_zh_CN.md)

一个跨平台的数字资产管理（DAM）工具，用于个人大量文件组织。TagStore 使用 AI 驱动的自动标签功能，将物理存储与逻辑检索解耦。

## 功能特性

- **双重导入模式**
  - **托管模式**：将文件移动到集中库（`~/Documents/TagStore_Library/YYYY/MM/`）
  - **引用模式**：就地索引文件而不移动（Alt + 拖放）

- **智能去重**
  - SHA-256 内容哈希
  - 冲突解决：拒绝 / 导入为副本 / 合并为别名

- **AI 自动标签**（OpenAI 兼容 API）
  - 自动文本提取（PDF、TXT、MD）
  - 基于 LLM 的标签生成
  - 支持 OpenAI、Azure OpenAI 和兼容服务

- **分面搜索**
  - 关键词搜索，300ms 防抖
  - 标签过滤（AND/OR 逻辑）
  - 引用文件与托管文件的视觉区分

- **现代 UI**
  - 浮动拖放气球，快速导入
  - 自适应网格布局，带缩略图
  - 深色主题，流畅动画

## 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | Qt 6.10+ (C++20) |
| UI | QML |
| 数据库 | SQLite |
| 架构 | MVVM |
| LLM | OpenAI 兼容 API |

## 构建

### 前置要求

- Qt 6.10+，包含模块：Core、Quick、Sql、Network、Concurrent
- CMake 3.16+
- Ninja（推荐）或其他构建系统
- LLVM-MinGW 或 MinGW 编译器

### 构建步骤

```powershell
# 克隆并进入目录
cd TagStore

# 创建构建目录
mkdir build && cd build

# 配置（LLVM-MinGW 示例）
$env:PATH = "D:\Qt\Tools\llvm-mingw1706_64\bin;D:\Qt\Tools\CMake_64\bin;D:\Qt\Tools\Ninja;" + $env:PATH

cmake .. -G "Ninja" `
  -DCMAKE_PREFIX_PATH="D:\Qt\6.10.1\llvm-mingw_64" `
  -DCMAKE_CXX_COMPILER="clang++.exe"

# 构建
cmake --build . --config Release

# 部署依赖
D:\Qt\6.10.1\llvm-mingw_64\bin\windeployqt.exe --qmldir ..\qml .\TagStore.exe

# 复制 LLVM 运行时（如果使用 LLVM-MinGW）
Copy-Item "D:\Qt\Tools\llvm-mingw1706_64\bin\libc++.dll" .
Copy-Item "D:\Qt\Tools\llvm-mingw1706_64\bin\libunwind.dll" .
```

## 配置

### OpenAI API 设置

1. 点击 **设置**（⚙️）按钮
2. 配置：
   - **API 基础 URL**：`https://api.openai.com/v1`（或兼容端点）
   - **API 密钥**：您的 API 密钥
   - **模型**：`gpt-4o-mini`、`gpt-3.5-turbo` 等

或者，设置环境变量：
```powershell
$env:OPENAI_API_KEY = "sk-..."
```

### 库路径

默认：`~/Documents/TagStore_Library`

可在设置中配置。数据库（`tagstore.db`）位于库根目录，便于移植。

## 使用说明

### 导入文件

| 操作 | 模式 |
|------|------|
| 拖放 | 托管（移动到库） |
| Alt + 拖放 | 引用（就地索引） |
| 点击 **+ 导入** | 文件选择器（托管） |
| 点击 **🔗 索引** | 文件夹选择器（引用） |

### 搜索与过滤

- 在搜索框中输入关键词搜索
- 点击标签芯片按标签过滤
- 多个标签 = AND 逻辑

### 文件操作（右键菜单）

- 打开
- 在资源管理器中显示
- 管理标签
- 删除

## 项目结构

```
TagStore/
├── CMakeLists.txt
├── src/
│   ├── main.cpp
│   ├── core/
│   │   ├── DatabaseManager.h/cpp    # SQLite 操作
│   │   ├── FileHasher.h/cpp         # SHA-256 异步哈希
│   │   ├── LibraryConfig.h/cpp      # 配置管理
│   │   └── LLMClient.h/cpp          # OpenAI API 客户端
│   ├── models/
│   │   └── LibraryModel.h/cpp       # GridView 的 QAbstractListModel
│   ├── viewmodels/
│   │   └── FileIngestor.h/cpp       # 文件导入控制器
│   └── workers/
│       ├── LLMProcessor.h/cpp       # 后台 AI 处理
│       └── TextExtractor.h/cpp      # PDF/文本提取
└── qml/
    ├── Main.qml                     # 主窗口
    ├── DropBalloon.qml              # 浮动导入组件
    └── components/
        ├── GlobalHeader.qml
        ├── TagFilterBar.qml
        ├── TagChip.qml
        ├── ResultsGrid.qml
        └── FileCard.qml
```

## 数据库架构

```sql
-- 文件表
files (id, content_hash, filename, file_path UNIQUE, storage_mode, created_at)

-- 标签表  
tags (id, name UNIQUE)

-- 关联表
file_tags (file_id, tag_id, PRIMARY KEY)

-- AI 处理队列
processing_queue (id, file_id, status, error_log)
```

## 许可证

MIT License

Copyright (c) 2024 TagStore Contributors

特此免费授予任何获得本软件副本及相关文档文件（下称"软件"）的人不受限制地处理该软件的权利，包括不受限制地使用、复制、修改、合并、发布、分发、再许可和/或销售该软件副本，以及再授权向其提供软件的人这样做，但须符合以下条件：

上述版权声明和本许可声明应包含在该软件的所有副本或重要部分中。

本软件按"原样"提供，不提供任何形式的明示或暗示保证，包括但不限于对适销性、特定用途适用性和非侵权性的保证。在任何情况下，作者或版权持有人均不对任何索赔、损害或其他责任负责，无论是在合同诉讼、侵权行为或其他方面，由软件或软件的使用或其他交易引起、由此产生或与之相关。
