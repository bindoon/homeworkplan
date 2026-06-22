# Pitfalls Research

**Domain:** 本地优先 iOS 小学生作业管理 App（家长端，OCR + DeepSeek 文本解析）
**Researched:** 2026-06-22
**Confidence:** HIGH（SwiftData/CloudKit、Vision OCR、DeepSeek JSON、UNUserNotificationCenter 均有官方或 Apple DTS 来源）；MEDIUM（中文家校群内容分类，基于产品文档与社区实践，缺少公开 A/B 数据）

## Critical Pitfalls

### Pitfall 1: Vision OCR 把聊天截图压成「文字汤」，丢失发言人结构

**What goes wrong:**
微信/钉钉截图经 Vision OCR 后变成按行排列的纯文本，气泡左右对齐、头像、时间戳等布局信息全部丢失。DeepSeek 无法可靠区分「张老师布置的作业」与「李妈妈接龙回复」，导致误提取家长闲聊、接龙回复、团购信息为作业任务。

**Why it happens:**
开发者假设「OCR 准确率 95%+ = 解析可用」，但 Vision 的设计目标是识别文字而非重建对话结构。MVP 刻意不用 VLM，却未在 OCR 层保留任何 layout 元数据（bounding box、左右侧归属）。

**How to avoid:**
- OCR 服务输出时保留 `VNRecognizedTextObservation` 的 bounding box，按 Y 坐标排序后标注「左/右/居中」启发式（群聊中右侧多为本人，左侧多为他人——仅作 LLM 提示，不作硬规则）。
- 确认页同时展示：原图缩略图 + OCR 原文 + 解析候选，让用户对照气泡修正。
- Prompt 明确要求：仅提取「疑似老师/家委/机构老师」发布的作业指令；对无法判断发言人的段落标记 `confidence: low`。
- 为 Phase 2+ 预留 VLM 回退路径（低置信度截图可走 Qwen-VL/Claude Vision），不在 MVP 强推。

**Warning signs:**
- 测试截图中家长回复「收到」被解析为独立作业项
- DeepSeek 返回的 `assigner` 字段大量为空或与 OCR 文本不匹配
- 同一截图多次解析结果波动大

**Phase to address:**
Phase 2（采集 + AI 解析）— OCR 服务设计与确认 UI 必须同阶段完成，不可拆到「后续优化」

---

### Pitfall 2: 把 DeepSeek JSON Mode 当成 Schema 保证

**What goes wrong:**
设置 `response_format: { type: "json_object" }` 后仍出现：空 content、JSON 被 `max_tokens` 截断（`finish_reason: length`）、字段类型漂移（日期变中文描述）、多余 markdown 包裹。App 直接 `JSONDecoder` 崩溃或 silently drop 导入。

**Why it happens:**
DeepSeek 官方文档明确：JSON Mode 保证「语法合法 JSON」，不保证字段级 schema；且可能返回空内容。开发者从 OpenAI Structured Outputs 经验迁移，跳过客户端校验与重试。

**How to avoid:**
- 定义本地 `Codable` schema + 宽松解析层（未知字段忽略、必填字段缺失则标记候选为 incomplete）。
- 每次响应检查 `finish_reason`；为 `length` 时提高 `max_tokens` 并重试一次。
- System prompt 必须含单词 `"json"` 并提供 EXAMPLE JSON（DeepSeek 硬性要求）。
- `temperature = 0`；相同 OCR 文本 SHA256 去重后再调用 API。
- 解析失败 → 展示 OCR 原文 +「手动录入」入口，不阻断用户。

**Warning signs:**
- 生产环境偶发 `JSONDecoder` 解码错误且无用户可见 fallback
- 日志里 `finish_reason: length` 与截断 JSON 共存
- 集成测试只覆盖「完美响应」样例

**Phase to address:**
Phase 2（采集 + AI 解析）— 解析服务、Prompt 合约、错误 UX 同批交付

---

### Pitfall 3: 中文家校群「作业 / 接龙 / 打卡 / 通知」混为一谈

**What goes wrong:**
LLM 把「接龙管家打卡」「健康上报」「团购接龙」「明天带跳绳」全部提取为 HomeworkTask。家长清单被无关项淹没，信任迅速下降；或漏掉嵌在长通知里的真实作业（「详见下方第三条」）。

**Why it happens:**
中国班级群高度依赖小程序（班级小管家、接龙管家）和模板化通知。文本表面都含「请家长」「今日」等词，语义边界模糊。Prompt 只写「提取作业」而无反例。

