# Requirements: HomeworkPlan

**Defined:** 2026-06-22
**Core Value:** 手动提供作业内容后，App 能可靠地将信息转化为经用户确认的每日作业清单

## v1 Requirements

### Task Management

- [x] **TASK-01**: User can create homework tasks manually with subject, content, due date, and optional notes
- [x] **TASK-02**: User sees today's incomplete homework tasks grouped by subject on the default screen
- [x] **TASK-03**: User can mark a homework task complete and record completion time
- [x] **TASK-04**: User can edit saved homework tasks (subject, content, due date, notes)
- [x] **TASK-05**: User can delete homework tasks via swipe or equivalent action
- [x] **TASK-06**: User can browse homework tasks for dates other than today
- [x] **TASK-07**: User can manage subjects (default set plus custom subjects)

### Homework Import

- [x] **IMPT-01**: User can select one or more homework screenshots from the photo library to import
- [x] **IMPT-02**: System runs Apple Vision OCR on imported screenshots and stores extracted text with the import record
- [x] **IMPT-03**: User can paste copied homework or chat text into the app as an import source
- [x] **IMPT-04**: System detects clipboard content hint when app opens or enters foreground (with iOS privacy compliance)
- [x] **IMPT-05**: System computes content hash and avoids re-processing exact duplicate imports

### Homework Parsing

- [x] **PARSE-01**: System sends OCR or pasted text to DeepSeek and returns structured task candidates (subject, content, due date, assigner, confidence)
- [x] **PARSE-02**: System distinguishes homework from unrelated chat, notices, and parent discussion
- [x] **PARSE-03**: System normalizes relative due dates (e.g. "tomorrow") using import timestamp
- [x] **PARSE-04**: System validates model JSON output against local schema; retries once on failure
- [x] **PARSE-05**: Parsed results display as task candidates without auto-saving to database
- [x] **PARSE-06**: User can confirm, edit, or discard each parsed task candidate before saving

### Recurring Tasks

- [ ] **RECUR-01**: User can create recurring rules with subject, content, frequency (daily/weekdays/weekly/custom), and reminder time
- [ ] **RECUR-02**: System generates homework tasks from active recurring rules when app starts or enters foreground
- [ ] **RECUR-03**: System avoids generating duplicate tasks for the same rule and date (deterministic generation key)
- [ ] **RECUR-04**: User can pause, resume, and delete recurring rules

### Local Reminders

- [ ] **REMND-01**: User can configure default reminder times in settings
- [ ] **REMND-02**: System schedules local notifications for incomplete tasks with due dates
- [ ] **REMND-03**: System schedules local notifications for generated recurring tasks when rule includes reminder
- [ ] **REMND-04**: System cancels pending notifications when task is completed or deleted
- [ ] **REMND-05**: System requests notification permission before scheduling; explains if denied

### Settings & Security

- [x] **SETT-01**: User can configure DeepSeek API Key stored securely in Keychain
- [x] **SETT-02**: App blocks AI parsing with clear guidance when API Key is not configured
- [x] **SETT-03**: SwiftData persists all data locally with iCloud sync enabled for multi-device continuity

## v2 Requirements

### Extensions

- **EXT-01**: Share Extension for importing screenshots from system share sheet
- **EXT-02**: ReplayKit Broadcast Upload Extension for automatic screen capture

### Automation

- **AUTO-01**: Monitor rules for screen recording capture (group name OCR + content parsing)
- **AUTO-02**: DingTalk robot/webhook integration with lightweight backend

### Enhancements

- **ENHN-01**: WidgetKit home screen widget showing today's incomplete tasks
- **ENHN-02**: Historical statistics (completion rate, subject distribution) with Swift Charts
- **ENHN-03**: Qwen-VL fallback when OCR quality is insufficient

## Out of Scope

| Feature | Reason |
|---------|--------|
| ReplayKit screen recording | MVP validates manual import first; high permission/memory risk |
| Broadcast Upload Extension | Depends on screen recording automation |
| Claude Vision / Qwen-VL primary path | MVP uses Vision OCR + DeepSeek text parsing |
| Backend / DingTalk webhook | Local-first self-use MVP |
| Multi-user / teacher / school admin | Out of scope for personal use |
| Share Extension | Deferred to v2; in-app photo picker sufficient for MVP |
| Auto-save parsed tasks | User confirmation required for trust |
| External platform check-in | Not solving multi-platform打卡 fatigue in MVP |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TASK-01 | Phase 1 | Complete |
| TASK-02 | Phase 1 | Complete |
| TASK-03 | Phase 1 | Complete |
| TASK-04 | Phase 1 | Complete |
| TASK-05 | Phase 1 | Complete |
| TASK-06 | Phase 1 | Complete |
| TASK-07 | Phase 1 | Complete |
| SETT-03 | Phase 1 | Complete |
| IMPT-01 | Phase 2 | Complete |
| IMPT-02 | Phase 2 | Complete |
| IMPT-03 | Phase 2 | Complete |
| IMPT-04 | Phase 2 | Complete |
| IMPT-05 | Phase 2 | Complete |
| PARSE-01 | Phase 2 | Complete |
| PARSE-02 | Phase 2 | Complete |
| PARSE-03 | Phase 2 | Complete |
| PARSE-04 | Phase 2 | Complete |
| PARSE-05 | Phase 2 | Complete |
| PARSE-06 | Phase 2 | Complete |
| SETT-01 | Phase 2 | Complete |
| SETT-02 | Phase 2 | Complete |
| RECUR-01 | Phase 3 | Pending |
| RECUR-02 | Phase 3 | Pending |
| RECUR-03 | Phase 3 | Pending |
| RECUR-04 | Phase 3 | Pending |
| REMND-01 | Phase 4 | Pending |
| REMND-02 | Phase 4 | Pending |
| REMND-03 | Phase 4 | Pending |
| REMND-04 | Phase 4 | Pending |
| REMND-05 | Phase 4 | Pending |

**Coverage:**

- v1 requirements: 30 total
- Mapped to phases: 30/30 ✓
- Unmapped: 0

---
*Requirements defined: 2026-06-22*
*Last updated: 2026-06-22 after roadmap creation*
