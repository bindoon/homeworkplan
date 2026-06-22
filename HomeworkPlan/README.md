# HomeworkPlan

HomeworkPlan 是一款面向家长的 iOS 作业管理 App（Phase 1 MVP）：手动录入作业、按科目分组展示今日待办、日期浏览、科目管理与 iCloud 同步。

## 环境要求

- macOS + Xcode 26 或更高版本
- iOS 17.0+ 部署目标（Simulator 或真机）
- Apple Developer 账号（启用 iCloud / CloudKit 能力）

## 构建

```bash
cd HomeworkPlan
xcodegen generate
xcodebuild -project HomeworkPlan.xcodeproj -scheme HomeworkPlan \
  -destination 'generic/platform=iOS Simulator' build
```

## 运行单元测试

```bash
xcodebuild -project HomeworkPlan.xcodeproj -scheme HomeworkPlan \
  -destination 'generic/platform=iOS Simulator' \
  -only-testing:HomeworkPlanTests test
```

## 运行 UI 测试

```bash
xcodebuild -project HomeworkPlan.xcodeproj -scheme HomeworkPlan \
  -destination 'generic/platform=iOS Simulator' \
  -only-testing:HomeworkPlanUITests test
```

## iCloud 同步验证步骤

CloudKit 容器 ID：`iCloud.app.homeworkplan.HomeworkPlan`

1. 在 Xcode 中打开 `HomeworkPlan.xcodeproj`，确认 **Signing & Capabilities → iCloud** 已启用，并勾选 CloudKit 容器 `iCloud.app.homeworkplan.HomeworkPlan`。
2. 在 Simulator 或真机上登录同一 Apple ID 的 iCloud 账户。
3. 在设备 A 上创建一条作业（例如「测试同步」）。
4. 等待 1–2 分钟，在设备 B（同一 Apple ID）上打开 App，确认作业出现。
5. 若离线编辑后出现重复科目，App 会在收到远程变更通知后自动合并（`SubjectDedupeService`）；也可重启 App 触发合并。

## 本地持久化最低验证

1. 创建一条作业。
2. 完全关闭 App 后重新启动。
3. 确认作业仍在「今日」或「全部」Tab 中可见。

## 项目结构

```
HomeworkPlan/
├── App/                 # 入口与依赖注入
├── Models/              # SwiftData @Model
├── Repositories/        # 数据访问层
├── Services/Sync/       # CloudKit schema 与去重
├── ViewModels/
├── Views/
└── Resources/           # PrivacyInfo.xcprivacy
```
