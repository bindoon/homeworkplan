# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-06-22
**Phases:** 4 | **Plans:** 10 | **Sessions:** 1 day

### What Was Built

- SwiftUI + SwiftData + CloudKit 三 Tab 壳，手动今日作业清单与科目管理
- Vision OCR + DeepSeek JSON 解析管道，截图/粘贴导入与候选确认流
- 幂等 generationKey 重复规则与 App 生命周期自动生成
- UNUserNotificationCenter 本地提醒，64 pending 预算与任务生命周期联动取消
- Keychain API Key 存储，内容哈希去重，CloudKit schema 初始化与科目 dedupe

### What Worked

- 四阶段垂直切片策略 — 每阶段结束 App 可独立使用，无需等待后续功能
- 服务边界清晰（import/OCR/parse/task/recurring/reminder）— 跨阶段集成通过 AppDependencies 一次接线
- 确认门控解析 — 家长场景信任优先，候选不自动入库
- generationKey 幂等 — 重复任务与提醒解耦，Phase 3→4 集成干净

### What Was Inefficient

- xcodebuild 验证被 iOS 26.2 Simulator 缺失阻断 — 四阶段均 human_needed，无法在 CI/executor 完成运行时验证
- Phase 2 SUMMARY 未写 requirements-completed frontmatter — 里程碑审计需回退 VERIFICATION.md 交叉引用

### Patterns Established

- `@MainActor` Repository + Service 分层，SwiftData `@Model` 实体
- ReminderService 通过 TaskRepository 属性注入，create/complete/delete 统一 schedule/cancel
- MainTabView 作为 lifecycle orchestrator（recurring generate + reminder reschedule）
- ImportSourceType 枚举贯通 manual/screenshot/paste/recurring 来源追踪

### Key Lessons

1. MVP 范围收窄（手动导入优先）比原 PRD 录屏方案更快验证核心价值
2. 环境约束（Simulator SDK）应在 Phase 1 前确认，避免四阶段连锁 human_needed
3. 跨阶段集成检查应在 milestone audit 中显式映射 REQ-ID → wiring evidence

### Cost Observations

- Model mix: GSD executor session (single day delivery)
- Timeline: 2026-06-22 13:52 → 14:20 (~28 min active commits for phases 3-4; full milestone same day)
- Notable: 10 plans / 4 phases / ~4100 LOC Swift in one session

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 1 | 4 | OpenSpec MVP scope extraction; vertical slice delivery |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | Unit + UI tests present | Static/code review | xcodebuild blocked |

### Top Lessons (Verified Across Milestones)

1. 确认门控 AI 解析是家长场景的正确默认 — 速度让位于信任
2. 本地优先 + 清晰服务边界为 v2 录屏自动化预留扩展点
