# Architecture Research

**Domain:** Local-first iOS homework management app (家长端，手动导入 + AI 解析)
**Researched:** 2026-06-22
**Confidence:** HIGH（Apple 官方文档 + OpenSpec MVP 规格 + 社区 MVVM/SwiftData 共识）

## Standard Architecture

### System Overview

HomeworkPlan MVP 采用 **MVVM + Service Layer + Repository** 三层分离，SwiftData 作为唯一持久化源，iCloud 作为可选同步层。所有网络调用仅发生在 AI 文本解析路径；OCR、通知、重复任务生成均在本地完成。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Presentation Layer                               │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │
│  │  TodayView   │  │  AllTasksView│  │ ImportFlow   │  │ SettingsView│  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘  │
│         │                 │                 │                 │          │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼──────┐  │
│  │TodayViewModel│  │AllTasksVM    │  │ImportVM      │  │SettingsVM   │  │
│  │ReviewVM      │  │ManualTaskVM  │  │RecurringVM   │  │             │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘  │
├─────────┴─────────────────┴─────────────────┴─────────────────┴─────────┤
│                         Domain Layer (Protocols + DTOs)                  │
│  TaskCandidate · ParsedHomework · ImportResult · RecurringSchedule       │
│  TaskRepositoryProtocol · ImportServiceProtocol · ParseServiceProtocol   │
├─────────────────────────────────────────────────────────────────────────┤
│                         Service Layer                                    │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐           │
│  │ImportSvc   │ │OCRService  │ │ParseService│ │RecurringGen│           │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘           │
│  ┌─────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐           │
│  │ReminderSvc │ │KeychainSvc │ │AttachmentSvc│ │DedupService│           │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘           │
├─────────────────────────────────────────────────────────────────────────┤
│                         Data Layer (SwiftData + Repositories)            │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  TaskRepository · SubjectRepository · ImportRecordRepository     │   │
│  │  RecurringRuleRepository · AttachmentRepository                  │   │
│  └───────────────────────────────┬──────────────────────────────────┘   │
│                                  │ ModelContext                          │
│  ┌───────────────────────────────▼──────────────────────────────────┐   │
│  │  SwiftData @Model: HomeworkTask · Subject · RecurringRule        │   │
│  │                  ImportRecord · TaskAttachment                   │   │
│  └───────────────────────────────┬──────────────────────────────────┘   │
│                                  │ ModelConfiguration (CloudKit .automatic)│
│  ┌───────────────────────────────▼──────────────────────────────────┐   │
│  │  Local SQLite Store  ←──sync──→  iCloud Private Database         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘

External (network, on-demand only):
  DeepSeek Text API ←── ParseService (via URLSession)
  Apple Vision      ←── OCRService (on-device, no network)
  UNUserNotificationCenter ←── ReminderService (on-device)
  iOS Keychain      ←── KeychainService (on-device)
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **Views** | 渲染 UI、转发用户手势，不含业务逻辑 | SwiftUI，`@Bindable` ViewModel，简单列表可用 `@Query` |
| **ViewModels** | 屏幕状态、加载/错误态、编排 Service 调用 | `@Observable` + `@MainActor`，依赖注入 protocol |
| **Domain DTOs** | 解析候选、导入结果等 transient 数据，不持久化 | 纯 Swift struct（`TaskCandidate`、`ParseResult`） |
| **ImportService** | 创建 ImportRecord、协调 OCR→Parse 管道、内容哈希去重 | actor 或 struct，调用 OCR + Parse + ImportRecordRepository |
| **OCRService** | 相册截图文字提取 | Vision `VNRecognizeTextRequest`，`recognitionLanguages: ["zh-Hans", "en-US"]` |
| **ParseService** | DeepSeek 调用、Prompt 管理、JSON schema 校验、相对日期归一化 | actor + URLSession，Keychain 读 API Key |
| **TaskRepository** | HomeworkTask CRUD、按日期/科目查询 | SwiftData `ModelContext`，封装 `FetchDescriptor` |
| **RecurringTaskGenerator** | App 启动/前台时按规则生成当日任务，幂等 | 独立 service，写入 TaskRepository |
| **ReminderService** | 本地通知注册、调度、取消 | `UNUserNotificationCenter`，用模型内 UUID 作 identifier |
| **KeychainService** | DeepSeek API Key 安全读写 | Security framework，`kSecClassGenericPassword` |
| **AttachmentService** | 截图/附件本地文件存储 | App Documents 目录 + SwiftData 路径引用 |
| **App Composition Root** | 依赖注入、ModelContainer 创建、生命周期 hook | `HomeworkPlanApp` init + `.modelContainer` + `scenePhase` |