**How to avoid:**
- Prompt 内置反例分类：`homework` / `check_in`（打卡签到）/ `collection`（接龙填表）/ `notice`（纯通知）/ `noise`（闲聊）。
- 默认只 persist `homework` 类型；其他类型在确认页折叠展示，用户可手动提升。
- 识别关键词启发式（非硬过滤）：「打卡」「接龙」「填表」「签字」→ 默认降权。
- 确认 UI 支持批量 discard，减少逐项删除摩擦。

**Warning signs:**
- 真实用户截图测试中 >30% 候选需手动删除
- 用户反馈「全是打卡不是作业」
- `ImportRecord` 中大量任务被标记完成但孩子并未收到作业

**Phase to address:**
Phase 2（Prompt 设计）+ Phase 3（确认交互打磨）

---

### Pitfall 4: 相对日期「明天 / 下节课 / 本周五前」锚点错误

**What goes wrong:**
「明天交」在周日晚上导入被算成周一，但用户心智是「下一个上学日」；「下节课前」被算成当天；跨零点导入时日期整体偏移一天。截止日期错误的任务要么漏提醒，要么错误提醒。

**Why it happens:**
LLM 自行推断日期但未传入可靠 `importTimestamp`、`timezone`、`locale`。开发者把解析出的日期字符串直接 `DateFormatter` 解析，未在确认页高亮 uncertain 字段。

**How to avoid:**
- 每次解析请求携带：`importedAt`（ISO8601）、`deviceTimeZone`、`schoolWeekContext`（可选：用户设置「上学日」）。
- JSON schema 要求：`dueDate` + `dueDateConfidence`（high/medium/low）+ `dueDateRawText`。
- `medium/low` 时在确认页预选「今天」或留空，强制用户点选日期。
- 单元测试覆盖：周日 22:00 导入「明天」、节假日、「本周五」等边界。

**Warning signs:**
- 截止日期字段在确认页几乎从不被用户修改（说明过度自信）
- 提醒在错误日期触发
- 同一截图在不同时间导入产生不同 due date 且无提示

**Phase to address:**
Phase 2（解析合约）+ Phase 3（确认 UI 日期控件）

---

### Pitfall 5: SwiftData + CloudKit 重复记录（任务、科目、重复规则、导入）

**What goes wrong:**
两台 iPhone 或「离线创建 + 随后同步」后，出现重复科目「语文」、同一重复规则生成两份「每日练字」、同一导入哈希对应两条 ImportRecord。Apple DTS 确认：`NSPersistentCloudKitContainer` **不支持 unique constraints**，重复数据需应用层自行合并。

**Why it happens:**
MVP 先本地开发、后开 iCloud；或 `@Model` 属性缺少默认值导致 CloudKit 反序列化失败后的重试产生副本；或各设备独立 `UUID()` 生成「相同语义」实体。

**How to avoid:**
- **Day 1** 在 Xcode 创建 CloudKit Container ID，即使初版仅本地存储（后期迁移代价极高）。
- 所有 `@Model` 属性：默认值或 Optional（CloudKit 反序列化 bypass `init`）。
- 业务唯一键：`ImportRecord.contentHash`、`RecurringRule.id + date` 生成键、`Subject.normalizedName`。
- 监听 `NSPersistentStoreRemoteChange`，后台 dedupe merge（keeper 选 metadata 更完整者）。
- 重复任务生成使用确定性 ID：`"\(ruleId)-\(yyyy-MM-dd)"`，插入前 fetch 存在则 skip。

**Warning signs:**
- 今日列表出现两条相同内容的待办
- 设置页科目列表重复
- App 升级后首次启动数据量翻倍（Apple Forums #772007 典型症状）

**Phase to address:**
Phase 1（数据层 + SwiftData 模型设计）— 唯一键与 dedupe 策略必须在启用 iCloud 前落地

---

### Pitfall 6: 重复任务每次启动都重新生成（非幂等）

**What goes wrong:**
`scenePhase == .active` 或 App 启动时无条件 insert 今日任务，导致同一规则每天产生 2–N 条重复待办；配合 iCloud 同步后多设备倍增。

**Why it happens:**
用「上次生成日期 < 今天」作判断但未持久化原子更新；多线程/多设备并发；生成与 `lastGeneratedDate` 更新非同一事务。

