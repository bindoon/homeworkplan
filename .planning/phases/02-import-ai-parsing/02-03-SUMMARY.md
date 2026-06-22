---
phase: 02-import-ai-parsing
plan: 03
subsystem: import-ui
tags: [swiftui, photospicker, review-flow]
dependency_graph:
  requires: [02-02]
  provides: [ImportSourceSheet, TaskCandidateReviewView, APIKeySettingsView]
  affects: [TodayView, SettingsView]
tech_stack:
  added: [PhotosUI]
  patterns: [confirmation gate before TaskRepository.create]
key_files:
  created:
    - HomeworkPlan/Views/Import/ImportSourceSheet.swift
    - HomeworkPlan/Views/Import/ScreenshotImportView.swift
    - HomeworkPlan/Views/Import/PasteImportView.swift
    - HomeworkPlan/Views/Import/TaskCandidateReviewView.swift
    - HomeworkPlan/Views/Import/ClipboardHintBanner.swift
    - HomeworkPlan/Views/Settings/APIKeySettingsView.swift
    - HomeworkPlan/ViewModels/ImportReviewViewModel.swift
  modified:
    - HomeworkPlan/Views/Tabs/TodayView.swift
    - HomeworkPlan/Views/Tabs/SettingsView.swift
    - HomeworkPlan/project.yml
decisions:
  - "Clipboard hasStrings hint only; content read when user taps 导入"
  - "Review toolbar: 全部确认 / 全部丢弃 per CONTEXT"
metrics:
  duration: 25min
  completed: 2026-06-22
---

# Phase 2 Plan 03: Import & Review UI Summary

**One-liner:** PhotosPicker screenshot import, paste flow, clipboard hint banner, candidate review with confirm/edit/discard, and Keychain API Key settings.

## Tasks Completed

| Task | Commit | Description |
|------|--------|-------------|
| 1 | pending | Import source views + PhotosPicker |
| 2 | pending | TaskCandidateReviewView + ViewModel |
| 3 | pending | Today/Settings integration + clipboard |

## Deviations from Plan

None - plan executed as written.

## Self-Check: PASSED

- TaskCandidateReviewView.swift: FOUND
- APIKeySettingsView.swift: FOUND
- today-import-button in TodayView: FOUND