## Recommended Project Structure

```
HomeworkPlan/
├── App/
│   ├── HomeworkPlanApp.swift          # Composition root, DI, lifecycle hooks
│   └── AppDependencies.swift          # 集中构造所有 service/repository
├── Models/                            # SwiftData @Model（持久化实体）
│   ├── HomeworkTask.swift
│   ├── Subject.swift
│   ├── RecurringRule.swift
│   ├── ImportRecord.swift
│   └── TaskAttachment.swift
├── Domain/                            # 非持久化类型 + protocol
│   ├── DTOs/
│   │   ├── TaskCandidate.swift
│   │   └── ParseResult.swift
│   └── Protocols/
│       ├── TaskRepositoryProtocol.swift
│       ├── ImportServiceProtocol.swift
│       └── ParseServiceProtocol.swift
├── Repositories/                      # SwiftData 访问封装
│   ├── TaskRepository.swift
│   ├── SubjectRepository.swift
│   ├── ImportRecordRepository.swift
│   └── RecurringRuleRepository.swift
├── Services/
│   ├── Import/
│   │   ├── ImportService.swift
│   │   ├── OCRService.swift
│   │   └── ContentHashService.swift
│   ├── Parsing/
│   │   ├── ParseService.swift
│   │   ├── HomeworkParsePrompt.swift
│   │   └── ParseResponseValidator.swift
│   ├── Recurring/
│   │   └── RecurringTaskGenerator.swift
│   ├── Reminders/
│   │   └── ReminderService.swift
│   ├── Security/
│   │   └── KeychainService.swift
│   └── Storage/
│       └── AttachmentStorageService.swift
├── ViewModels/
│   ├── TodayViewModel.swift
│   ├── AllTasksViewModel.swift
│   ├── ImportViewModel.swift
│   ├── CandidateReviewViewModel.swift
│   ├── ManualTaskViewModel.swift
│   ├── RecurringRuleViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── Tabs/
│   │   ├── MainTabView.swift
│   │   ├── TodayView.swift
│   │   ├── AllTasksView.swift
│   │   └── SettingsView.swift
│   ├── Import/
│   │   ├── ImportSourcePickerView.swift
│   │   ├── PasteImportView.swift
│   │   └── CandidateReviewView.swift
│   ├── Tasks/
│   │   ├── TaskRowView.swift
│   │   ├── ManualTaskFormView.swift
│   │   └── TaskEditView.swift
│   └── Recurring/
│       └── RecurringRuleFormView.swift
└── Resources/
    └── PrivacyInfo.xcprivacy            # App Store 必需
```

### Structure Rationale

- **Models/ vs Domain/：** SwiftData `@Model` 与 UI/测试用的纯 struct 分离，避免测试必须启动 ModelContainer，也为后续 ReplayKit Extension 共享 DTO 预留空间。
- **Repositories/ vs Services/：** Repository 只管 CRUD 与查询；跨 feature 的业务编排（导入管道、重复生成、通知联动）放 Service。
- **ViewModels/ 按屏幕拆分：** 导入确认流（CandidateReview）独立 ViewModel，避免 ImportViewModel 膨胀。
- **App/ 作为 Composition Root：** 所有依赖在此组装并注入，ViewModel 不在内部 `new` 具体实现。

