# HomeworkPlan

HomeworkPlan 是一款面向家长的 iOS 作业管理 App：手动录入作业、按科目分组展示今日待办、日期浏览、科目管理。**所有数据仅保存在本机**（SwiftData 本地 SQLite），不使用 iCloud / CloudKit。

## 环境要求

- macOS + Xcode 26 或更高版本
- iOS 17.0+ 部署目标（Simulator 或真机）
- Apple Developer 账号（真机调试签名）

## AI 解析配置（本地，不提交 Git）

```bash
cp Config/Secrets.env.example Config/Secrets.env
# 编辑 Secrets.env，填入 DashScope API Key 与模型名
#   LLM_MODEL      — 文本解析，如 deepseek-v4-flash
#   VISION_MODEL   — 截图识图，如 qwen-vl-plus（留空则走本地 OCR + 文本模型）
```

编译时会自动生成 `App/GeneratedSecrets.swift` 并写入 App。设置页中的 API Key 仍可覆盖本地编译配置。

截图导入流程：优先 Apple Vision 本地 OCR + `LLM_MODEL` 文本解析；仅当 OCR 失败且配置了 `VISION_MODEL` 时，才降级为云端识图。

## 构建

```bash
cd HomeworkPlan
xcodegen generate
xcodebuild -project HomeworkPlan.xcodeproj -scheme HomeworkPlan \
  -destination 'generic/platform=iOS Simulator' build
```

## 运行测试

```bash
xcodebuild -project HomeworkPlan.xcodeproj -scheme HomeworkPlan \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## 本地持久化验证

1. 创建一条作业。
2. 完全关闭 App 后重新启动。
3. 确认作业仍在「今日」或「全部」Tab 中可见。

## 项目结构

```
HomeworkPlan/
├── App/                 # 入口与依赖注入
├── Models/              # SwiftData @Model
├── Repositories/        # 数据访问层
├── Services/            # OCR、解析、提醒等
├── ViewModels/
├── Views/
└── Resources/           # PrivacyInfo.xcprivacy
```