**How to avoid:**
- 生成前先 fetch：`predicate = ruleId AND dueDate == todayStart`。
- 使用确定性 `task.id` 或 `generationKey`，CloudKit 冲突时可识别同一 logical task。
- `lastGeneratedDate` 与 insert 在同一 `ModelContext.save()` 事务。
- 规则暂停/删除时 cascade 取消关联 pending 通知。

**Warning signs:**
- 调试时多次切前后台，今日列表任务数递增
- 完成一条「每日练字」后仍剩一条同名未完成

**Phase to address:**
Phase 4（重复任务 + 自动生成）

---

### Pitfall 7: 本地通知静默失效（64 上限、误删、权限假象）

**What goes wrong:**
用户设置了提醒却从不触发；或只有第一天有效之后全部消失；Simulator 上「测过了」上线真机失败。常见根因：iOS **64 条 pending 上限** silently drop 最旧通知；`removeAllPendingNotificationRequests()` 与 `add` 竞态导致新通知被删；`add()` 在用户拒绝权限时仍返回 success。

**Why it happens:**
为每个任务每条提醒各建 UUID 通知； reschedule 时先 `removeAll` 再 bulk add；只在 Simulator 验证；未实现 `UNUserNotificationCenterDelegate` 导致前台不显示（误以为没调度）。

**How to avoid:**
- 通知 ID 规范：`task-{taskId}-morning` / `recurring-{ruleId}-{weekday}`，更新时 replace 而非叠加。
- Reschedule：先 `getPendingNotificationRequests()`，按 category 过滤后 **仅删除本 App 相关 ID**，禁止 `removeAll`。
- 调度前 `getNotificationSettings()`，未授权时引导 Settings，不假装已提醒。
- 实现 notification budget：按 fire date + 优先级保留最近 64 条。
- **真机**验证；Simulator 不可靠。
- 任务完成/删除/改期时同步 cancel + reschedule。

**Warning signs:**
- `getPendingNotificationRequests().count` 长期 = 64
- 代码库中存在 `removeAllPendingNotificationRequests`
- 用户授权后仍无通知，但 pending 列表为空

**Phase to address:**
Phase 5（本地通知 + 提醒设置）

---

### Pitfall 8: 剪贴板「自动检测」触发 iOS 粘贴权限弹窗，破坏信任

**What goes wrong:**
App 进入前台就读取 `UIPasteboard.general.string`，iOS 16+ 每次弹出「Allow Paste from WeChat?」。家长感到 App 在「偷窥剪贴板」，即使只想检测新作业文本。

**Why it happens:**
PRD 要求「打开 App 自动检测剪贴板新内容」，但 iOS 隐私模型要求 **用户意图** 才能读 pasteboard 内容。`hasStrings` 只能知有无，不能读内容。

**How to avoid:**
- 默认不用后台静默读剪贴板；改用明确入口：「粘贴导入」按钮 + `UIPasteControl`（iOS 16+）或 TextEditor paste。
- 若需提示「可能有新内容」：仅用 `hasStrings` / `detectedPatterns(for:)` 显示 banner「点击粘贴」，用户点击后再读。
- 记录上次 processed hash，避免重复提示同一内容。

**Warning signs:**
- 首次进入主页即出现系统 Paste 权限弹窗
- 用户拒绝 paste 后功能完全不可用且无手动路径

**Phase to address:**
Phase 2（粘贴导入 UX）— 与相册导入同期设计

---

### Pitfall 9: OCR 配置错误导致中文识别失败或 Preview 与 App 不一致

**What goes wrong:**
部分截图在 Preview/Live Text 可选中，但 App 内 OCR 返回 0 observations；或中文被识别为乱码英文。Dark Mode 截图、压缩 JPEG、贴边文字是重灾区。

**Why it happens:**
未设置 `recognitionLanguages = ["zh-Hans", "zh-Hant"]`；使用 `.fast` 而非 `.accurate`；未处理 `CGImage` 方向；贴边文字缺少 margin padding（Stack Overflow #79146582：加 ~40px 白边可修复）。

**How to avoid:**
- 固定 `recognitionLevel = .accurate`，`recognitionLanguages = ["zh-Hans", "zh-Hant"]`。
- 预处理 pipeline：correct orientation → 可选 white padding → OCR。
- OCR 失败时展示「识别失败，请手动输入或换一张截图」，保留原图。
- 建立 **真实微信群截图** 黄金样本集（≥20 张）回归测试，不只用印刷体测试图。

