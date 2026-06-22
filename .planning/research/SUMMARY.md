# Project Research Summary — v2.0 AI Native

**Project:** HomeworkPlan v2.0 AI Native  
**Domain:** iOS 家长作业管理 App — Agent + Tool-calling 交互改造  
**Researched:** 2026-06-22  
**Confidence:** HIGH

## Executive Summary

v2.0 在 v1.0 已验证的服务层之上新增 **Agent 层**，用 Tool-calling 将 ImportService、TaskRepository、SubjectRepository、RecurringRuleRepository 暴露为 LLM 可调用工具。UI 从三 Tab 表单导航简化为 **Home（查询 + 折叠展示）** 与 **Action（单一输入框 + 贴图/语音）**。技术栈不引入外部 Agent 框架：DeepSeek function calling + 自研 `AgentOrchestrator` + `SFSpeechRecognizer`，保留确认门控与家长信任模型。

## Key Findings

### Stack Additions

- DeepSeek Chat Completions `tools` 参数 + JSON Schema 工具定义
- `SFSpeechRecognizer` 语音转文字（zh-CN）
- Action Console 内 `PhotosPicker` + 剪贴板贴图
- Info.plist 麦克风/语音识别权限

### Table Stakes

- 单一操作入口 + 工具化写入 + 确认后再持久化
- 文字 NL 添加作业
- Agent 明确说明即将执行的操作

### Architecture

Agent Layer 介于 UI 与现有 Service Layer 之间；Tool 为薄适配器，不重复业务逻辑；Agent 会话状态不入 SwiftData。

### Watch Out For

- 跳过确认门控（P1）
- Agent 循环失控（P4）
- 过早移除表单 fallback（P3）
- Home 合并后一次加载全部历史（P6）

## Implications for Roadmap

| Phase | Focus | Risk Addressed |
|-------|-------|----------------|
| 1 | Agent + Tools + Text Action Console | P1, P2, P4, P7, P9 |
| 2 | Image paste + Voice input | P5, P8 |
| 3 | Home merge + collapsible | P6, P10 |
| 4 | NL admin + Settings slim | P3 |

---
*Synthesized: 2026-06-22 for milestone v2.0*
