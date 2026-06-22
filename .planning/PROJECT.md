# 小学生作业管理 App（HomeworkPlan）

## What This Is

面向家长的 iPhone 本地优先作业管理 App。v1.0 已交付手动清单、导入解析、重复任务与本地通知完整闭环。

**v2.0 方向：AI Native 改造** — 将导入、添加作业、科目管理、重复任务等能力下沉为 AI 工具（Tool-calling），界面简化为「查询首页 + 自然语言操作台」：首页合并今日与全部视图（支持折叠展示）；第二 Tab 为单一输入框，支持贴图、语音描述与自然语言管理各类配置。

先自用跑通流程，目标用户为 iPhone 用户（全栈开发者本人）。

## Current Milestone: v2.0 AI Native

**Goal:** 以 Agent + Tools 架构重构交互层，保留 v1.0 数据与服务层，让用户通过自然语言完成绝大多数操作。

**Target features:**
- 首页：简洁查询视图，合并原「今日」与「全部」Tab，支持按日期/科目折叠展示
- 操作台 Tab：单一输入框统一入口（文字、贴图、语音）
- AI 工具层：导入作业、添加任务、科目 CRUD、重复规则 CRUD 等封装为可调用工具
- 自然语言操作：「每天练字」「加一门科学」「导入这张截图里的作业」等描述式交互
- 保留用户确认 gate：AI 解析/变更结果需用户确认后再写入 SwiftData

## Core Value

手动提供作业内容后，App 能可靠地将信息转化为经用户确认的每日作业清单——一眼看清今天还有什么没做。

## Requirements

### Validated

- ✓ 手动截图导入作业（相册选择 → Vision OCR → DeepSeek 解析）— v1.0
- ✓ 粘贴文字导入作业（含剪贴板检测）— v1.0
- ✓ AI 解析返回结构化任务候选，用户确认后才保存 — v1.0
- ✓ 今日待办主界面（按科目分组、完成/编辑/删除）— v1.0
- ✓ 手动创建作业任务 — v1.0
- ✓ 重复任务规则（每天/工作日/每周）及自动生成 — v1.0
- ✓ 本地通知提醒（截止日期任务 + 重复任务）— v1.0
- ✓ SwiftData 本地存储 + iCloud 同步 — v1.0
- ✓ Keychain 安全存储 DeepSeek API Key — v1.0

### Active

- [ ] AI Native 双 Tab 信息架构 — 首页查询 + 操作台（v2.0）
- [ ] Agent Orchestrator + Tool Registry — 统一调度导入/任务/科目/重复规则工具（v2.0）
- [ ] 操作台多模态输入 — 文字、贴图、语音描述（v2.0）
- [ ] 首页合并视图 — 今日待办 + 历史浏览，折叠展示（v2.0）
- [ ] 自然语言管理科目与重复任务（v2.0）

### Out of Scope

- Share Extension / ReplayKit / WidgetKit — v2.0 聚焦 AI Native 交互，原扩展计划延后至 v2.1+
- 后端 Agent 服务 — 继续客户端直连 LLM，本地优先
- 钉钉机器人 / Webhook — 无多用户需求
- 多用户协作、教师端、学校管理 — 自用不需要
- 外部平台打卡 — 不解决多平台打卡疲劳
- 完全去掉确认步骤 — 家长场景仍需 AI 结果确认 gate

## Context

**痛点来源：**
1. 作业来源分散（钉钉、微信群、补习班），群消息量大易漏
2. 固定任务（如每日练字）靠记忆，经常忘记
3. 多平台打卡操作繁琐

**v1.0 交付状态（2026-06-22）：**
- ~4,100 行 Swift（HomeworkPlan/ + tests）
- 4 phases, 10 plans, 30/30 v1 requirements implemented
- 46 Swift source files: models, repositories, import/OCR/parse, recurring, reminders
- Runtime xcodebuild verification deferred — iOS 26.2 Simulator not on executor machine

**技术环境：**
- iOS 17+，Swift + SwiftUI，MVVM
- SwiftData + CloudKit（iCloud 同步，无后端）
- Apple Vision（本地 OCR）
- DeepSeek（文本语义解析）
- UNUserNotificationCenter（本地通知）
- Keychain（API Key）

**参考文档：**
- `docs/PRD.md` — 完整产品技术方案
- `.planning/milestones/v1.0-ROADMAP.md` — v1.0 归档路线图
- `.planning/milestones/v1.0-REQUIREMENTS.md` — v1.0 归档需求

## Constraints

- **Platform**: iOS 17+ only — SwiftUI/SwiftData 最低版本要求
- **Architecture**: Local-first, no backend — 自用 MVP，SwiftData + iCloud 足够
- **AI**: DeepSeek text API only for MVP — OCR 提取文字后送 DeepSeek，不用 VLM
- **Confirmation**: User must confirm parsed tasks — 家长场景容错要求高，避免误报
- **Privacy**: API Key in Keychain — 客户端直连 LLM，密钥不可明文存储
- **Timeline**: 3 个周末 MVP — v1.0 单日完成（2026-06-22）

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 手动导入为 MVP 主路径 | 录屏方案有 Extension 内存/权限/微信屏蔽风险，先验证核心价值 | ✓ Good — v1.0 完整闭环已交付 |
| DeepSeek 负责语义解析 | 文本解析足够验证日常用法，成本低于 Claude Vision | ✓ Good — ParseService JSON mode + retry |
| 解析结果必须用户确认 | 家长场景误报代价高，信任比速度重要 | ✓ Good — TaskCandidateReviewView gate |
| 本地优先无后端 | 自用、隐私、部署简单 | ✓ Good — SwiftData + CloudKit only |
| 服务边界清晰（import/OCR/parse/task/recurring/reminder） | 便于后续接入录屏自动化而不重写核心 | ✓ Good — AppDependencies DI |
| 默认科目 + 可自定义 | 降低首次使用门槛，保留灵活性 | ✓ Good — SubjectRepository seed |
| Share Extension 不纳入 MVP v1 | 应用内相册导入足够验证，减少 Extension 复杂度 | ✓ Good — deferred to v2.1+ |
| v2.0 优先 AI Native 而非 Extension | 用户反馈：表单入口过多，希望自然语言统一操作 | — Pending |
| 保留 v1.0 服务层，重构 UI + Agent 层 | 降低迁移风险，TaskRepository 等已验证 | — Pending |
| 双 Tab 取代三 Tab | 首页=查，第二 Tab=做，设置保留为轻量入口 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-22 after v2.0 AI Native milestone started*
