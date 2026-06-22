# 小学生作业管理 App（HomeworkPlan）

## What This Is

面向家长的 iPhone 本地优先作业管理 App。v1.0 交付手动清单、导入解析、重复任务与本地通知完整闭环；**v2.0 已交付 AI Native 改造** — Agent + Tool-calling 架构，界面简化为「Home 查询首页 + Action 自然语言操作台」，支持文字、贴图、语音输入与自然语言管理科目/重复规则，所有变更经用户确认后写入 SwiftData。

先自用跑通流程，目标用户为 iPhone 用户（全栈开发者本人）。

## Current State

**Shipped:** v2.0 AI Native (2026-06-22)

- AgentOrchestrator + 15-tool ToolRegistry，确认门控写入
- Action Console：文字/贴图 OCR/语音多模态输入
- Home Tab：合并今日与历史，按科目/日期折叠
- 三 Tab 壳：首页 + 操作 + 设置（Settings 精简）
- NL 管理科目与重复规则 via Action Console

**Next:** v2.1+ Extensions（Share Extension、Widget 等）或跨 Tab UX 修复

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
- ✓ AI Native 双 Tab 信息架构 — 首页查询 + 操作台 — v2.0
- ✓ Agent Orchestrator + Tool Registry — v2.0
- ✓ 操作台多模态输入 — 文字、贴图、语音 — v2.0
- ✓ 首页合并视图 — 今日待办 + 历史浏览，折叠展示 — v2.0
- ✓ 自然语言管理科目与重复任务 — v2.0

### Active

(None — run `/gsd-new-milestone` to define v2.1+ requirements)

### Out of Scope

- Share Extension / ReplayKit / WidgetKit — v2.1+（v2.0 聚焦 AI Native）
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

**v2.0 交付状态（2026-06-22）：**
- ~5,000+ 行 Swift（HomeworkPlan/ + tests）
- v2.0: 4 phases, 4 plans, 26/26 requirements mapped (25 fully satisfied, TOOL-02 partial)
- Agent layer: Orchestrator, ToolRegistry, ToolExecutor, ActionConsoleView
- HomeQueryView unified home; MainTabView 三 Tab 壳
- 83 unit tests passing on iPhone 17 Simulator
- Known tech debt: Home auto-refresh after Action confirm; recurring generateIfNeeded on NL confirm; missing update_task tool

**v1.0 交付状态（2026-06-22）：**
- 4 phases, 10 plans, 30/30 v1 requirements
- See `.planning/milestones/v1.0-ROADMAP.md`

**技术环境：**
- iOS 17+，Swift + SwiftUI，MVVM
- SwiftData + CloudKit（iCloud 同步，无后端）
- Apple Vision（本地 OCR）
- DeepSeek / DashScope（Agent tool-calling + 文本解析）
- UNUserNotificationCenter（本地通知）
- Keychain（API Key）

**参考文档：**
- `docs/PRD.md` — 完整产品技术方案
- `.planning/milestones/v2.0-ROADMAP.md` — v2.0 归档路线图
- `.planning/milestones/v2.0-REQUIREMENTS.md` — v2.0 归档需求

## Constraints

- **Platform**: iOS 17+ only — SwiftUI/SwiftData 最低版本要求
- **Architecture**: Local-first, no backend — 自用 MVP，SwiftData + iCloud 足够
- **AI**: DeepSeek text API + tool-calling — OCR 提取文字后送 LLM，不用 VLM
- **Confirmation**: User must confirm parsed tasks — 家长场景容错要求高，避免误报
- **Privacy**: API Key in Keychain — 客户端直连 LLM，密钥不可明文存储

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 手动导入为 MVP 主路径 | 录屏方案有 Extension 内存/权限/微信屏蔽风险 | ✓ Good — v1.0 完整闭环 |
| DeepSeek 负责语义解析 | 文本解析足够验证日常用法 | ✓ Good — ParseService + Agent tools |
| 解析结果必须用户确认 | 家长场景误报代价高 | ✓ Good — Proposal gate |
| 本地优先无后端 | 自用、隐私、部署简单 | ✓ Good — SwiftData + CloudKit |
| v2.0 优先 AI Native 而非 Extension | 表单入口过多，希望 NL 统一操作 | ✓ Good — v2.0 shipped |
| 保留 v1.0 服务层，重构 UI + Agent 层 | 降低迁移风险 | ✓ Good — repos reused |
| 双 Tab 取代三 Tab | 首页=查，第二 Tab=做 | ✓ Good — Home + Action |
| Subject/recurring admin via Action NL | Settings 表单入口移除 | ✓ Good — Phase 4 |
| Deprecated views retained in codebase | 便于参考与后续清理 | ⚠️ Revisit — post-v2 cleanup |

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-06-22 after v2.0 AI Native milestone shipped*
