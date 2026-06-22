# Feature Research

**Domain:** 家长端小学生作业管理 iOS App（本地优先、手动导入 + AI 解析）
**Researched:** 2026-06-22
**Confidence:** MEDIUM-HIGH（竞品功能来自 App Store 官方描述与 PRD/OpenSpec；MVP 边界已与 PROJECT.md 对齐）

## Feature Landscape

### Table Stakes (Users Expect These)

家长打开「作业管理」类 App 时的基本预期。缺少这些，产品会被认为「连清单都做不好」，即使用 AI 解析再强也难以留存。

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| 今日待办主视图 | 核心痛点是「今天还有什么没做」；PRD 与竞品（作业小达人、盯盯作业、MyStudyLife）均以当日清单为首页 | LOW | 按科目分组；未完成/已完成状态一目了然 |
| 任务完成/取消完成 | 清单类 App 最基本交互；家长需要勾选进度 | LOW | 记录完成时间，便于事后核对 |
| 手动创建任务 | 并非所有作业都来自群消息；补习班口头布置、家长自建习惯均需手动入口 | LOW | 科目 + 内容 + 截止日期表单 |
| 科目分组 | 中国小学家长心智模型是「语文/数学/英语…」；竞品普遍按科分类 | LOW | 默认科目 + 可自定义；影响列表可读性 |
| 编辑与删除任务 | 录入错误、老师临时变更很常见；不可编辑等于不可用 | LOW | 左滑删除或详情页编辑 |
| 截止日期与按日查看 | 作业有「今天/明天/周末」之分；家长需切换日期查历史或预习 | LOW-MEDIUM | 日历或日期选择器；MVP 至少支持选日浏览 |
| 本地提醒/通知 | 固定任务（练字）和截止任务是两大痛点；无提醒则重复任务价值减半 | MEDIUM | iOS 本地通知；需权限引导与完成/删除时取消 |
| 重复/固定任务 | 「每天练字」是 PRD 明确痛点；作业小达人、优学小助手、MyStudyLife 均有类似能力 | MEDIUM | 每天/工作日/每周；启动时自动生成当日实例 |
| 从外部导入作业内容 | 作业来源在微信群/钉钉，家长不会愿意逐条手打；竞品已教育市场「拍照/粘贴即可整理」 | MEDIUM | MVP：相册截图 + 粘贴文字；非 MVP：Share Extension、录屏 |
| 导入后结构化任务列表 | 长段群消息需拆成「练字一张」「背诵一篇」等可执行项；作业小达人以「AI 智能整理」为卖点 | MEDIUM-HIGH | OCR + LLM 解析；须处理非作业噪音 |
| 解析结果可编辑再保存 | 家长对误报容忍度极低；竞品隐含「整理后可改」；HomeworkPlan 明确要求确认流 | MEDIUM | 候选任务 → 确认/编辑/丢弃 → 持久化 |
| 数据本地持久化 | 作业是敏感家庭数据；断网、换机不能丢 | MEDIUM | SwiftData + iCloud 同步为 PRD 基线 |
| 空状态与首次引导 | 新用户不知从哪导入；无引导则首次体验失败 | LOW | 提示截图/粘贴/手动添加三种路径 |

### Differentiators (Competitive Advantage)

