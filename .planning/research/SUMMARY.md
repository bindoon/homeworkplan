# Project Research Summary

**Project:** HomeworkPlan
**Domain:** Local-first iOS 家长端小学生作业管理 App（手动导入 + OCR + LLM 解析）
**Researched:** 2026-06-22
**Confidence:** HIGH

## Executive Summary

HomeworkPlan 是一款面向中国小学家长的本地优先 iOS 作业清单 App。核心价值是：从微信/钉钉群聊截图或粘贴文本中，经设备端 OCR 与 DeepSeek 文本解析，提取结构化作业候选，经家长确认后写入今日清单，并配合重复规则与本地通知解决「每天练字忘记」等痛点。竞品（作业小达人、优学小助手、MyStudyLife）已教育市场「清单 + 提醒 + AI 整理」的基本预期；HomeworkPlan 的错位竞争在于 **群聊语义解析 + 确认式入库 + 本地隐私 + 无后端账号**，刻意不做批改辅导、班级提交、游戏化激励。

专家构建此类产品的推荐路径是：**SwiftUI + MVVM + Service Layer + Repository**，SwiftData 作为唯一持久化源，CloudKit 实现多设备同步，Apple Vision 做设备端中文 OCR，DeepSeek `deepseek-v4-flash`（失败重试 `deepseek-v4-pro`）做纯文本 JSON 解析。MVP 范围已收敛为手动导入（相册截图 + 粘贴），ReplayKit 录屏与 Share Extension 延后至验证核心价值之后。关键架构模式是 **Import Pipeline：Staging → Parse → Confirm → Persist**——解析产出 transient `TaskCandidate`，用户确认后才写入 `HomeworkTask`；任何输入源（含未来录屏）最终汇入同一管道。

主要风险集中在三类：**(1) 中文家校群内容边界模糊**（接龙/打卡/作业混杂、OCR 丢失聊天气泡结构）——通过 Prompt 反例分类、确认页原图/OCR/候选三栏对照、相对日期置信度标注缓解；**(2) SwiftData + CloudKit 无 unique 约束**——Day 1 创建 CloudKit Container、全属性 default/optional、应用层 SHA256 与 `(ruleId, date)` 确定性键去重；**(3) 本地通知 64 条上限与 reschedule 竞态**——NotificationBudgetManager 滚动窗口、稳定 UUID identifier、禁止 `removeAllPendingNotificationRequests`。剪贴板自动读取在 iOS 16+ 会触发 Paste 权限弹窗，MVP 应改用显式粘贴入口（`UIPasteControl` / 粘贴按钮），`hasStrings` 仅作 hint banner。

## Key Findings

### Recommended Stack

纯原生 iOS，零外部 SPM 依赖。Xcode 26.x 构建（App Store 2026 起要求 iOS 26 SDK），部署目标 iOS 17.0+。SwiftUI + `@Observable` ViewModel 做 UI 层，SwiftData + CloudKit 私有容器做持久化与同步，Apple Vision `.accurate` + `zh-Hans`/`en-US` 做 OCR，URLSession + async/await 直连 DeepSeek Chat Completions API（Keychain 存 API Key），UserNotifications 做本地提醒，PhotosUI `PhotosPicker` 做截图导入，CryptoKit SHA256 做导入去重。

**Core technologies:**
- **SwiftUI + MVVM + `@Observable`：** 声明式 UI 与屏幕状态分离，便于 Service 注入与测试 — iOS 17+ 标准路径
- **SwiftData + CloudKit：** 本地存储 + 无后端多设备同步 — 替代 Core Data 样板；注意 CloudKit 不支持 `@Attribute(.unique)`
- **Apple Vision OCR：** 设备端中文识别，零 API 成本 — 中文须 `.accurate` 模式；MVP 不用 VLM
- **DeepSeek `deepseek-v4-flash` / `deepseek-v4-pro`：** OCR 后纯文本 JSON 解析 — 成本低（~$0.0001/次）；`deepseek-chat` 2026-07-24 退役
- **UserNotifications + Keychain：** 本地提醒与 API Key 安全存储 — 禁止 UserDefaults 存密钥；通知 ID 用模型内 UUID

### Expected Features

MVP 验证闭环：**手动提供内容 → AI 解析 → 用户确认 → 今日清单 → 提醒**。无 AI 也能用手动 CRUD 兜底，确保导入链路失败时 App 仍可用。