## Architectural Patterns

### Pattern 1: MVVM with @Observable ViewModels (iOS 17+)

**What:** View 绑定 `@Observable` ViewModel；ViewModel 持有 protocol 类型依赖，暴露 `@MainActor` 方法与 UI 状态。
**When to use:** 所有需要 loading/error/多步交互的屏幕（导入、确认、设置）。
**Trade-offs:** 比 `@Query` 直连多一层代码，但导入/确认/通知编排逻辑有明确归属；测试可 mock repository。

**Example:**
```swift
@Observable @MainActor
final class ImportViewModel {
    private let importService: any ImportServiceProtocol
    var phase: ImportPhase = .idle
    var candidates: [TaskCandidate] = []

    init(importService: any ImportServiceProtocol) {
        self.importService = importService
    }

    func importScreenshot(_ image: UIImage) async {
        phase = .processing
        do {
            let result = try await importService.processScreenshot(image)
            candidates = result.candidates
            phase = .review
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
```

### Pattern 2: Import Pipeline (Staging → Parse → Confirm → Persist)

**What:** 导入内容先写入 `ImportRecord`（含 OCR 文本、内容 SHA256），再产生 transient `TaskCandidate`，用户确认后才调用 `TaskRepository` 持久化。
**When to use:** 所有非手动录入路径（截图、粘贴、未来 ReplayKit）。
**Trade-offs:** 多一步确认 UI，但符合家长场景「误报代价高」的产品决策；ImportRecord 提供溯源与去重。

**Example:**
```swift
// ImportService orchestrates; ParseService knows nothing about SwiftData
func processText(_ text: String, source: ImportSource) async throws -> ImportPipelineResult {
    let hash = contentHashService.sha256(text)
    if try await importRecordRepo.exists(hash: hash) {
        throw ImportError.duplicate
    }
    let record = try await importRecordRepo.create(text: text, hash: hash, source: source)
    let candidates = try await parseService.parse(text: text, referenceDate: record.createdAt)
    return ImportPipelineResult(recordID: record.id, candidates: candidates)
}
```

### Pattern 3: Repository over Raw ModelContext

**What:** ViewModel/Service 不直接 `@Environment(\.modelContext)`；通过 Repository protocol 访问 SwiftData。
**When to use:** 所有持久化读写；Today 列表等简单场景可用 `@Query` 读，写操作仍走 Repository。
**Trade-offs:** 少量 boilerplate，换存储或写单元测试时收益大。

### Pattern 4: Lifecycle-Driven Recurring Generation

**What:** `RecurringTaskGenerator` 在 `scenePhase == .active` 或 app launch 时运行，按 `(ruleID, date)` 确定性键幂等生成任务。
**When to use:** 重复任务（每日练字等）；与 iCloud 多设备同步配合时需 deterministic key 防重复。
**Trade-offs:** 不在后台 silent push 生成；依赖用户打开 App——对 MVP 可接受。

### Pattern 5: ReminderService as Side-Effect Bridge

**What:** Task 保存/完成/删除后，由 Repository 或 thin coordinator 调用 `ReminderService.schedule/cancel`；通知 ID 使用模型内持久化 `UUID`，不用 `PersistentIdentifier.hashValue`（跨启动不稳定）。
**When to use:** 所有提醒相关操作。
**Trade-offs:** 需维护 notification ID 与 task 生命周期同步；编辑 due date 时要 reschedule。

## Data Flow

### Request Flow (General)

```
User Action (View)
    ↓ tap/gesture
ViewModel (@MainActor)
    ↓ async call
Service / Repository
    ↓
SwiftData ModelContext.save()  OR  URLSession (DeepSeek)  OR  Vision OCR
    ↓
ViewModel updates @Observable state
    ↓
View re-renders (Observation)
```

### State Management

```
SwiftData (@Model)          ← source of truth for persisted data
    ↓ FetchDescriptor / @Query
ViewModel (derived UI state) ← grouping, filters, transient import phase
    ↓ @Observable
SwiftUI Views
```

