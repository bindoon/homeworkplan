---
phase: 02-import-ai-parsing
plan: 01
subsystem: import
tags: [swiftdata, keychain, crypto]
dependency_graph:
  requires: [phase-01]
  provides: [ImportRecord, KeychainService, ContentHashService, ImportRepository]
  affects: [HomeworkTask, AppDependencies]
tech_stack:
  added: [CryptoKit, Security framework]
  patterns: [SwiftData @Model, Keychain generic password]
key_files:
  created:
    - HomeworkPlan/Models/ImportRecord.swift
    - HomeworkPlan/Models/TaskCandidate.swift
    - HomeworkPlan/Models/ImportSourceType.swift
    - HomeworkPlan/Services/Security/KeychainService.swift
    - HomeworkPlan/Services/Import/ContentHashService.swift
    - HomeworkPlan/Repositories/ImportRepository.swift
    - HomeworkPlanTests/HomeworkPlanTests/ContentHashServiceTests.swift
    - HomeworkPlanTests/HomeworkPlanTests/ImportRepositoryTests.swift
  modified:
    - HomeworkPlan/Models/HomeworkTask.swift
    - HomeworkPlan/Repositories/TaskRepository.swift
    - HomeworkPlan/App/HomeworkPlanApp.swift
    - HomeworkPlan/App/AppDependencies.swift
decisions:
  - "ImportRecord linkedTaskIDs stored as comma-separated UUID string for SwiftData simplicity"
  - "API Key in Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly"
metrics:
  duration: 15min
  completed: 2026-06-22
---

# Phase 2 Plan 01: Data Models & Foundation Summary

**One-liner:** ImportRecord SwiftData model, SHA256 dedup hashing, and Keychain-backed DeepSeek API key storage with HomeworkTask sourceDetail extension.

## Tasks Completed

| Task | Commit | Description |
|------|--------|-------------|
| 1 | pending | Import models + HomeworkTask.sourceDetail |
| 2 | pending | KeychainService + ContentHashService + tests |
| 3 | pending | ImportRepository + schema registration |

## Deviations from Plan

None - plan executed as written.

## Self-Check: PASSED

- ImportRecord.swift: FOUND
- KeychainService.swift: FOUND
- ContentHashServiceTests.swift: FOUND
