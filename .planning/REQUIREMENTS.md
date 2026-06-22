# Requirements: HomeworkPlan v2.0 AI Native

**Defined:** 2026-06-22  
**Milestone:** v2.0 AI Native  
**Core Value:** 手动提供作业内容后，App 能可靠地将信息转化为经用户确认的每日作业清单

## Milestone Requirements

### Agent & Tools (AGNT)

- [ ] **AGNT-01**: AgentOrchestrator 接受用户文字输入并调用 DeepSeek function calling
- [ ] **AGNT-02**: ToolRegistry 注册全部 v1.0 写操作工具（import、task、subject、recurring）
- [ ] **AGNT-03**: Tool 执行通过现有 Service/Repository，不重复业务逻辑
- [ ] **AGNT-04**: Agent 循环最多 5 轮 tool call，防止失控
- [ ] **AGNT-05**: 所有 mutating tool 返回 Proposal，用户确认后才持久化

### Action Console (ACTN)

- [ ] **ACTN-01**: 第二 Tab 提供单一文字输入框 + 发送按钮
- [ ] **ACTN-02**: 展示 agent 回复与待确认卡片
- [ ] **ACTN-03**: 用户可在 Action Console 内确认/拒绝 tool 提案
- [x] **ACTN-04**: 支持在输入框粘贴截图触发 import 工具
- [x] **ACTN-05**: 支持按住录音按钮，语音转文字后送入 agent

### Home Query (HOME)

- [ ] **HOME-01**: 第一 Tab 合并原「今日」与「全部」为统一查询首页
- [ ] **HOME-02**: 默认展示选中日期的任务，按科目分组
- [ ] **HOME-03**: 支持日期选择器切换日期
- [ ] **HOME-04**: 历史任务按日期分区展示，各区可折叠/展开
- [ ] **HOME-05**: 首页可直接切换任务完成状态，无需表单

### Navigation (NAV)

- [ ] **NAV-01**: 主界面改为 Home + Action 双 Tab，Settings 保留第三 Tab 或 gear 入口
- [ ] **NAV-02**: Settings 精简为提醒、API Key、关于；科目/重复任务表单入口移除

### Natural Language Admin (NLAD)

- [ ] **NLAD-01**: 用户可通过 Action Console 自然语言创建/修改/删除科目
- [ ] **NLAD-02**: 用户可通过 Action Console 自然语言创建/修改/删除重复规则
- [ ] **NLAD-03**: 用户可通过文字或语音描述添加手动作业

### Tool Implementations (TOOL)

- [ ] **TOOL-01**: `import_from_image` / `import_from_text` 包装 ImportService
- [ ] **TOOL-02**: `create_task` / `update_task` / `delete_task` / `toggle_task_complete` / `list_tasks` 包装 TaskRepository
- [ ] **TOOL-03**: `create_subject` / `update_subject` / `delete_subject` / `list_subjects` 包装 SubjectRepository
- [ ] **TOOL-04**: `create_recurring_rule` / `update_recurring_rule` / `delete_recurring_rule` / `list_recurring_rules` 包装 RecurringRuleRepository

## Future Requirements (Deferred)

### Extensions (v2.1+)

- **EXT-01**: Share Extension 系统分享导入
- **EXT-02**: ReplayKit 录屏自动采集
- **EXT-03**: WidgetKit 今日任务小组件

## Out of Scope

| Feature | Reason |
|---------|--------|
| 后端 Agent 服务 | 本地优先约束 |
| 外部 Agent 框架 (LangChain 等) | 避免 SPM 依赖 |
| 去掉确认门控 | 家长场景信任要求 |
| 全自动 agent 写入 | 误报代价高 |
| on-device LLM | 中文解析质量不足 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AGNT-01 | Phase 1 | Pending |
| AGNT-02 | Phase 1 | Pending |
| AGNT-03 | Phase 1 | Pending |
| AGNT-04 | Phase 1 | Pending |
| AGNT-05 | Phase 1 | Pending |
| TOOL-01 | Phase 1 | Pending |
| TOOL-02 | Phase 1 | Pending |
| TOOL-03 | Phase 1 | Pending |
| TOOL-04 | Phase 1 | Pending |
| ACTN-01 | Phase 1 | Pending |
| ACTN-02 | Phase 1 | Pending |
| ACTN-03 | Phase 1 | Pending |
| NLAD-03 | Phase 1 | Pending |
| ACTN-04 | Phase 2 | Complete |
| ACTN-05 | Phase 2 | Complete |
| HOME-01 | Phase 3 | Pending |
| HOME-02 | Phase 3 | Pending |
| HOME-03 | Phase 3 | Pending |
| HOME-04 | Phase 3 | Pending |
| HOME-05 | Phase 3 | Pending |
| NAV-01 | Phase 3 | Pending |
| NLAD-01 | Phase 4 | Pending |
| NLAD-02 | Phase 4 | Pending |
| NAV-02 | Phase 4 | Pending |

**Coverage:**
- Milestone requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-22*
*Last updated: 2026-06-22 after v2.0 AI Native roadmap*