Transient state（导入进度、解析候选、表单草稿）只存 ViewModel/DTO，**确认前不写 HomeworkTask**。

### Key Data Flows

#### 1. Screenshot Import Flow

```
PhotoPicker
  → ImportViewModel.importScreenshot(image)
    → AttachmentStorageService.save(image)           # 本地文件
    → OCRService.recognizeText(image)                # Vision, on-device
    → ContentHashService.sha256(text)
    → ImportRecordRepository.create(...)             # 持久化导入记录
    → ParseService.parse(text, referenceDate:)       # DeepSeek API
    → ParseResponseValidator.validate(json)          # schema 校验
    → [TaskCandidate] → CandidateReviewViewModel     # transient
  → User confirms/edits/discards each candidate
    → TaskRepository.create(from: candidate)         # 持久化 HomeworkTask
    → ReminderService.schedule(for: task)            # 若有 due date
    → ImportRecordRepository.link(tasks)             # 溯源
```

**Direction:** 单向向下写入；解析失败不创建 Task，仅更新 ImportRecord 状态。

#### 2. Paste Import Flow

```
PasteImportView / ClipboardDetector (on foreground)
  → ImportViewModel.importText(text)
    → [same pipeline as above, skip OCR]
```

#### 3. Today List Flow

```
TodayView
  → @Query(filter: dueToday, sort: subject)   # 简单读路径
  OR TodayViewModel.load() via TaskRepository.fetchDue(on: Date())
  → group by Subject.sortOrder
  → User marks complete
    → TaskRepository.markComplete(id)
    → ReminderService.cancel(for: task)
```

#### 4. Recurring Task Generation Flow

```
App/scenePhase → .active
  → RecurringTaskGenerator.generateForToday()
    → RecurringRuleRepository.fetchActive()
    → for each rule matching today:
        deterministicKey = "\(rule.id)-\(yyyy-MM-dd)"
        if !TaskRepository.exists(generationKey: key):
          TaskRepository.create(from: rule, date: today, key: key)
          ReminderService.schedule(for: newTask)
    → RecurringRuleRepository.updateLastGeneratedDate(rule, today)
```

#### 5. Settings / API Key Flow

```
SettingsViewModel.saveAPIKey(key)
  → KeychainService.store(key)
ParseService.parse(...)
  → KeychainService.retrieve()  # 无 key 则 UI 引导去设置
```

## Suggested Build Order

依赖关系决定 phase 顺序；每层完成后应有可运行 vertical slice。

| Order | Component / Phase | Depends On | Delivers |
|-------|-------------------|------------|----------|
| **1** | Xcode project + SwiftData models + ModelContainer | — | 可编译，空 App 启动 |
| **2** | Repositories (Task, Subject) + seed default subjects | 1 | 可读写任务数据 |
| **3** | MainTabView + TodayView + ManualTaskForm | 2 | 手动添加 + 今日列表（核心价值骨架） |
| **4** | AllTasksView + date browsing + edit/delete/complete | 3 | 完整任务 CRUD |
| **5** | KeychainService + Settings (API Key, reminder prefs) | 1 | AI 与通知前置配置 |
| **6** | OCRService + AttachmentStorage | 1 | 本地 OCR 可独立验证 |
| **7** | ParseService + ImportRecord + Import pipeline | 5, 6 | 截图/粘贴 → 候选（未确认） |
| **8** | CandidateReviewView + confirm flow | 4, 7 | 导入 → 确认 → 保存闭环 |
| **9** | RecurringRule CRUD + RecurringTaskGenerator | 2, 4 | 每日固定任务自动生成 |
| **10** | ReminderService + notification permission UX | 4, 5, 9 | 截止日与重复提醒 |
| **11** | iCloud sync (CloudKit `.automatic`) + duplicate generation hardening | 2, 9 | 多设备同步 |
| **12** | Clipboard detect on foreground + polish | 7, 8 | MVP 完整体验 |

