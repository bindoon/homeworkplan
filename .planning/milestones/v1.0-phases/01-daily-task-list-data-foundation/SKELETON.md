# Walking Skeleton — HomeworkPlan

**Phase:** 1
**Generated:** 2026-06-22

## Capability Proven End-to-End

家长打开 App 默认进入「今日」Tab，手动添加一条作业后，能在按科目分组的今日列表中看到该任务，数据写入 SwiftData 本地存储。

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Framework | SwiftUI (iOS 17+) | 项目约束；Tab 导航、表单、@Query 列表均为原生能力 |
| Data layer | SwiftData + CloudKit private database | 本地优先、无后端；Phase 1 启用 iCloud 多设备同步（SETT-03） |
| Architecture | MVVM + Repository + Service | ARCHITECTURE.md 已定；ViewModel 不持有 ModelContext |
| Auth | 无（单用户本地 + iCloud Apple ID） | 自用 MVP，无需账号体系 |
| Deployment target | iOS 17.0 Simulator + 真机 | SwiftData/@Observable 最低版本 |
| Directory layout | HomeworkPlan/{App,Models,Domain,Repositories,Services,ViewModels,Views}/ | 与 ARCHITECTURE.md 一致，后续 Phase 2–4 直接扩展 |
| Bundle ID | app.homeworkplan.HomeworkPlan | Greenfield 占位；执行时按 Apple Developer Team 调整 |
| CloudKit container | iCloud.app.homeworkplan.HomeworkPlan | Day 1 创建 Container ID，避免后期迁移（PITFALLS #5） |
| 第三方依赖 | 零 SPM 包 | STACK.md 推荐 MVP 零外部依赖 |

## Stack Touched in Phase 1

- [x] Project scaffold（Xcode App + SwiftData + iCloud capability）
- [x] Routing — MainTabView 三 Tab（今日 / 全部 / 设置）
- [x] Database — HomeworkTask + Subject @Model，TaskRepository/SubjectRepository CRUD
- [x] UI — TodayView @Query 分组 + ManualTaskForm 写入
- [x] Deployment — `xcodebuild` Simulator build/test 作为 CI 验证命令

## Out of Scope (Deferred to Later Slices)

- DeepSeek API Key / 解析（Phase 2）
- 截图/粘贴导入、OCR、ImportRecord（Phase 2）
- RecurringRule 模型与自动生成（Phase 3）
- 本地通知 UNUserNotificationCenter（Phase 4）
- Share Extension、ReplayKit
- 今日 Tab 底部「导入」按钮（Phase 2 接入 ImportFlow）
- RecurringRule / ImportRecord / TaskAttachment 完整 @Model（Phase 1 仅 HomeworkTask + Subject）

## Subsequent Slice Plan

- Phase 2: 截图/粘贴导入 → OCR → DeepSeek 解析 → 用户确认入库
- Phase 3: 重复规则创建 + 启动/前台自动生成当日任务
- Phase 4: 截止日与重复任务本地通知 + 权限引导