不是「没有就不能用」，但做对了能形成清晰定位，并与作业帮/班级小管家等错位竞争。

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| 群聊场景 AI 语义解析 | 从微信/钉钉杂乱聊天中过滤接龙、通知、闲聊，只提取作业；比纯 OCR 或手动分行省大量时间 | HIGH | DeepSeek 文本解析；Temperature=0 + schema 校验 |
| 截图 OCR + 文本解析流水线 | 家长习惯「截群聊图」；本地 Vision OCR 保护隐私、降成本，再送 LLM | MEDIUM-HIGH | 与 VLM 一步到位相比更可控、更便宜 |
| 用户确认门控（Confirm-before-save） | 建立信任：宁可多一步，也不把「明天交」误存成「今天交」 | LOW-MEDIUM | 差异化于「自动入库」；符合家长容错需求 |
| 相对日期归一化 | 群消息常说「明天交」「周五前」；需结合导入时间戳转为具体日期 | MEDIUM | 解析层能力，直接影响提醒准确性 |
| 内容哈希去重 | 家长可能重复粘贴同一条群消息；避免重复任务与重复 API 调用 | LOW | SHA256；提升体验与成本效率 |
| 重复规则 + 提醒一体化 | 不只日历上的重复事件，而是「规则 → 每日实例 → 本地通知」闭环 | MEDIUM | 优学/作业小达人有类似，但专注「作业」而非习惯/宠物 |
| 本地优先、无后端账号 | 自用 MVP 零运维；数据不出设备（除 LLM API）；隐私叙事清晰 | MEDIUM | 与需微信登录、家庭码的多端 App 形成差异 |
| 服务边界清晰（import/OCR/parse/task/recurring/reminder） | 为后续 ReplayKit 录屏自动化预留接口，不重写核心 | MEDIUM | 架构型差异，Phase 2+ 录屏接入时显现 |
| 布置人/来源溯源 | 群里有多个老师时知道「谁布置的」；便于核对 | LOW-MEDIUM | 解析字段 optional；列表可展示来源 |
| 剪贴板检测快捷粘贴 | 从微信复制后打开 App 即可粘贴，减少步骤 | LOW | 提升导入路径流畅度 |

**延后但仍属长期差异化（非 MVP）：**

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| ReplayKit 录屏自动采集 | 原 PRD 核心差异：刷群时自动捕获，无需手动截图 | HIGH | 权限摩擦、Extension 内存、微信屏蔽风险；已移出 MVP |
| Share Extension | 微信/钉钉内分享截图直达 App | MEDIUM | PRD Phase 2 |
| 桌面小组件 | 不打开 App 看今日剩余作业 | MEDIUM | PRD Phase 3 |
| 历史完成率/统计 | 长期习惯与复盘 | MEDIUM | PRD Phase 5 |

### Anti-Features (Commonly Requested, Often Problematic)

看似合理但会拖垮 MVP、模糊定位或引入不可控风险的能力——应明确不做。

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| 录屏自动采集（MVP） | 省去手动截图 | ReplayKit 每次需用户确认、状态栏红条、Extension 50MB 限制、微信可能屏蔽；技术风险最高 | MVP 用手动截图 + 粘贴；验证价值后再做 Phase 2 自动化 |
| 拍照批改 / 搜题 / 讲题 | 作业帮、小猿 AI 已极强 | 完全不同品类；需海量题库与教研；分散「清单管理」核心价值 | 需要辅导时用现有 App；HomeworkPlan 专注「要做什么」 |
| 积分/勋章/电子宠物/愿望清单 | 优学小助手、作业小达人的激励闭环 | 游戏化设计与运维成本高；自用 MVP 不需要；易变成「打卡 App」 | 重复任务 + 本地提醒解决「忘记」；未来若验证需求再加轻量激励 |
| 专注监督 / 摄像头盯写 | 盯盯作业卖点 | 隐私敏感、需订阅时长、与孩子设备强绑定；家长端自用场景不匹配 | 不在产品范围；用户可选盯盯作业等 |
| 作业提交给老师 / 班级打卡 | 班级小管家、班小二、钉钉 | 需教师端与班级体系；与「家长自建清单」定位冲突 | 打卡仍在原平台完成；本 App 只管家庭侧清单 |
| 多孩 / 全家协同 / 权限角色 | 二胎家庭、祖辈陪读 | 账号体系、邀请码、权限同步显著增加复杂度 | MVP 单孩单家长；iCloud 多设备同步即可 |
| 后端服务 / 钉钉 Webhook | 自动从钉钉机器人收消息 | 需部署、密钥、合规；违背本地优先 | 客户端手动导入；有管理员权限后再评估 |
| 解析结果自动入库 | 追求「零操作」 | 群聊误识别代价高（多作业、错日期）；一次误报即可失去信任 | 强制确认流；高置信度也不跳过 |
| VLM 主路径（Claude Vision / Qwen-VL） | OCR 失败时想一步到位 | MVP 成本与复杂度更高；Vision OCR 对中文聊天截图通常够用 | OCR + DeepSeek 文本；OCR 不足再 Phase 2 加 VLM fallback |
| 实时推送 / 远程通知服务器 | 希望「老师一发就提醒」 | 需后端与推送证书；与无后端架构冲突 | 本地通知 + 家长导入触发；录屏自动化后再考虑采集通知 |
| 历史大数据 / 学情分析 | 想看完成率趋势 | MVP 验证的是「导入→清单」而非「Analytics」 | Phase 5；先用「按日浏览已完成」满足简单回溯 |
| 附件/视频作业管理 | 英语打卡要传视频 | 存储、权限、与提交平台重复 | MVP 任务文本即可；附件可 Phase 2 |
| 多平台 Android / Web | 覆盖全家设备 | 资源分散；项目约束 iOS 17+ | 专注 iPhone 体验 |