**Must have (table stakes):**
- 今日待办主视图（按科目分组）— 家长核心痛点「今天还有什么没做」
- 任务 CRUD + 完成/取消完成 + 按日浏览 — 清单类 App 基本预期
- 相册截图导入 + 粘贴文字导入 — 作业来源在微信群/钉钉
- DeepSeek 解析 → 候选任务 → 用户确认 — 长群消息拆成可执行项
- 重复规则（每天/工作日/每周）+ 启动/前台自动生成 — 「每天练字」痛点
- 本地通知（截止 + 重复）+ 权限引导 — 无提醒则重复任务价值减半
- SwiftData 本地存储 + iCloud 同步 — 敏感家庭数据不能丢
- 默认科目 + 可自定义、空状态引导 — 降低首次使用门槛

**Should have (competitive):**
- 群聊场景 AI 语义解析（过滤接龙/闲聊，提取作业）— 核心差异化
- 相对日期归一化（「明天交」「周五前」→ 具体日期）— 直接影响提醒准确性
- 内容哈希去重 — 避免重复 API 调用与重复任务
- 确认门控（Confirm-before-save）— 建立家长信任，区别于自动入库
- 剪贴板检测快捷粘贴（显式入口，非静默读取）— 提升导入流畅度
- 布置人/来源溯源 — 多老师场景便于核对

**Defer (v2+):**
- ReplayKit 录屏自动采集 — 技术风险最高，已移出 MVP
- Share Extension — Phase 2，减少「存相册再打开 App」步骤
- 桌面小组件、历史统计、多孩/家庭协同 — 验证核心价值后再投入
- VLM fallback、附件管理、后端/钉钉 Webhook — 按需追加

### Architecture Approach

采用 **MVVM + Service Layer + Repository** 三层分离：View/ViewModel 负责 UI 与编排，Service 封装 OCR/解析/通知/重复生成等跨 feature 逻辑，Repository 封装 SwiftData CRUD。SwiftData `@Model` 与 Domain DTO（`TaskCandidate`、`ParseResult`）分离；Composition Root（`HomeworkPlanApp` + `AppDependencies`）集中依赖注入。所有外部 IO（Vision、DeepSeek、Keychain、UNUserNotificationCenter）经 Service 访问，View 不直接调用。

**Major components:**
1. **ImportService + OCRService + ParseService** — 导入管道编排：截图/粘贴 → OCR → 哈希去重 → DeepSeek JSON → 候选列表
2. **TaskRepository + SubjectRepository + ImportRecordRepository** — SwiftData 持久化封装；写操作不直连 ModelContext
3. **RecurringTaskGenerator** — 启动/前台按 `(ruleId, yyyy-MM-dd)` 幂等生成当日任务实例
4. **ReminderService** — 本地通知调度/取消，64 条预算管理，UUID 稳定 identifier
5. **CandidateReviewViewModel** — 确认流独立 ViewModel，解析候选确认后才调用 TaskRepository 持久化

### Critical Pitfalls

1. **Vision OCR 丢失聊天气泡结构** — 保留 bounding box 左右侧启发式作 LLM 提示；确认页必展示原图 + OCR 原文 + 候选三栏对照
2. **DeepSeek JSON Mode ≠ Schema 保证** — 本地 Codable 校验 + 检查 `finish_reason` + Flash→Pro 重试；失败展示 OCR 原文 + 手动录入入口
3. **接龙/打卡/通知误识别为作业** — Prompt 内置反例分类（homework/check_in/collection/notice/noise）；确认页批量 discard
4. **相对日期锚点错误** — 解析请求携带 `importedAt` + timezone；`dueDateConfidence` medium/low 时强制用户选日期
5. **SwiftData + CloudKit 重复记录** — Day 1 创建 CloudKit Container；应用层 dedupe（contentHash、generationKey、normalizedName）；禁止 `@Attribute(.unique)`
6. **重复任务非幂等生成** — 插入前 fetch 存在性；确定性 ID + 同事务更新 `lastGeneratedDate`
7. **本地通知 64 条上限静默失效** — NotificationBudgetManager 保留最近 64 条；禁止 `removeAllPendingNotificationRequests`；真机验证
8. **剪贴板自动读取触发 Paste 权限弹窗** — 改用 `UIPasteControl` / 显式粘贴按钮；`hasStrings` 仅作 hint banner

## Implications for Roadmap

基于依赖关系、架构建议构建顺序与 pitfalls 映射，推荐 **6 个 Phase**：

