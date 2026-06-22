---
phase: 02
slug: import-ai-parsing
status: approved
shadcn_initialized: false
preset: ios-native
created: 2026-06-22
---

# Phase 2 — UI Design Contract

> SwiftUI native iOS app — import & AI parsing flows. Approved for planning/execution.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (SwiftUI native) |
| Preset | iOS Human Interface Guidelines |
| Component library | SwiftUI system components |
| Icon library | SF Symbols |
| Font | System (San Francisco) |

---

## Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4pt | Icon gaps |
| sm | 8pt | Compact spacing |
| md | 16pt | Default padding |
| lg | 24pt | Section spacing |
| xl | 32pt | Sheet margins |

Exceptions: none

---

## Typography

| Role | Size | Weight | Usage |
|------|------|--------|-------|
| Body | 17pt | Regular | List rows, form fields |
| Label | 15pt | Medium | Section headers |
| Heading | 20pt | Semibold | Sheet titles |
| Caption | 13pt | Regular | Confidence, hints |

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant | systemBackground | Main surfaces |
| Secondary | secondarySystemGroupedBackground | Cards, banners |
| Accent | .blue | Primary CTAs only (导入、确认、保存) |
| Destructive | .red | 丢弃、删除 |
| Warning | .orange | Clipboard hint banner |

Accent reserved for: 导入 button, 开始解析, 确认, 全部确认, API Key 保存

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA (Today toolbar) | 导入 |
| Import sheet title | 导入作业 |
| Screenshot option | 从相册选择截图 |
| Paste option | 粘贴文字 |
| Clipboard banner | 检测到剪贴板内容，是否导入？ |
| Review screen title | 确认作业 |
| Confirm single | 确认 |
| Edit single | 编辑 |
| Discard single | 丢弃 |
| Batch confirm | 全部确认 |
| Batch discard | 全部丢弃 |
| Empty candidates | 未识别到作业内容 |
| No API Key | 请先在设置中配置 DeepSeek API Key |
| API Key settings | DeepSeek API Key |
| Parse failure fallback | 解析失败，可查看原文手动录入 |

---

## Interaction Contracts

### Import entry (Today tab)
- Toolbar trailing: existing「添加作业」+ new「导入」(leading or menu — use `Menu` with 添加作业 + 导入, OR separate buttons; CONTEXT says 导入 button with sheet)
- Sheet presents two options then navigates to sub-flow

### Screenshot import
- PhotosPicker single/multi selection
- Progress: 「正在识别文字…」→「正在解析…」
- On duplicate hash: alert「该内容已导入过」

### Paste import
- TextEditor min height 200pt
- Submit button「开始解析」disabled when empty

### Review screen
- List of candidates with subject emoji+name, content, due date, confidence badge
- Swipe or buttons: 确认 / 编辑 / 丢弃
- Toolbar: 全部确认 | 全部丢弃
- Confirmed tasks NOT auto-saved until user taps 确认

### Settings
- NavigationLink「DeepSeek API Key」→ SecureField + 保存
- Masked display when saved

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS (N/A — no web registry)

**Approval:** approved 2026-06-22