## Feature Dependencies

```
[科目 Subject]
    └──requires──> [任务 Task Management]
                       ├──requires──> [本地存储 SwiftData]
                       └──requires──> [今日视图 / 按日浏览]

[相册截图导入]
    └──requires──> [Vision OCR]
                       └──requires──> [导入记录 ImportRecord]
                                          └──requires──> [DeepSeek 解析]
                                                             └──requires──> [Keychain API Key]
                                                                                └──requires──> [用户确认]
                                                                                                   └──requires──> [任务 Task Management]

[粘贴文字导入]
    └──requires──> [导入记录 ImportRecord] ──> (同上解析链)

[内容哈希去重]
    └──enhances──> [导入记录 ImportRecord]
    └──enhances──> [DeepSeek 解析] (避免重复调用)

[重复规则 RecurringRule]
    └──requires──> [任务 Task Management]
    └──requires──> [App 生命周期触发器] (启动/前台)
    └──requires──> [按规则+日期去重生成]

[本地提醒]
    └──requires──> [通知权限]
    └──requires──> [任务 Task Management] (due date / 生成实例)
    └──enhances──> [重复规则 RecurringRule]
    └──conflicts──> [无截止日的纯手动任务] (可选提醒，非必须)

[剪贴板检测]
    └──enhances──> [粘贴文字导入]

[iCloud 同步]
    └──requires──> [SwiftData + CloudKit]
    └──enhances──> [任务 / 规则 / 科目] (多设备)

[ReplayKit 录屏] ──conflicts──> [MVP 范围]
    └──(future) requires──> [监控规则 MonitorRule]
    └──(future) requires──> [Broadcast Upload Extension]
    └──(future) enhances──> [导入记录] (自动来源)

[Share Extension] ──conflicts──> [MVP 范围]
    └──(future) enhances──> [相册截图导入]
```

### Dependency Notes

- **OCR 依赖导入记录：** 截图导入需先持久化来源与时间，OCR 文本附在 import record 上，便于重试解析与溯源。
- **解析依赖确认再写任务：** 解析输出是「候选」不是「任务」；确认流是信任机制，不可为求快而绕过。
- **重复规则依赖任务模型：** 生成的实例是普通 HomeworkTask（来源= recurring），与手动/导入任务共用完成、提醒、删除逻辑。
- **提醒依赖任务与权限：** 无通知权限时 App 仍可用，但须明确降级说明；完成任务必须取消 pending notification。
- **去重增强解析链：** 应在创建 import record 前算 hash，避免 duplicate 进入 LLM。
- **录屏与 MVP 冲突：** 录屏自动化依赖监控规则与 Extension，与「手动导入验证价值链」阶段目标不一致，分阶段实施。

## MVP Definition

### Launch With (v1)

与 OpenSpec `extract-mvp-scope` 及 PROJECT.md Active 需求对齐——验证「手动提供内容 → 确认 → 今日清单 → 提醒」闭环。

- [ ] **今日待办主界面（按科目分组）** — 核心价值「一眼看清今天还有什么没做」
- [ ] **手动创建 / 编辑 / 删除 / 完成任务** — 无 AI 也能用，兜底所有来源
- [ ] **按日期浏览任务** — 查历史、看明天
- [ ] **相册截图导入 + Vision OCR** — 家长最高频路径之一
- [ ] **粘贴文字导入（含剪贴板检测）** — 从微信/钉钉复制后直接导入
- [ ] **DeepSeek 解析 → 候选任务 → 用户确认** — 差异化核心；含非作业过滤、相对日期、schema 校验
- [ ] **导入内容哈希去重** — 避免重复任务与 API 浪费
- [ ] **重复规则（每天/工作日/每周）+ 启动/前台自动生成** — 解决「每天练字忘记」
- [ ] **本地通知（截止任务 + 重复任务）+ 权限引导** — 固定任务与截止日期闭环
- [ ] **默认科目 + 可自定义** — 降低首次使用门槛
- [ ] **SwiftData 本地存储 + iCloud 同步** — 换机不丢
- [ ] **Keychain 存储 DeepSeek API Key** — 安全直连 LLM