**Warning signs:**
- 测试集仅包含清晰印刷 PDF，无真实聊天截图
- OCR 结果为空时无 UI 反馈，用户卡在空白确认页

**Phase to address:**
Phase 2（OCR 服务）— Phase 0 技术验证可先做 OCR 样本集基准测试

---

### Pitfall 10: 导入去重哈希基于不稳定 OCR 文本

**What goes wrong:**
同一张截图两次导入，OCR 因语言 correction 或边界框顺序产生细微差异，SHA256 不同 → 重复调用 DeepSeek、重复候选任务。或相反：不同作业 OCR 文本碰巧相同 → 错误 skip。

**Why it happens:**
对 raw OCR 字符串直接 hash；未 normalize（trim、合并空白、统一标点、排序行）。

**How to avoid:**
- Normalize pipeline：`trim` → 折叠 whitespace → 全角半角标点统一 → 可选去掉 OCR 置信度极低行。
- 去重键：`hash(normalizedText)` + `sourceType`；图片导入额外记录 `imagePerceptualHash` 或 asset ID。
- 去重范围：仅跳过 **API 调用**，仍允许用户主动「再次导入」同内容（长按 force re-parse）。

**Warning signs:**
- 同一截图连续导入产生两次 API 账单
- ImportRecord 表出现大量近似重复 rawText

**Phase to address:**
Phase 2（ImportRecord + 解析服务）

---

### Pitfall 11: 跳过「用户确认」直接持久化 AI 结果

**What goes wrong:**
为降低摩擦 auto-save 高置信度候选，一条误解析的「明天带红色跳绳」进入今日清单；家长不再信任 App，回到微信群手动核对——产品核心价值崩塌。

**Why it happens:**
Demo 阶段图方便；或仅对 `confidence == high` auto-save，但 LLM 过度自信是中国家校场景的常态。

**How to avoid:**
- **硬规则**：任何 AI 路径都必须经确认页；无 `autoSave` 开关（MVP）。
- 确认页默认「全选待审」而非「全选接受」。
- Persist 时写入 `sourceType` + `ImportRecord` 链路，便于溯源与撤销。

**Warning signs:**
- 代码路径存在 `if candidate.confidence > 0.9 { save() }`
- 用户无法在保存前看到完整 OCR 原文

**Phase to address:**
Phase 2–3（解析 → 确认 → 持久化边界）

---

### Pitfall 12: API Key 存 UserDefaults 或硬编码

**What goes wrong:**
Key 被 iCloud 备份、日志、crash report 泄露；审核或分享 TestFlight 构建时密钥外泄。HomeworkPlan 约束明确要求 Keychain。

**Why it happens:**
Keychain API 样板代码多，开发者先用 UserDefaults「临时」后忘记迁移。

**How to avoid:**
- 仅通过 Security framework / Keychain Services 读写；Settings 页 masked 显示。
- 首次解析前 gating：无 Key 则引导配置，不发起网络请求。
- 禁止把 Key 写入 SwiftData（会进 iCloud）。

**Warning signs:**
- `UserDefaults.standard.set(apiKey` 出现在代码库
- HomeworkTask 或 Settings model 含 `apiKey` 字段