**Critical path:** 1 → 2 → 3 → 7 → 8（验证「导入 → 解析 → 确认 → 今日清单」核心价值）

**Parallelizable after step 3:** OCR (6) 与 Settings (5) 可并行；Recurring (9) 与 Import (7–8) 可并行，但 Reminder (10) 需两者基本完成。

### Build Order Diagram

```
[1 Models+Container]
        │
   ┌────┴────┐
   ▼         ▼
[2 Repos]  [5 Keychain/Settings]
   │
   ▼
[3 Today+Manual] ──→ [4 All Tasks CRUD]
   │                        │
   ├──────────┐             │
   ▼          ▼             ▼
[6 OCR]   [9 Recurring]  [10 Reminders]
   │          │             │
   ▼          └──────┬──────┘
[7 Parse+Import]    │
   │                │
   ▼                │
[8 Confirm Flow]────┘
   │
   ▼
[11 iCloud sync]
   │
   ▼
[12 Clipboard + polish]
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 自用 MVP (1 user, 1 child) | 单 target monolith 足够；`@Query` 直读可接受 |
| 多孩子 / 多设备 (100–1K tasks) | Subject/Task 加索引；Recurring 生成键强制唯一约束；Reminder 批量 reschedule 放后台 |
| 录屏自动化扩展 (Phase 2+) | Broadcast Extension 写 App Group 共享目录 → 同一 ImportService 入口；不新建 task 创建路径 |
| 后端 / 钉钉机器人 (远期) | 新增 `RemoteImportAdapter` 产出 ImportRecord，核心 Repository/Service 不变 |

### Scaling Priorities

1. **First bottleneck:** DeepSeek 解析延迟与失败率 → ParseService 内重试 + 离线队列（ImportRecord 标记 pending）；UI 显示解析进度。
2. **Second bottleneck:** iCloud 同步导致 recurring 重复任务 → `(ruleID, date)` 唯一 generationKey + CloudKit conflict 策略在 Repository 层处理。
3. **Third bottleneck:** 通知数量上限（iOS 64 pending）→ ReminderService 只调度近期任务（如今日起 7 天内），完成/过期自动清理。

## Anti-Patterns

### Anti-Pattern 1: View 直接调用 DeepSeek / Vision

**What people do:** 在 `ImportView` 的 button action 里写 URLSession 或 VNRequest。
**Why it's wrong:** 无法测试、Prompt/schema 散落、后续换模型或加 Extension 需复制代码。
**Do this instead:** 所有外部 IO 经 Service；View 只调用 ViewModel。

### Anti-Pattern 2: 解析结果自动写入 HomeworkTask

**What people do:** ParseService 返回后直接 `modelContext.insert(task)`。
**Why it's wrong:** 违反 MVP「用户确认后才保存」；家长场景误报破坏信任。
**Do this instead:** 解析产出 `TaskCandidate` DTO → CandidateReview 屏 → 用户确认 → TaskRepository。

### Anti-Pattern 3: ViewModel 持有 ModelContext

**What people do:** `@Environment(\.modelContext)` 注入 ViewModel，或直接 `import SwiftData`。
**Why it's wrong:** ViewModel 与 SwiftData 耦合，Preview/测试需完整容器；违反依赖倒置。
**Do this instead:** 注入 `TaskRepositoryProtocol`；Composition Root 构造具体 Repository。

### Anti-Pattern 4: 用 PersistentIdentifier 作通知 identifier

**What people do:** `task.persistentModelID.hashValue.description` 作为 UNNotificationRequest ID。
**Why it's wrong:** Apple 文档明确 hashValue 跨启动不稳定，导致 cancel/reschedule 失效。
**Do this instead:** HomeworkTask 模型内持久化 `notificationID: UUID`，创建 task 时生成。

### Anti-Pattern 5: 业务逻辑堆在 @Query View

**What people do:** TodayView 内 inline 分组、完成回调、通知调度。
**Why it's wrong:** 导入/重复/提醒逻辑重复出现在多个 View；难以单元测试。
**Do this instead:** 简单列表可用 `@Query` 读；写操作与跨 cutting 逻辑进 ViewModel/Service。

### Anti-Pattern 6: 录屏/Extension 专用 Task 创建路径

**What people do:** 为未来 ReplayKit 单独写一套 `createTaskFromCapture()`。
**Why it's wrong:** 与手动导入分叉，MVP 服务边界设计目标失效。
**Do this instead:** 任何输入源最终产出 `ImportRecord` + 相同 Parse/Confirm 管道（design.md 已明确）。

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **DeepSeek Text API** | ParseService via URLSession, API Key from Keychain | 仅文本输入；temperature=0；离线时 ImportRecord 标记 pending |
| **Apple Vision OCR** | OCRService, `VNRecognizeTextRequest` accurate + zh-Hans | 全本地；Extension 未来可复用同一 service 接口 |
| **UNUserNotificationCenter** | ReminderService actor/class | 首次需提醒时再请求权限；UUID identifier |
| **iCloud / CloudKit** | SwiftData `ModelConfiguration(cloudKitDatabase: .automatic)` | MVP 可先 local-only，模型稳定后开启；与现有 CloudKit app 冲突时用 `.none` |
| **iOS Keychain** | KeychainService | Generic password item；Settings 屏配置 |
| **Photo Library** | PHPickerViewController → UIImage → ImportService | MVP 应用内选择；Share Extension 延后 |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| View ↔ ViewModel | `@Bindable` / method calls | View 不含 async 业务 |
| ViewModel ↔ Service | async protocol methods | ViewModel 编排多 service 调用顺序 |
| Service ↔ Repository | sync/async CRUD | Service 不直接访问 ModelContext |
| TaskRepository ↔ ReminderService | Task save/update/delete hooks | 可在 Repository 内调用或 AppCoordinator 统一 dispatch |
| ImportService ↔ ParseService | text + referenceDate in, `[TaskCandidate]` out | ParseService 无 SwiftData 依赖 |
| RecurringGenerator ↔ TaskRepository | generationKey 幂等写入 | 必须在 foreground lifecycle 触发 |
| Future Extension ↔ Main App | App Group 共享目录 + 同一 ImportService 入口 | Extension 只做 OCR/写文件，不做 DeepSeek 调用（可选，降 Extension 复杂度） |

## Sources

- [Apple SwiftData — Syncing model data across devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) — CloudKit `.automatic` / `.none` 配置（HIGH）
- [Apple Vision — Recognizing Text in Images](https://developer.apple.com/documentation/vision/recognizing-text-in-images) — 本地 OCR，中文需 `zh-Hans`（HIGH）
- [Apple SwiftData — ModelContext.save()](https://developer.apple.com/documentation/swiftdata/modelcontext/save()) — 持久化最佳实践（HIGH）
- Project: `docs/PRD.md` — 数据模型、服务层划分、路线图（HIGH）
- Project: `openspec/changes/extract-mvp-scope/design.md` — MVP 手动导入、确认流、服务边界（HIGH）
- Project: `openspec/changes/extract-mvp-scope/specs/*` — 导入、解析、重复、提醒需求（HIGH）
- [Decoupling SwiftData from SwiftUI (SwiftOrbit)](https://swiftorbit.io/decoupling-swiftdata-swiftui-clean-architecture/) — Repository + DI 模式（MEDIUM）
- [SwiftUI MVVM iOS 17+ (Soarias)](https://soarias.com/swiftui/how-to-implement-mvvm-architecture/) — `@Observable` ViewModel 实践（MEDIUM）
- [Notification identifier stability (Stack Overflow)](https://stackoverflow.com/questions/79281776/) — 不用 PersistentIdentifier hashValue（MEDIUM，与 Apple Hashable 文档一致）

---
*Architecture research for: HomeworkPlan — 小学生作业管理 iOS App*
*Researched: 2026-06-22*
