# Roadmap: HomeworkPlan iOS MVP

## Overview

HomeworkPlan MVP 以四个垂直切片交付完整家长作业管理闭环：先建立可手动维护的今日清单与 iCloud 持久化基线，再接入截图/粘贴导入与 DeepSeek 确认式解析，随后补齐重复任务自动生成，最后以本地通知完成截止与固定任务提醒。每阶段结束时用户都能独立完成一条端到端价值链，无需等待后续阶段才可使用 App。

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3, 4): Planned milestone work
- Decimal phases (e.g., 2.1): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Daily Task List & Data Foundation** - 手动创建/管理今日作业清单，SwiftData + iCloud 持久化 (completed 2026-06-22)
- [ ] **Phase 2: Import & AI Parsing** - 截图/粘贴导入，OCR + DeepSeek 解析，用户确认后入库 (executed 2026-06-22, verification human_needed)
- [ ] **Phase 3: Recurring Tasks** - 重复规则创建与启动/前台自动生成当日任务
- [ ] **Phase 4: Local Reminders** - 截止与重复任务本地通知，权限引导与联动取消

## Phase Details

### Phase 1: Daily Task List & Data Foundation

**Goal**: 家长无需 AI 即可手动维护孩子今日作业清单，数据本地持久化并在多设备间同步
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: SETT-03, TASK-01, TASK-02, TASK-03, TASK-04, TASK-05, TASK-06, TASK-07
**Success Criteria** (what must be TRUE):

  1. 用户打开 App 默认看到今日未完成作业，按科目分组展示
  2. 用户可手动创建作业（科目、内容、截止日期、备注），并标记完成、编辑或删除
  3. 用户可浏览今天以外的日期作业列表
  4. 用户可使用默认科目集合并添加自定义科目
  5. 作业数据在本地保存，并在启用 iCloud 的设备间保持同步

**Plans**: 5 plans
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Walking Skeleton：Xcode 工程 + SwiftData/CloudKit + Tab 壳 + 手动添加今日任务

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — 任务生命周期：完成/编辑/左滑删除

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-03-PLAN.md — 日期浏览：今日日期选择器 + 全部 Tab 按日分组
- [x] 01-04-PLAN.md — 科目管理：设置页 CRUD + 自定义科目

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 01-05-PLAN.md — iCloud 同步硬化：CloudKit schema + 去重 + 人工验证

**UI hint**: yes

### Phase 2: Import & AI Parsing

**Goal**: 家长可从群聊截图或粘贴文字导入作业，经 OCR 与 AI 解析后逐项确认再写入清单
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: IMPT-01, IMPT-02, IMPT-03, IMPT-04, IMPT-05, PARSE-01, PARSE-02, PARSE-03, PARSE-04, PARSE-05, PARSE-06, SETT-01, SETT-02
**Success Criteria** (what must be TRUE):

  1. 用户可从相册选择截图或粘贴文字作为作业导入来源
  2. 系统对截图执行 Vision OCR，并将文本发送至 DeepSeek 返回结构化候选任务
  3. 解析结果以候选列表展示，不会自动入库；用户可逐项确认、编辑或丢弃
  4. 用户可在设置中配置 DeepSeek API Key（Keychain 存储）；未配置时 AI 解析被阻断并给出明确引导
  5. 重复导入相同内容时被检测并跳过，避免重复解析与重复任务

**Plans**: 3 plans
Plans:
**Wave 1**

- [x] 02-01-PLAN.md — 数据模型、Keychain、内容哈希去重、ImportRecord

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Vision OCR + DeepSeek ParseService + ImportService 管道

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02-03-PLAN.md — 导入 UI、候选确认流、剪贴板 hint、API Key 设置

**UI hint**: yes

### Phase 3: Recurring Tasks

**Goal**: 家长可为固定作业（如每日练字）设置重复规则，App 自动生成当日任务实例
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: RECUR-01, RECUR-02, RECUR-03, RECUR-04
**Success Criteria** (what must be TRUE):

  1. 用户可创建重复规则（科目、内容、频率、提醒时间）
  2. App 启动或进入前台时，活跃规则自动生成当日作业任务
  3. 同一规则在同一日期不会生成重复任务
  4. 用户可暂停、恢复或删除重复规则

**Plans**: 1 plan
Plans:
**Wave 1**

- [x] 03-01-PLAN.md — RecurringRule model, generator, Settings CRUD, lifecycle hooks
**UI hint**: yes

### Phase 4: Local Reminders

**Goal**: 家长收到截止作业与重复任务的本地通知提醒，完成任务后通知自动取消
**Mode:** mvp
**Depends on**: Phase 1, Phase 3
**Requirements**: REMND-01, REMND-02, REMND-03, REMND-04, REMND-05
**Success Criteria** (what must be TRUE):

  1. 用户可在设置中配置默认提醒时间
  2. 有截止日期的未完成作业会按规则调度本地通知
  3. 含提醒时间的重复规则所生成的任务会收到本地通知
  4. 用户完成作业或删除任务后，对应待发送通知被取消
  5. 首次调度前 App 请求通知权限；若用户拒绝，给出清晰说明与后续指引

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Daily Task List & Data Foundation | 5/5 | Complete   | 2026-06-22 |
| 2. Import & AI Parsing | 3/3 | Executed | 2026-06-22 |
| 3. Recurring Tasks | 0/TBD | Not started | - |
| 4. Local Reminders | 0/TBD | Not started | - |
