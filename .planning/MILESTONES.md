# Milestones

## v1.0 MVP (Shipped: 2026-06-22)

**Phases completed:** 4 phases, 10 plans, 12 tasks

**Key accomplishments:**

- SwiftUI walking skeleton with SwiftData dual models, CloudKit container, three-tab shell, default subject seeding, and manual task CRUD on Today view
- TaskRepository full write API with unit tests, completion toggle with haptics, edit sheet, and swipe-to-delete on Today tab
- Today tab compact DatePicker with selected-day filtering and All tab date-section grouped task history
- Settings tab subject CRUD with normalizedName dedupe, default subject protection, and live @Query picker in task forms
- DEBUG CloudKit schema initializer, SubjectDedupeService on remote change, App Store privacy manifest, and Chinese README with xcodebuild and iCloud verification steps
- ImportRecord SwiftData model, SHA256 dedup hashing, and Keychain-backed DeepSeek API key storage with HomeworkTask sourceDetail extension.
- Vision OCR (.accurate, zh-Hans/en-US) feeding DeepSeek JSON-mode parser with schema validation, retry, and ImportService orchestration including hash dedup.
- PhotosPicker screenshot import, paste flow, clipboard hint banner, candidate review with confirm/edit/discard, and Keychain API Key settings.
- 幂等 generationKey 驱动的重复规则 CRUD 与 App 生命周期自动生成
- UNUserNotificationCenter reminders with 64-pending budget, settings defaults, and TaskRepository/RecurringTaskGenerator lifecycle hooks.

**Known deferred items at close:** 4 verification gaps (see STATE.md Deferred Items) — xcodebuild blocked by missing iOS 26.2 Simulator; runtime UAT pending on developer Mac.

**Tag:** v1.0

---