### Phase 1: Foundation & Data Layer
**Rationale:** 所有功能依赖 SwiftData 模型与 Repository；CloudKit Container ID 必须 Day 1 创建（后期迁移代价极高）；dedupe 策略需在启用 iCloud 前落地。
**Delivers:** Xcode 项目骨架、SwiftData `@Model`（HomeworkTask/Subject/RecurringRule/ImportRecord/TaskAttachment）、ModelContainer 配置、Repository 层、默认科目 seed、CloudKit Container ID 注册（可先 `cloudKitDatabase: .none` 本地跑通）
**Addresses:** 数据本地持久化、科目分组、SwiftData + iCloud 基线
**Avoids:** Pitfall 5（CloudKit 重复）— 全属性 default/optional、业务唯一键设计

### Phase 2: Core Task Experience
**Rationale:** 手动 CRUD 是 AI 失败时的兜底路径，也是重复任务/提醒的数据基础；今日视图是核心价值骨架，应早于导入链路交付可运行 vertical slice。
**Delivers:** MainTabView、TodayView（`@Query` 按科目分组）、ManualTaskForm、AllTasksView（按日浏览）、编辑/删除/完成任务、空状态引导
**Addresses:** 今日待办、手动 CRUD、按日浏览、空状态与首次引导
**Avoids:** 无 AI 也能用的兜底要求；Pitfall 11（确认边界在此阶段不涉及 AI，但手动路径须完整）

### Phase 3: Import & AI Parsing
**Rationale:** 差异化核心路径；OCR、Parse、Keychain、确认流、去重同属一条管道，须同批交付（pitfalls 明确不可拆分「后续优化」）。
**Delivers:** KeychainService + Settings（API Key）、OCRService（Vision zh-Hans + orientation/padding）、ParseService（DeepSeek JSON + schema 校验 + 重试）、ImportService 管道、ImportRecord + ContentHash 去重、CandidateReviewView 确认流、相册截图 + 粘贴导入（显式粘贴，非静默剪贴板）
**Uses:** Apple Vision、DeepSeek v4-flash/pro、Keychain、CryptoKit
**Implements:** Import Pipeline（Staging → Parse → Confirm → Persist）
**Avoids:** Pitfall 1–4, 8–12（OCR 结构、JSON 不可靠、接龙误识别、相对日期、剪贴板隐私、hash 不稳定、跳过确认、Keychain）

### Phase 4: Recurring Tasks
**Rationale:** 依赖 TaskRepository 与任务 CRUD 完成；与导入链路可部分并行，但须在 Reminder Phase 之前完成（提醒需任务实例）。
**Delivers:** RecurringRule CRUD、RecurringTaskGenerator（启动/前台触发）、`(ruleId, date)` 确定性 generationKey 幂等写入
**Addresses:** 重复/固定任务、启动/前台自动生成
**Avoids:** Pitfall 6（非幂等生成）— 同 rule 同 date 仅一条

### Phase 5: Local Notifications
**Rationale:** 依赖任务模型与重复规则实例；截止提醒与重复提醒闭环是 P1 功能，但实现细节（64 上限、budget manager）需专门 phase 消化。
**Delivers:** ReminderService、通知权限引导 UX、任务 CRUD 联动 schedule/cancel、NotificationBudgetManager（≤64 pending）、真机验证清单
**Addresses:** 本地提醒/通知（截止 + 重复）
**Avoids:** Pitfall 7（64 上限、removeAll 竞态、Simulator 假象）

### Phase 6: iCloud Sync & MVP Polish
**Rationale:** 模型稳定、核心业务跑通后再启用 CloudKit sync；dedupe hardening 与 clipboard polish 是 MVP 收尾。
**Delivers:** `cloudKitDatabase: .private(...)` 启用、DEBUG schema init、远程变更 dedupe merge、剪贴板 hint banner（`hasStrings`）、PrivacyInfo.xcprivacy、黄金截图集回归测试
**Addresses:** iCloud 多设备同步、剪贴板检测（P2 polish）
**Avoids:** Pitfall 5 二次验证（双设备离线编辑 dedupe）

### Phase Ordering Rationale

