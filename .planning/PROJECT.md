# 小学生作业管理 App（HomeworkPlan）

## What This Is

面向家长的 iPhone 本地优先作业管理 App。家长通过手动截图或粘贴文字导入微信/钉钉/补习班群中的作业信息，经 OCR 与 AI 解析后确认保存，打开 App 即可看到孩子今天还有哪些作业未完成，并支持重复任务与本地提醒。

先自用跑通流程，目标用户为 iPhone 用户（全栈开发者本人）。

## Core Value

手动提供作业内容后，App 能可靠地将信息转化为经用户确认的每日作业清单——一眼看清今天还有什么没做。

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] 手动截图导入作业（相册选择 → Vision OCR → DeepSeek 解析）
- [ ] 粘贴文字导入作业（含剪贴板检测）
- [ ] AI 解析返回结构化任务候选，用户确认后才保存
- [ ] 今日待办主界面（按科目分组、完成/编辑/删除）
- [ ] 手动创建作业任务
- [ ] 重复任务规则（每天/工作日/每周）及自动生成
- [ ] 本地通知提醒（截止日期任务 + 重复任务）
- [ ] SwiftData 本地存储 + iCloud 同步
- [ ] Keychain 安全存储 DeepSeek API Key

### Out of Scope

- ReplayKit 录屏自动采集 — MVP 优先验证手动导入价值，录屏方案风险高、权限摩擦大
- Broadcast Upload Extension — 依赖录屏自动化，延后至后续阶段
- Claude Vision / Qwen-VL 主路径 — MVP 使用 Vision OCR + DeepSeek 文本解析
- 钉钉机器人 / Webhook / 后端服务 — 本地优先，无多用户需求
- 多用户协作、教师端、学校管理 — 自用 MVP 不需要
- Share Extension — 延后至 Phase 2（PRD 路线图）
- 桌面小组件 — 延后至 Phase 3
- 历史统计 — 延后至 Phase 5

## Context

**痛点来源：**
1. 作业来源分散（钉钉、微信群、补习班），群消息量大易漏
2. 固定任务（如每日练字）靠记忆，经常忘记
3. 多平台打卡操作繁琐

**MVP 范围调整（相对原 PRD）：**
原 PRD 以 ReplayKit 录屏自动采集为核心差异化功能。OpenSpec `extract-mvp-scope` 将 MVP 收窄为手动导入优先，先验证「导入 → 解析 → 确认 → 每日清单」核心价值链，录屏自动化延后。

**技术环境：**
- iOS 17+，Swift + SwiftUI，MVVM
- SwiftData + CloudKit（iCloud 同步，无后端）
- Apple Vision（本地 OCR）
- DeepSeek（文本语义解析，替代 PRD 中的 Claude）
- UNUserNotificationCenter（本地通知）
- Keychain（API Key）

**参考文档：**
- `docs/PRD.md` — 完整产品技术方案
- `openspec/changes/extract-mvp-scope/` — MVP 范围提取与 spec

## Constraints

- **Platform**: iOS 17+ only — SwiftUI/SwiftData 最低版本要求
- **Architecture**: Local-first, no backend — 自用 MVP，SwiftData + iCloud 足够
- **AI**: DeepSeek text API only for MVP — OCR 提取文字后送 DeepSeek，不用 VLM
- **Confirmation**: User must confirm parsed tasks — 家长场景容错要求高，避免误报
- **Privacy**: API Key in Keychain — 客户端直连 LLM，密钥不可明文存储
- **Timeline**: 3 个周末 MVP（PRD 估算）— 分阶段交付

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 手动导入为 MVP 主路径 | 录屏方案有 Extension 内存/权限/微信屏蔽风险，先验证核心价值 | — Pending |
| DeepSeek 负责语义解析 | 文本解析足够验证日常用法，成本低于 Claude Vision | — Pending |
| 解析结果必须用户确认 | 家长场景误报代价高，信任比速度重要 | — Pending |
| 本地优先无后端 | 自用、隐私、部署简单 | — Pending |
| 服务边界清晰（import/OCR/parse/task/recurring/reminder） | 便于后续接入录屏自动化而不重写核心 | — Pending |
| 默认科目 + 可自定义 | 降低首次使用门槛，保留灵活性 | — Pending |
| Share Extension 不纳入 MVP v1 | 应用内相册导入足够验证，减少 Extension 复杂度 | — Pending |

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
*Last updated: 2026-06-22 after initialization*
