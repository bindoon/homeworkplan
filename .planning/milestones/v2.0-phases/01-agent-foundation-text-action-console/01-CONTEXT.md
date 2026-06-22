# Phase 01 Context: Agent Foundation & Text Action Console

## Goal
Add LLM-driven agent layer with tool calling and confirmation gate for mutating operations.

## Stack
- Swift iOS 17+, SwiftUI, SwiftData
- DashScope OpenAI-compatible API (`AppSecrets.dashscopeBaseURL`, `AppSecrets.llmModel`)
- Existing: TaskRepository, SubjectRepository, RecurringRuleRepository, ImportService

## Key Constraint
Mutating tool calls return `AgentProposal` — nothing persists until user taps 确认 in Action Tab.

## Deliverables
- `Services/Agent/*` — models, registry, executor, LLM, orchestrator
- `ActionConsoleView` — 4th tab「操作」
- Unit tests for ToolRegistry and ToolExecutor