- **Phase 1→2 先行：** Repository 与手动任务路径是 everything else 的前置；无 AI 也能用的 App 可在 Phase 2 结束时有价值
- **Phase 3 是 critical path：** 1→2→3 验证「导入 → 解析 → 确认 → 今日清单」核心价值；Settings/Keychain 虽可并行但 Parse 依赖 Keychain
- **Phase 4 与 Phase 3 部分并行：** Recurring 不依赖 AI，可在 Phase 3 开发后期启动；但 Phase 5 须等 3+4 基本完成
- **Phase 5 通知放后：** 提醒逻辑依赖完整任务生命周期（含 recurring 实例）；64 条 budget 实现复杂度独立
- **Phase 6 iCloud 放最后：** 避免开发期 sync 干扰调试；模型冻结后再启用 CloudKit，降低 schema 变更风险
- **ReplayKit / Share Extension 不在 MVP roadmap：** 验证手动导入价值后再承担 Extension 复杂度

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3:** DeepSeek Prompt 合约与中文家校群反例分类需 `/gsd-plan-phase --research-phase 3` 做 prompt 工程与黄金截图集基准测试；OCR bounding box 启发式需样验证
- **Phase 5:** 通知 budget 算法（优先级 vs fire date）与 recurring 多 weekday 调度策略需细化
- **Phase 6:** CloudKit schema 迁移与 dedupe merge 策略需对照 Apple DTS 最新实践

Phases with standard patterns (skip research-phase):
- **Phase 1:** SwiftData + Repository 模式有 Apple 官方文档与社区共识
- **Phase 2:** SwiftUI Tab + `@Query` 今日列表是 established pattern
- **Phase 4:** 日历重复任务生成有 MyStudyLife 等先例，确定性键方案已明确

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Apple 官方文档 + DeepSeek API 文档 + OpenSpec 决策一致；版本兼容性已验证 |
| Features | MEDIUM-HIGH | 竞品来自 App Store 官方描述；MVP 边界已与 PROJECT.md/OpenSpec 对齐 |
| Architecture | HIGH | Apple 官方 SwiftData/Vision 文档 + OpenSpec design.md + MVVM 社区共识 |
| Pitfalls | HIGH | SwiftData/CloudKit、Vision OCR、DeepSeek JSON、UNUserNotificationCenter 均有官方或 DTS 来源 |

**Overall confidence:** HIGH

### Gaps to Address

- **中文家校群 Prompt 误报率：** 缺少公开 A/B 数据；Phase 3 须建立 ≥20 张真实微信群截图黄金样本集，人工标注 assigner 准确率目标 ≥80% 或确认页可快速修正
- **「明天」语义（上学日 vs 日历日）：** 用户心智因家庭而异；Phase 3 确认页对 medium/low confidence 强制选日期，可选 Settings「上学日」配置延后验证
- **SwiftData + CloudKit 生产稳定性：** 社区反馈 iOS 18 仍有 edge cases；Phase 6 启用 sync 前须在双设备实测 dedupe
- **OCR 不足时的 VLM fallback 选型：** MVP 不实现；若黄金样本集 OCR 非空率 <95%，Phase 2+ 需评估 Qwen-VL vs Claude Vision 成本
- **DeepSeek 模型退役时间表：** `deepseek-chat` 2026-07-24 退役；须监控 API 公告，Prompt 版本化便于迁移

## Sources

### Primary (HIGH confidence)
- [Apple SwiftData — Syncing model data across devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) — CloudKit 配置、schema 限制
- [Apple Vision — Recognizing Text in Images](https://developer.apple.com/documentation/vision/recognizing-text-in-images) — 中文 OCR `.accurate` 要求
- [DeepSeek API Docs](https://api-docs.deepseek.com/) — V4 模型、JSON Output、定价
- [Apple — Upcoming SDK minimum requirements](https://developer.apple.com/news/?id=ueeok6yw) — iOS 26 SDK / Xcode 26
- [Apple UIPasteboard Documentation](https://developer.apple.com/documentation/uikit/uipasteboard) — 剪贴板隐私模型
- HomeworkPlan PROJECT.md / OpenSpec `extract-mvp-scope` — MVP 范围与架构决策

### Secondary (MEDIUM confidence)
- [Fatbobman — Key Considerations Before Using SwiftData](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) — CloudKit 同步注意事项
- [Todoist Engineering: Local Notification Scheduler](https://www.doist.dev/implementing-a-local-notification-scheduler-in-todoist-ios/) — 64 条上限实践
- [SwiftOrbit — Decoupling SwiftData from SwiftUI](https://swiftorbit.io/decoupling-swiftdata-swiftui-clean-architecture/) — Repository + DI 模式
- 作业小达人 / 优学小助手 / MyStudyLife App Store 描述 — 竞品功能矩阵

### Tertiary (LOW confidence)
- 作业帮 / 小猿 AI 品类边界报道 — 需产品定位验证
- OCR bounding box 左右侧发言人启发式 — 需黄金样本集实测

---
*Research completed: 2026-06-22*
*Ready for roadmap: yes*
