# Relo - AI 智能笔记与待办助手

## 项目简介

**Relo** 是一款基于 iOS 平台的原生 AI 智能笔记与待办事项管理应用。它旨在通过 Apple 端侧的自然语言处理（NLP）技术，帮助用户更高效地记录想法、整理思绪并自动化提取日常工作中的任务。应用采用现代化架构设计，兼顾了极简的交互体验与强大的数据分析能力，同时利用本地存储确保了用户的数据隐私与安全。

## 核心功能与已完成内容

### 1. 智能笔记记录 (Smart Notes)

- **快速记录**：提供简洁直观的文本输入界面（`NoteEditorPage` / `ContentView`），支持用户随时随地记录想法和工作内容。
- **笔记管理**：已完成笔记列表展示（`NotesListView`）及详情查看功能（`NoteDetailView`），支持对历史记录的浏览与管理。

### 2. AI 智能分析 (NLP Integration)

完全基于 Apple 原生 `Natural Language` 框架实现端侧数据分析，无需联网即可提供以下智能处理：

- **关键词提取**：自动从长篇笔记中提取出核心词汇，帮助快速把握重点。
- **智能摘要生成**：基于语义权重，自动为较长的笔记文本生成简短的摘要。
- **情绪识别**：分析并标记文本的情绪倾向（积极、中性、消极），帮助用户回顾时了解当时的心境。
- **自动化任务提取**：智能识别笔记中包含“时间”（如“明天”、“周五”）与“动作”（如“开会”、“提交”）的语句，并自动将其转化为待办事项。

### 3. 待办事项管理 (Todo Management)

- **双向同步**：待办事项既可以从笔记文本中 AI 自动提取，也可以由用户手动添加（`AddTodoView`）。
- **待办列表**：提供独立的待办事项视图（`TodoListView`），清晰展示所有待完成的任务，支持状态切换（未完成/已完成）。

### 4. 智能提醒与辅助功能

- **本地通知系统**：深度集成 `UserNotifications`，支持为待办事项设置定时提醒及提前提醒功能，确保重要任务不遗漏。
- **工具支持**：内置 `DateHelper.swift` 辅助进行时间解析和日期格式化处理。
- **个性化设置**：包含基础的设置页面（`SettingView`）供用户调整偏好。

### 5. 数据持久化与安全

- **Core Data 本地存储**：通过 `Persistence.swift` 与 `ReloModel.xcdatamodeld` 实现了所有笔记（`NoteEntity`）与待办任务（`TodoEntity`）的本地持久化。数据完全存储在设备端，保障隐私。

## 🛠 技术栈

- **开发语言**：Swift 6.0 / Swift 5.x
- **UI 框架**：SwiftUI
- **本地数据库**：Core Data
- **AI 框架**：Natural Language (Apple 原生 NLP)
- **系统集成**：UserNotifications (本地通知)

## 📁 项目结构概览

```text
Relo/
├── ReloApp.swift            # 应用主入口，处理生命周期与通知权限
├── Persistence.swift        # Core Data 持久化容器配置与控制
├── ReloModel.xcdatamodeld   # 核心数据模型 (笔记与待办事项实体定义)
├── NLPContents/             # AI 核心模块
│   └── NLPAnalyzer.swift    # 封装所有 NLP 文本分析与任务提取逻辑
├── NotesContent/            # 主视图模块
│   └── ContentView.swift    # 包含底部 TabView 导航的主容器
├── NotesList/               # 笔记列表与详情模块
│   ├── NotesListView.swift
│   └── NoteDetailView.swift
├── TodoList/                # 待办事项模块
│   ├── TodoListView.swift
│   └── AddTodoView.swift
├── NotesSetting/            # 设置模块
│   └── SettingView.swift
├── RlToolHelper/            # 工具类
│   └── DateHelper.swift     # 日期与时间处理辅助
└── RlLodingView/            # 启动与加载视图
    ├── LoadingView.swift
    └── Launch Screen.storyboard
```

## 总结

该项目目前已完成从**UI 交互层**、**业务逻辑层**到**数据持久层**的完整闭环开发。其最大亮点在于将 **SwiftUI 现代响应式 UI** 与 **Apple 原生 NLP 端侧分析能力** 完美结合，不仅实现了基础的增删改查功能，还赋予了应用“智能化”的特性。代码结构清晰，模块化程度高，为后续的功能扩展打下了良好的基础。

## 未来规划 (To-Do)

### 1. 深度 AI 赋能 (大模型接入)

- **日记/笔记深度分析**：接入云端或本地大语言模型（如 ChatGPT / Claude / DeepSeek 或 Apple Intelligence），对用户的长篇日记和历史笔记进行深度语义理解。
- **智能建议与洞察**：基于用户的记录内容（情绪变化、工作重心、生活习惯），定期生成个性化的建议、周报或情绪疏导指南。
- **对话式交互**：增加一个 AI Chat 界面，允许用户直接向 AI 提问：“我上周主要在忙什么？”或“帮我把这篇会议记录整理成 Action Items”。

### 2. 多端同步与生态融入

- **iCloud 数据同步**：接入 CloudKit，实现笔记与待办事项在 iPhone、iPad 和 Mac 之间的无缝同步。
- **桌面与锁屏小组件 (Widgets)**：开发 iOS 桌面小组件，方便用户快速查看今日待办、快速记录想法或展示 AI 生成的每日格言。
- **Siri 与快捷指令 (Shortcuts)**：支持通过 Siri 语音直接添加笔记或待办事项，提升记录效率。

### 3. 功能完善与体验升级

- **富文本与多媒体支持**：在 `NoteEditorPage` 中支持插入图片、录音、Markdown 格式以及手写涂鸦。
- **标签与分类系统**：为笔记和待办引入自定义标签（Tags）和文件夹层级，方便更细粒度的知识管理。
- **高级数据可视化**：在 `SettingView` 或新的统计页面中，通过图表直观展示用户的情绪波动趋势、任务完成率和高频记录词汇。
- **数据导出与分享**：支持将笔记或 AI 分析报告导出为 PDF、长图或纯文本，方便分享给他人或归档。

