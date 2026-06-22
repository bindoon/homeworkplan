# Phase 4: Local Reminders — Research

**Gathered:** 2026-06-22

## Technical Approach

### UNUserNotificationCenter
- Local notifications via `UNUserNotificationCenter.current()`
- Request authorization with `.alert`, `.sound`, `.badge` on first schedule attempt
- Stable identifiers: `{taskId.uuidString}-morning`, `-afternoon`, `-recurring` (never `hashValue`)
- Never call `removeAllPendingNotificationRequests()` — diff pending vs desired IDs

### Notification Budget (64 limit)
- iOS caps pending local notifications at 64
- `NotificationBudgetManager` sorts requests by fire date, selects top 64
- Horizon: 14 days of incomplete tasks with due dates
- Full reschedule on app launch / foreground (after recurring generation)

### Reminder Strategy
| Task type | Notifications |
|-----------|---------------|
| Manual/import with due date | Morning + afternoon on due day (settings times) |
| Recurring-generated (`sourceType == recurring`) | Single notification at `rule.reminderTime` on due day |

Default times: 08:00 morning, 17:00 afternoon (UserDefaults via `ReminderSettings`).

### Integration Points
- `TaskRepository`: schedule on create/update/markIncomplete; cancel on markComplete/delete
- `RecurringTaskGenerator`: schedule after new task with `rule.reminderTime`
- `MainTabView`: `rescheduleAll` after `generateIfNeeded`
- `SettingsView`: reminder times + permission status + denial messaging

### Testing
- Pure logic tests: `ReminderNotificationBuilder`, `NotificationBudgetManager`
- Simulator unreliable for notification delivery — document for human verification

## RESEARCH COMPLETE