### Add After Validation (v1.x)

核心闭环跑通且自用稳定后，按 PRD 路线图逐步加入。

- [ ] **Share Extension** — 减少「保存相册再打开 App」步骤；验证导入频率后再做
- [ ] **ReplayKit 录屏 + 监控规则** — 验证手动导入价值后，再承担自动化复杂度
- [ ] **VLM fallback（Qwen-VL 等）** — OCR 质量不足时的备选解析路径
- [ ] **附件（图片）关联任务** — 保留原始作业截图便于核对
- [ ] **离线解析队列** — 无网络时暂存 import，联网后补解析
- [ ] **桌面小组件** — 高频查看今日剩余时再投入
- [ ] **空状态优化 / 首次向导** — 根据自用反馈细化 onboarding

### Future Consideration (v2+)

产品-市场契合后再考虑，避免 MVP 膨胀。

- [ ] **多孩 / 家庭协同** — 有真实多孩需求与账号意愿时
- [ ] **历史统计与完成率** — 需要长期数据积累
- [ ] **钉钉机器人 / 轻量后端** — 有学校管理员权限与自动化诉求时
- [ ] **轻量激励（积分）** — 若发现仅靠提醒不足以养成习惯
- [ ] **Android / 跨平台** — iOS 验证成功后再议

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| 今日待办 + 科目分组 | HIGH | LOW | P1 |
| 手动 CRUD 任务 | HIGH | LOW | P1 |
| 完成任务 + 完成时间 | HIGH | LOW | P1 |
| 粘贴文字导入 | HIGH | LOW | P1 |
| 截图导入 + OCR | HIGH | MEDIUM | P1 |
| DeepSeek 解析 + 确认流 | HIGH | HIGH | P1 |
| 重复规则 + 自动生成 | HIGH | MEDIUM | P1 |
| 本地提醒 | HIGH | MEDIUM | P1 |
| SwiftData + iCloud | HIGH | MEDIUM | P1 |
| 按日浏览 | MEDIUM | LOW | P1 |
| 内容去重 | MEDIUM | LOW | P1 |
| Keychain API Key | MEDIUM | LOW | P1 |
| 剪贴板检测 | MEDIUM | LOW | P2 |
| 布置人/来源展示 | MEDIUM | LOW | P2 |
| Share Extension | MEDIUM | MEDIUM | P2 |
| 附件存图 | MEDIUM | MEDIUM | P2 |
| 录屏自动采集 | HIGH (长期) | HIGH | P3 |
| 小组件 | MEDIUM | MEDIUM | P3 |
| 历史统计 | LOW (早期) | MEDIUM | P3 |
| 积分/宠物/协同 | LOW (MVP) | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

市场可分为四类：**作业清单管理**（直接竞品）、**习惯/激励管理**（部分重叠）、**班级/家校平台**（作业来源端）、**批改辅导**（不同品类）。HomeworkPlan 应对标第一类，借 AI 导入强化，刻意避开第三、四类。

