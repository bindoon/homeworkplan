---
phase: 04-nl-admin-settings-slim
plan: 01
subsystem: agent
tags: [swiftui, agent-prompt, settings, tool-executor, nl-admin]

requires:
  - phase: 01-agent-foundation-text-action-console
    provides: ToolExecutor subject/recurring tools with confirmation gate
  - phase: 03-unified-home-navigation
    provides: Action Console tab in three-tab shell
provides:
  - Agent prompt with Chinese NL examples for subject and recurring admin
  - Slim SettingsView without form CRUD entry points
  - Action Console empty-state NL hints
  - ToolExecutorTests for create_subject and create_recurring_rule confirm flows
affects: []

tech-stack:
  added: []
  patterns:
    - "Subject/recurring admin via Action Console NL only"
    - "Settings limited to reminders, API key, about"

key-files:
  created:
    - .planning/phases/04-nl-admin-settings-slim/04-01-PLAN.md
  modified:
    - HomeworkPlan/Services/Agent/AgentSystemPrompt.swift
    - HomeworkPlan/Views/Tabs/SettingsView.swift
    - HomeworkPlan/Views/Agent/ActionConsoleView.swift
    - HomeworkPlanTests/HomeworkPlanTests/ToolExecutorTests.swift

key-decisions:
  - "Keep SubjectManagementView/RecurringRulesListView files for debug but remove Settings navigation"
  - "Document NL admin examples directly in AgentSystemPrompt rather than separate doc"

requirements-completed: [NLAD-01, NLAD-02, NAV-02]

duration: 15min
completed: 2026-06-22
---

# Phase 4 Plan 01: NL Admin & Settings Slim Summary

**Agent prompt documents Chinese NL subject/recurring admin; Settings slimmed to reminders/API/about; ToolExecutor confirm flows tested**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-22T11:21:00Z
- **Completed:** 2026-06-22T11:36:02Z
- **Tasks:** 7
- **Files modified:** 4

## Accomplishments

- AgentSystemPrompt lists all subject/recurring tools with Chinese phrase→tool mapping examples
- SettingsView no longer links to SubjectManagementView or RecurringRulesListView (NAV-02)
- ActionConsoleView empty state suggests 「加一门科学」「每天练字」 alongside task import examples
- Four new ToolExecutorTests verify proposal gate and confirm persistence for subjects and recurring rules
- Full unit suite: 83 tests, 0 failures (iPhone 17 simulator)

## Task Commits

1. **Task 1: AgentSystemPrompt NL examples** - `c9200e3` (feat)
2. **Task 2-3: Settings slim + Action Console hints** - `e3a88f7` (feat)
3. **Task 5: ToolExecutorTests** - `2bf70de` (test)

## Files Created/Modified

- `HomeworkPlan/Services/Agent/AgentSystemPrompt.swift` - NL admin capability section with Chinese examples
- `HomeworkPlan/Views/Tabs/SettingsView.swift` - Removed subject/recurring NavigationLinks
- `HomeworkPlan/Views/Agent/ActionConsoleView.swift` - Empty-state NL hint examples
- `HomeworkPlanTests/HomeworkPlanTests/ToolExecutorTests.swift` - Subject/recurring proposal+confirm tests

## Decisions Made

- Retained SubjectManagementView/RecurringRulesListView source files (v1.0 views) without Settings entry — aligns with deferred cleanup item
- Enhanced system prompt in-place; no new AgentTool definitions needed (Phase 1 tools sufficient)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- xcodebuild default destination `iPhone 16` unavailable; used `iPhone 17, OS=26.3.1` instead — all tests passed

## Next Phase Readiness

- v2.0 AI Native milestone complete (all 4 phases shipped)
- Runtime NL admin UAT on device recommended for end-to-end agent→confirm flow

---
*Phase: 04-nl-admin-settings-slim*
*Completed: 2026-06-22*

## Self-Check: PASSED

- FOUND: HomeworkPlan/Services/Agent/AgentSystemPrompt.swift
- FOUND: HomeworkPlan/Views/Tabs/SettingsView.swift
- FOUND: HomeworkPlan/Views/Agent/ActionConsoleView.swift
- FOUND: HomeworkPlanTests/HomeworkPlanTests/ToolExecutorTests.swift
- FOUND: c9200e3
- FOUND: e3a88f7
- FOUND: 2bf70de