**Phase to address:**
Phase 2（Settings + 解析服务初始化）

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| 初版 SwiftData 纯本地，稍后再配 CloudKit Container | 加快第一周开发 | 已有用户数据无法平滑迁移 iCloud；双轨用户体验 | **Never** — PROJECT 已要求 iCloud，Container ID Day 1 创建 |
| OCR 只输出 plain string，不存 bounding box | OCR 服务简单 | 无法改进发言人推断；VLM 回退缺少中间态 | MVP 可接受 **仅当** 确认页必展示原图 + 接受误报由用户修正 |
| 通知 reschedule 时 `removeAllPendingNotificationRequests` | 代码 3 行搞定 | 竞态删除新通知；Reminder 随机失效 | **Never** |
| 重复任务用 UUID 作 notification / task ID | 实现快 | 无法 update-in-place；duplicate 堆积 | **Never** |
| Prompt 放硬编码字符串，无版本号 | 快速迭代 | 无法 A/B 或回滚；ImportRecord 存了 JSON 却对不上 prompt 版本 | MVP 末期前必须引入 PromptVersion 常量 |
| 仅支持竖屏聊天截图 OCR | 忽略横屏/ iPad 分屏 | 部分钉钉/iPad 用户导入失败 | Phase 3 打磨前可 defer，但需在 PITFALLS 标注 |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Apple Vision OCR | 默认英语；`.fast` 模式；不处理 image orientation | `zh-Hans`/`zh-Hant` + `.accurate` + orientation fix + 可选 padding |
| DeepSeek Chat API | 无 `response_format`；不检查 `finish_reason`；prompt 不含 "json" | JSON mode + schema 校验 + retry + 手动 fallback |
| DeepSeek（离线/弱网） | 解析失败即丢失用户粘贴内容 | 队列待处理 ImportRecord，`NWPathMonitor` 恢复后重试 |
| SwiftData + CloudKit | 非 Optional 属性无默认值；期望 DB unique | 全属性 default/optional；应用层 dedupe + 业务唯一键 |
| UIPasteboard | 前台自动读 `string` | `UIPasteControl` / 显式粘贴；`hasStrings` 仅作 hint |
| UNUserNotificationCenter | 以为 `add` 失败会 throw；不处理 delegate | 查 authorization；stable ID；真机测试；budget manager |
| PHPhotoPicker 截图 | 直接 OCR 缩略图 | 请求原图或高质量 representation；EXIF orientation |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| 全分辨率 OCR 不 downscale | 导入卡顿 3–10s | 长边限制 ~2048px 再 OCR；progress UI | 长图聊天记录 >4000px |
| 每次 foreground 全量 reschedule 通知 | 启动延迟、竞态 | TaskQueue 串行化；diff pending vs desired | >50 活跃任务 + 重复规则 |
| 主线程 OCR + 网络解析 | UI hitch | OCR 在 background；解析 async | 任何大图导入 |
| ImportRecord 永久存原图 + JSON | iCloud 配额膨胀 | 可配置保留策略；确认后压缩截图 | 数月日常导入 |
| 今日列表 fetch 无 predicate | 任务增多后 Tab 切换慢 | `@Query` filter `dueDate == today` | >500 历史任务 |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| API Key 存 UserDefaults / SwiftData | 密钥随备份/同步泄露 | Keychain only；Settings 不明文展示 |
| OCR 原文 + 截图进 iCloud 无用户认知 | 群聊隐私上云 | 首次启用 iCloud 说明；可选「敏感导入不同步」后续迭代 |
| 日志打印 OCR 全文 / API 响应 | 控制台、crash log 泄露群聊 | 日志 redact；仅 debug build 详细日志 |
| 客户端 Key 无用量限制 | Key 泄露后账单失控 | DeepSeek 控制台设 spend limit；App 内调用频率 cap |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| 确认页只显示解析结果，不显示 OCR/原图 | 无法判断误解析，信任低 | 三栏对照：原图 / OCR / 候选 |
| 每个候选单独一页确认 | 一条群消息 5 个作业 → 5 屏 | 单页批量 accept/edit/discard |
| 剪贴板自动弹 Paste 权限 | 「这 App 在监视我」 | 显式粘贴入口 |
| 空状态只写「暂无作业」 | 新用户不知下一步 | 引导：截图导入 / 粘贴 / 手动添加 / 配置 API Key |
| 完成作业无反馈 | 家长不确定是否记录 | 轻量 haptic + 完成时间戳；可选 undo |
| 科目自动推断错误无快捷修正 | 数学作业进「其他」 | 确认页科目 picker 默认可改；记住用户修正 |

## "Looks Done But Isn't" Checklist

