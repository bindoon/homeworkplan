# Phase 1: Daily Task List & Data Foundation - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous — all recommended defaults accepted)

<domain>
## Phase Boundary

建立 HomeworkPlan MVP 的数据与任务管理基线：SwiftData 模型 + Repository + Tab 导航壳，今日待办主界面（按科目分组），手动 CRUD，日期浏览，默认科目 + 自定义科目，本地持久化并启用 iCloud 同步。本阶段不涉及 AI 解析、导入、重复任务或通知。

</domain>

<decisions>
## Implementation Decisions

### 今日主界面布局
- 默认 Tab 为「今日」，按科目分组展示未完成作业
- 每项显示：科目、内容摘要、截止日期、完成 checkbox
- 左滑删除，点击进入编辑 sheet
- 空状态引导用户手动添加第一条作业
- 顶部日期选择器可切换查看其他日期

### 数据模型与持久化
- SwiftData @Model：HomeworkTask、Subject（Phase 1 最小集；RecurringRule/ImportRecord 预留 schema 或 Phase 1 仅建 HomeworkTask + Subject）
- ModelConfiguration 启用 CloudKit private database
- Repository 层封装 TaskRepository、SubjectRepository
- HomeworkTask 字段：id(UUID)、subject、content、notes、dueDate、isCompleted、completedAt、sourceType(manual)、createdAt

### 科目管理
- 默认科目：语文、数学、英语、科学（带 emoji 图标）
- 用户可在设置或添加任务时新增自定义科目
- Subject 独立 @Model，HomeworkTask 关联 subject 名称或关系

### 导航结构
- 三 Tab：今日 / 全部 / 设置
- 「全部」Tab：按日期分组的历史与未来任务列表
- 「设置」Tab：Phase 1 仅含科目管理与关于；API Key 占位 Phase 2

### Claude's Discretion
- 具体 SwiftUI 组件拆分、@Observable ViewModel 命名
- iCloud sync 开发期 schema 初始化策略
- 是否在本阶段创建完整 5 模型 schema 或仅 HomeworkTask + Subject

</decisions>

<code_context>
## Existing Code Insights

Greenfield — no existing iOS code. Follow ARCHITECTURE.md MVVM + Service + Repository pattern and STACK.md (SwiftUI, SwiftData, iOS 17+, zero third-party deps).

### Reusable Assets
- None yet

### Established Patterns
- @Observable ViewModels, @Query in simple lists, Repository wraps ModelContext

### Integration Points
- HomeworkPlanApp as composition root with .modelContainer
- TabView root navigation

</code_context>

<specifics>
## Specific Ideas

- 家长打开 App 第一眼看到「今天还有什么没做」
- 中文 UI 文案
- 参考 PRD 3.6 今日待办设计

</specifics>

<deferred>
## Deferred Ideas

- DeepSeek API Key 配置（Phase 2）
- 截图/粘贴导入（Phase 2）
- 重复任务（Phase 3）
- 本地通知（Phase 4）
- Share Extension、录屏采集

</deferred>
