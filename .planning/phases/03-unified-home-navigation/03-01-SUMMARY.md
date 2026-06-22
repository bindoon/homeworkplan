---
phase: 03-unified-home-navigation
plan: 01
subsystem: ui
tags: [swiftui, home, navigation, disclosure-group, viewmodel]

requires:
  - phase: 01-agent-foundation-text-action-console
    provides: ActionConsoleView tab shell
  - phase: 02-multimodal-action-console
    provides: multimodal Action tab
provides:
  - HomeQueryView unified home tab
  - HomeQueryViewModel with subject groups and history sections
  - Three-tab navigation Home + Action + Settings
affects:
  - phase-04-nl-admin-settings-slim

tech-stack:
  added: []
  patterns:
    - "@Observable HomeQueryViewModel with expand/collapse Sets"
    - "DisclosureGroup for subject and date sections"
    - "Selected day incomplete tasks + history all tasks"

key-files:
  created:
    - HomeworkPlan/ViewModels/HomeQueryViewModel.swift
    - HomeworkPlan/Views/Tabs/HomeQueryView.swift
    - HomeworkPlanTests/HomeworkPlanTests/HomeQueryViewModelTests.swift
  modified:
    - HomeworkPlan/Views/Tabs/MainTabView.swift
    - HomeworkPlan/Views/Tabs/TodayView.swift
    - HomeworkPlan/Views/Tabs/AllTasksView.swift
    - HomeworkPlanTests/HomeworkPlanUITests/TodayFlowUITests.swift
    - HomeworkPlan/HomeworkPlan.xcodeproj/project.pbxproj

key-decisions:
  - "Keep TodayView/AllTasksView files with deprecation comment rather than delete"
  - "History sections default expanded only for today; subject groups default expanded"
  - "Selected day shows incomplete tasks only; history shows complete and incomplete"

requirements-completed: [HOME-01, HOME-02, HOME-03, HOME-04, HOME-05, NAV-01]

duration: 25min
completed: 2026-06-22
---

# Phase 3 Plan 01: Unified Home & Navigation Summary

**Single Home tab merges Today + All with subject DisclosureGroups, collapsible history by date, and three-tab shell (Home + Action + Settings)**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-22T11:28:00Z
- **Completed:** 2026-06-22T11:53:00Z
- **Tasks:** 9
- **Files modified:** 8

## Accomplishments

- HomeQueryViewModel unifies selected-date subject grouping and history date sections
- HomeQueryView replaces separate Today/All tabs with date picker, clipboard banner, import/add toolbar
- MainTabView reduced to 首页 + 操作 + 设置
- Seven unit tests cover collapse defaults, date filtering, and section sorting

## Task Commits

1. **Task 1: HomeQueryViewModel** - `268b769` (feat)
2. **Task 2: HomeQueryView** - `a455db5` (feat)
3. **Task 3: MainTabView navigation** - `5d519fb` (feat)
4. **Task 6: Unit tests** - `96a4d4a` (test)

## Files Created/Modified

- `HomeworkPlan/ViewModels/HomeQueryViewModel.swift` - Unified home data and collapse state
- `HomeworkPlan/Views/Tabs/HomeQueryView.swift` - Merged home UI
- `HomeworkPlan/Views/Tabs/MainTabView.swift` - Three-tab shell
- `HomeworkPlanTests/HomeworkPlanTests/HomeQueryViewModelTests.swift` - ViewModel tests
- `HomeworkPlanTests/HomeworkPlanUITests/TodayFlowUITests.swift` - Updated for 首页 tab

## Decisions Made

- Deprecated TodayView/AllTasksView in place instead of deleting (reference for Phase 4 cleanup)
- Empty state directs users to 操作 Tab for natural-language entry while keeping 添加作业 toolbar
- History uses same date sort as AllTasksViewModel (today first, future ascending, past descending)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- xcodebuild initially failed on missing iPhone 16 simulator; retried on iPhone 17 (OS 26.3.1) — all 7 tests passed

## Next Phase Readiness

- Home + Action + Settings navigation complete; ready for Phase 4 NL admin and Settings slim
- TodayView/AllTasksView can be removed in a future cleanup once no longer needed for reference

## Self-Check: PASSED

- FOUND: HomeworkPlan/ViewModels/HomeQueryViewModel.swift
- FOUND: HomeworkPlan/Views/Tabs/HomeQueryView.swift
- FOUND: HomeworkPlanTests/HomeworkPlanTests/HomeQueryViewModelTests.swift
- FOUND: 268b769
- FOUND: a455db5
- FOUND: 5d519fb
- FOUND: 96a4d4a

---
*Phase: 03-unified-home-navigation*
*Completed: 2026-06-22*