- [ ] **截图导入：** 是否用真实微信群暗色/压缩截图测过？——不仅测印刷体
- [ ] **DeepSeek 解析：** 失败路径是否可手动录入？——不仅 happy path
- [ ] **用户确认：** 是否存在任何 auto-save 分支？——全局搜索 `save` without confirmation UI
- [ ] **重复任务：** 多次前后台切换是否 duplicate？——同 rule 同 date 仅一条
- [ ] **iCloud 同步：** 两设备离线各创建同科目是否 dedupe？——非单设备测试
- [ ] **本地通知：** `getPendingNotificationRequests` 是否 ≤64 且含今日任务？——非 Simulator-only
- [ ] **剪贴板：** 进入 App 是否不触发 Paste 弹窗？——仅用户点击粘贴才读
- [ ] **截止日期：** 「明天」在周日 22:00 导入是否正确？——带 timezone 测试
- [ ] **API Key：** 是否不出现在 UserDefaults / SwiftData / git？——静态扫描
- [ ] **Import 去重：** 同截图两次导入是否跳过第二次 API？——normalize hash 验证

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| CloudKit 重复任务/科目 | MEDIUM | 部署 dedupe 脚本：按 generationKey / normalizedName merge；保留 keeper 的 completedAt |
| 通知队列被清空 | LOW | 全量 rebuild：遍历未完成任务 + 活跃 recurring rules reschedule |
| OCR 中文大面积失败 | MEDIUM | 热修复 OCR 配置 + padding；短期引导粘贴文字导入 |
| Prompt 误提取接龙为作业 | LOW | 发版更新 Prompt + 反例；不迁移历史任务，用户手动删除 |
| iCloud 启用后数据翻倍 | HIGH | 停 sync → 本地 dedupe → 清 CloudKit zone（自用可接受 wipe）→ 重开 sync |
| API Key 泄露 | LOW | DeepSeek 轮换 Key；Keychain 更新；旧 Key revoke |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| OCR 丢失聊天结构 | Phase 2 | 黄金截图集：assigner 准确率人工标注 ≥80% 或确认页可快速修正 |
| DeepSeek JSON 不可靠 | Phase 2 | 故障注入测试：空响应、截断 JSON、错误类型 |
| 接龙/打卡误识别 | Phase 2–3 | 20 张真实群截图误报率统计 |
| 相对日期锚点错误 | Phase 2–3 | 时区 + 周日夜间边界单元测试 |
| SwiftData+CloudKit 重复 | Phase 1 | 双设备离线编辑后无 duplicate subject/task |
| 重复任务非幂等 | Phase 4 | 10 次前后台切换，同 rule 同 date 任务数 = 1 |
| 通知静默失效 | Phase 5 | 真机 7 天 recurring + due date 提醒；pending audit |
| 剪贴板隐私弹窗 | Phase 2 | 冷启动进首页无 Paste 系统弹窗 |
| OCR 中文配置 | Phase 2 | 黄金样本集 OCR 非空率 ≥95% |
| 导入 hash 不稳定 | Phase 2 | 同图两次导入 API 调用次数 = 1 |
| 跳过用户确认 | Phase 2–3 | 代码审查 + E2E 必经确认页 |
| API Key 存储 | Phase 2 | grep 无 UserDefaults key；Keychain 集成测试 |

## Sources

- [Apple Developer Forums: SwiftData data duplication (#772007)](https://developer.apple.com/forums/thread/772007) — CloudKit 无 unique constraint，需应用层 dedupe（HIGH）
- [Apple Developer Forums: SwiftData + CloudKit deduplication (#745329)](https://developer.apple.com/forums/thread/745329) — 离线并发创建 duplicate 合并策略（HIGH）
- [CloudKit Sync with SwiftData: Getting Your Data Models Right](https://www.codewithlionel.com/post/cloudkit-sync-with-swiftdata-getting-your-data-models-right) — 属性默认值、早期创建 Container（HIGH）
- [DeepSeek API: JSON Output](https://api-docs.deepseek.com/guides/json_mode) — json 关键词、max_tokens、空 content 风险（HIGH）
- [Apple UIPasteboard Documentation](https://developer.apple.com/documentation/uikit/uipasteboard) — metadata vs content 访问、detectedPatterns（HIGH）
- [Stack Overflow #79146582: VNRecognizeTextRequest Chinese failures](https://stackoverflow.com/questions/79146582/vnrecognizetextrequest-fails-but-can-select-text-in-preview-app) — padding、recognitionLanguages（MEDIUM）
- [Apple Developer Forums: Scheduled notifications disappearing (#670622)](https://developer.apple.com/forums/thread/670622) — removeAll 竞态（HIGH）
- [Todoist Engineering: Local Notification Scheduler](https://www.doist.dev/implementing-a-local-notification-scheduler-in-todoist-ios/) — 64 上限、TaskQueue 串行 reschedule（MEDIUM）
- [HomeworkPlan design.md — Risks / Trade-offs](openspec/changes/extract-mvp-scope/design.md) — 项目已识别风险：OCR 结构丢失、JSON  malformed、相对日期、iCloud duplicate recurring（HIGH）
- [HomeworkPlan PRD §十 风险与应对](docs/PRD.md) — 中文解析、确认后保存、录屏降级（MEDIUM）

---
*Pitfalls research for: 小学生作业管理 iOS App（HomeworkPlan）*
*Researched: 2026-06-22*
