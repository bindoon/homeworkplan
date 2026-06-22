# Phase 2: Import & AI Parsing - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous — all recommended defaults accepted)

<domain>
## Phase Boundary

在 Phase 1 任务管理基线上，接入手动作业导入与 AI 解析闭环：相册截图导入（Vision OCR）、粘贴文字导入、DeepSeek 结构化解析、候选任务确认流、内容哈希去重、Keychain API Key 配置。解析结果不得自动入库。

</domain>

<decisions>
## Implementation Decisions

### 导入入口
- 今日 Tab 添加「导入」按钮，sheet 选择：截图导入 / 粘贴导入
- PhotosPicker 选择相册截图（应用内，不依赖 Share Extension）
- 粘贴导入：多行 TextEditor + 提交按钮
- 剪贴板 hint：App 进入前台时用 `UIPasteboard.general.hasStrings` 检测，显示 banner「检测到剪贴板内容，是否导入？」（不自动读取内容，符合 iOS 16+ 隐私）

### OCR 与解析管道
- Vision OCR：`.accurate`，`recognitionLanguages: ["zh-Hans", "en-US"]`
- DeepSeek API：`deepseek-v4-flash` 主模型，JSON mode，`temperature: 0`
- 输入：OCR 文本或粘贴文本 + import timestamp（用于相对日期）
- 输出 schema：TaskCandidate[] with subject, content, dueDate, assigner, confidence, notes

### 确认流 UX
- 单次导入展示候选列表 review screen
- 每项：确认 / 编辑 / 丢弃
- 批量操作：全部确认 / 全部丢弃
- 确认后调用 TaskRepository 写入，sourceType = screenshot/pasted

### API Key 与错误处理
- 设置 Tab 新增 DeepSeek API Key 配置（SecureField + Keychain）
- 未配置 Key 时阻断解析，显示引导文案
- JSON 解析失败：重试一次 stricter prompt，仍失败则展示 OCR 原文供手动录入
- SHA256 内容哈希去重（CryptoKit）

### 数据模型扩展
- ImportRecord @Model：contentHash, rawText, sourceType, parsedJSON, createdAt, linked task IDs
- TaskCandidate 为 transient struct，不持久化
- HomeworkTask 增加 sourceType enum 与 sourceDetail 字段

### Claude's Discretion
- ParseService actor 实现细节
- Prompt 模板文件组织
- 截图附件是否保留到 Documents（建议：确认前保留，确认后可配置删除 — MVP 默认保留）

</decisions>

<code_context>
## Existing Code Insights

Phase 1 已交付：HomeworkPlan/ SwiftUI app with HomeworkTask, Subject, TaskRepository, SubjectRepository, MainTabView (今日/全部/设置), TodayView, ManualTaskFormView.

### Reusable Assets
- TaskRepository.create for confirmed tasks
- AppDependencies DI pattern
- SettingsView shell for API Key section

### Integration Points
- ImportService → OCRService → ParseService → ReviewViewModel → TaskRepository
- KeychainService new service

</code_context>

<specifics>
## Specific Ideas

- OpenSpec specs: homework-import, homework-parsing
- 中文家校群 Prompt 需过滤接龙/闲聊/通知
- 用户确认后才保存（非 negotiable）

</specifics>

<deferred>
## Deferred Ideas

- Share Extension
- Qwen-VL fallback when OCR insufficient
- ReplayKit screen capture
- Offline parse queue (nice-to-have, defer if complex)

</deferred>