| Feature | 作业小达人 | 盯盯作业 | 优学小助手 | MyStudyLife | HomeworkPlan MVP |
|---------|-----------|---------|-----------|-------------|------------------|
| 定位 | 作业管理 + 打卡 + 题库 + 积分 | 作业规划 + 过程监督 | 计划/习惯/宠物/积分 | 学生课表 + 作业Planner | **家长自建清单，本地优先** |
| 今日/日历视图 | ✅ 作业日历 | ✅ 任务顺序 | ✅ 日/周/月计划 | ✅ 作业 + 课表 | ✅ 今日主屏 + 按日 |
| 手动添加 | ✅ | ✅ | ✅ | ✅ | ✅ |
| AI 整理作业 | ✅ 粘贴/照片拆分 | ✅ 拍照整理清单 | ✅ AI 生成计划 | ❌ | ✅ OCR+粘贴+DeepSeek |
| 重复/批量复制 | ✅ 模板复制 3–7 天 | — | ✅ 计划/习惯复用 | ✅ Repeated tasks | ✅ 重复规则 |
| 提醒 | ✅ | ✅ 专注提醒 | ✅ 番茄/计划 | ✅ | ✅ 本地通知 |
| 多孩/家庭协同 | ✅ 多孩+邀请码 | — | ✅ 家长/孩子模式 | ❌ 偏学生端 | ❌ MVP 不做 |
| 积分/游戏化 | ✅ 核心卖点 | — | ✅ 宠物/愿望 | ❌ | ❌ 刻意不做 |
| 拍照解题/批改 | ✅ | — | — | ❌ | ❌ 不同品类 |
| 作业提交给老师 | ✅ 拍照提交 | — | — | ❌ | ❌ 在班级 App 完成 |
| 专注/盯写 | — | ✅ 核心卖点 | ✅ 番茄钟 | ✅ Pomodoro | ❌ |
| 录屏/自动采群消息 | ❌ | ❌ | ❌ | ❌ | ❌ MVP；**Phase 2 潜在差异** |
| 本地优先无账号 | ❌ 微信登录 | ❌ 订阅 | ❌ 账号同步 | ⚠️ 可选账号 | ✅ iCloud 即可 |
| 确认后再保存 | ⚠️ 未强调 | ⚠️ 未强调 | ✅ 家长审核 | — | ✅ **明确门控** |

**品类边界说明：**
- **作业帮 / 小猿 AI：** 解决「做得对不对、不会怎么做」——表桩是搜题、批改、讲解，不是「今天有哪些作业」。
- **班级小管家 / 班小二 / 钉钉：** 解决「老师布置 → 家长收到 → 提交打卡」——依赖班级体系，Standalone 家长 App 无法替代，但可与之并存（家长仍须自己整理分散来源）。
- **HomeworkPlan 错位竞争：** 不做批改、不做班级提交、不做游戏化；专注 **分散群消息 → 结构化清单 → 重复任务提醒**，并以 **确认式 AI 解析 + 本地隐私** 建立信任。

## Sources

- [HomeworkPlan PROJECT.md](../PROJECT.md) — MVP 范围、Active/Out of Scope 需求
- [OpenSpec extract-mvp-scope](../../openspec/changes/extract-mvp-scope/proposal.md) — 能力边界与 spec
- [docs/PRD.md](../../docs/PRD.md) — 痛点、功能设计、分阶段路线图
- [作业小达人 — App Store CN](https://apps.apple.com/cn/app/%E4%BD%9C%E4%B8%9A%E5%B0%8F%E8%BE%BE%E4%BA%BA-%E5%B0%8F%E5%AD%A6%E7%94%9F%E4%BD%9C%E4%B8%9A%E6%89%93%E5%8D%A1%E7%A7%AF%E5%88%86%E7%A5%9E%E5%99%A8/id6751796522) — AI 解析、重复任务、多孩、积分（HIGH confidence）
- [盯盯作业 — App Store CN](https://apps.apple.com/cn/app/%E7%9B%AF%E7%9B%AF%E4%BD%9C%E4%B8%9A-%E4%B8%93%E4%B8%9A%E7%9B%9D%E7%9D%A3%E5%AD%A6%E4%B9%A0ai%E8%80%81%E5%B8%88/id6760898561) — 拍照整理、学科排序、专注监督（HIGH confidence）
- [优学小助手 — App Store CN](https://apps.apple.com/cn/app/%E4%BC%98%E5%AD%A6%E5%B0%8F%E5%8A%A9%E6%89%8B/id6762972276) — 计划/习惯/宠物/积分/家长审核（HIGH confidence）
- [MyStudyLife — App Store](https://apps.apple.com/gb/app/mystudylife-study-planner/id910639339) — 重复任务、提醒、课表作业 Planner（HIGH confidence）
- [Homework Tracker — App Store US](https://apps.apple.com/us/app/homework-tracker-app/id6762500453) — 家庭共享日历、多孩、提醒（MEDIUM confidence）
- [作业帮 / 小猿 AI 对比报道](https://www.163.com/dy/article/KTQ0NGCK0552PLK4.html) — 批改辅导品类边界（MEDIUM confidence）
- [班级小管家官网](https://banjixiaoguanjia.com/) — 家校平台功能范围（MEDIUM confidence）

---
*Feature research for: 小学生作业管理 iOS App（HomeworkPlan）*
*Researched: 2026-06-22*
