# Architecture Research — v2.0 AI Native

**Project:** HomeworkPlan v2.0  
**Researched:** 2026-06-22

## Layer Model

```
┌─────────────────────────────────────────────────┐
│  UI Layer (SwiftUI)                              │
│  HomeQueryView │ ActionConsoleView │ Settings*   │
└────────────┬────────────────────┬───────────────┘
             │                    │
┌────────────▼────────────────────▼───────────────┐
│  Agent Layer (NEW)                                 │
│  AgentOrchestrator │ ToolRegistry │ ToolExecutor   │
│  ConfirmationGate │ AgentSessionState             │
└────────────┬──────────────────────────────────────┘
             │
┌────────────▼──────────────────────────────────────┐
│  Service Layer (EXISTING — wrap, don't rewrite)    │
│  ImportService │ ParseService │ OCRService         │
│  RecurringTaskGenerator │ ReminderService          │
└────────────┬──────────────────────────────────────┘
             │
┌────────────▼──────────────────────────────────────┐
│  Repository Layer (EXISTING)                       │
│  Task │ Subject │ RecurringRule │ Import           │
└────────────┬──────────────────────────────────────┘
             │
┌────────────▼──────────────────────────────────────┐
│  SwiftData + CloudKit (EXISTING)                   │
└───────────────────────────────────────────────────┘
```

## New Components

### ToolRegistry

Static registry of `AgentTool` definitions:
- `import_from_image`, `import_from_text`
- `create_task`, `update_task`, `delete_task`, `toggle_task_complete`, `list_tasks`
- `create_subject`, `update_subject`, `delete_subject`, `list_subjects`
- `create_recurring_rule`, `update_recurring_rule`, `delete_recurring_rule`, `list_recurring_rules`

Each tool: `name`, `description`, `parameters JSON Schema`, `execute(params) async throws -> ToolResult`

### AgentOrchestrator

1. Build messages: system prompt (homework assistant, must use tools, must not invent tasks) + user input + optional OCR text from attachment
2. Call DeepSeek with tools
3. If `tool_calls`: execute via ToolExecutor, append results, loop (max 5)
4. If write tool result needs confirm: return `PendingConfirmation` without persisting
5. Else: return assistant message

### ConfirmationGate

Reuses v1.0 `TaskCandidate` / review pattern generalized to `AgentProposal`:
- Import proposals → existing `TaskCandidateReviewView` data
- Subject/recurring proposals → simple confirm sheet with diff preview

### ActionConsoleViewModel

@Observable state: `inputText`, `attachments`, `turns[]`, `pendingConfirmation`, `isRecording`

## Data Flow — Add Homework via Voice

```
User holds mic → SFSpeechRecognizer → transcript
  → AgentOrchestrator.run(transcript)
  → LLM calls create_task({ subject, content, dueDate })
  → ConfirmationGate presents proposal
  → User confirms → TaskRepository.create → ReminderService schedule
  → HomeQueryView refreshes via @Query / reload
```

## Data Flow — Paste Screenshot

```
User pastes image in Action Console
  → OCRService.recognize (local)
  → AgentOrchestrator.run("导入作业", ocrText, imageRef)
  → LLM calls import_from_text or import_from_image
  → ImportService pipeline → TaskCandidates
  → Confirm → persist
```

## Build Order (MVP Phases)

| Order | Component | Depends on |
|-------|-----------|------------|
| 1 | ToolRegistry + ToolExecutor wrapping repos | AppDependencies |
| 2 | AgentOrchestrator + DeepSeek tools API | ToolRegistry, ParseService patterns |
| 3 | ActionConsoleView (text) + confirmation UI | Orchestrator |
| 4 | Speech + image attach | Action Console |
| 5 | HomeQueryView (merge Today+All) | TaskRepository queries |
| 6 | NL subject/recurring tools + Settings slim | ToolRegistry complete |

## Modified vs New

| Modified | New |
|----------|-----|
| MainTabView (2-tab shell) | AgentOrchestrator, ToolRegistry, ToolExecutor |
| DeepSeek client (add tools param) | ActionConsoleView, ActionConsoleViewModel |
| ParseService prompts (optional shared system context) | HomeQueryView, HomeQueryViewModel |
| SettingsView (slim links) | SpeechInputService, AgentProposal models |

## Deprecated (Remove in Phase 4)

- `TodayView`, `AllTasksView` as separate tabs (logic migrates to HomeQueryView)
- Settings navigation to SubjectManagementView / RecurringRulesListView as primary paths (keep as debug/fallback optional)
