---
phase: 02
status: human_needed
verified: 2026-06-22
requirements_covered: IMPT-01, IMPT-02, IMPT-03, IMPT-04, IMPT-05, PARSE-01, PARSE-02, PARSE-03, PARSE-04, PARSE-05, PARSE-06, SETT-01, SETT-02
---

# Phase 2: Import & AI Parsing — Verification

## Status: human_needed

xcodebuild blocked: iOS Simulator runtime not installed (iOS 26.2 SDK present, no simulator devices). Automated build/test could not run in CI environment.

## Must-Haves Verified (static / code review)

| Truth | Status | Evidence |
|-------|--------|----------|
| 相册截图导入 | ✓ code | ScreenshotImportView + PhotosPicker |
| Vision OCR | ✓ code | OCRService VNRecognizeTextRequest .accurate |
| 粘贴导入 | ✓ code | PasteImportView TextEditor |
| 剪贴板 hint | ✓ code | ClipboardHintBanner + hasStrings only |
| 内容哈希去重 | ✓ code | ContentHashService + ImportRepository.findByContentHash |
| DeepSeek 解析 | ✓ code | ParseService actor JSON mode |
| 候选不自动入库 | ✓ code | TaskCandidateReviewView confirm gate |
| 确认/编辑/丢弃 | ✓ code | Review buttons + batch actions |
| API Key Keychain | ✓ code | KeychainService + APIKeySettingsView |
| 未配置 Key 阻断 | ✓ code | ImportServiceError.missingAPIKey |

## Automated Checks

| Check | Result | Notes |
|-------|--------|-------|
| xcodebuild build | BLOCKED | No iOS Simulator installed |
| Unit tests | BLOCKED | Same environment constraint |

## Human Verification Required

1. **Build & run** on simulator/device after installing iOS Simulator runtime in Xcode > Settings > Components
2. **Configure API Key** in 设置 > DeepSeek API Key with valid DeepSeek key
3. **Screenshot import:** pick homework screenshot → OCR → parse → review → confirm → appears in 今日 list with sourceType screenshot
4. **Paste import:** paste group chat text → parse → confirm one candidate
5. **Duplicate import:** import same text twice → second attempt shows duplicate message without re-parse
6. **Clipboard hint:** copy text, background/foreground app → banner appears; tap 导入 → paste sheet pre-filled
7. **Missing API Key:** clear key → import shows「请先在设置中配置 DeepSeek API Key」
8. **Parse failure:** invalid API key or non-homework text → empty candidates with raw text fallback

## Requirement Traceability

| ID | Covered |
|----|---------|
| IMPT-01 | ✓ PhotosPicker screenshot |
| IMPT-02 | ✓ OCRService |
| IMPT-03 | ✓ PasteImportView |
| IMPT-04 | ✓ ClipboardHintBanner |
| IMPT-05 | ✓ ContentHashService |
| PARSE-01 | ✓ ParseService |
| PARSE-02 | ✓ ParsePrompt filters non-homework |
| PARSE-03 | ✓ import timestamp in prompt |
| PARSE-04 | ✓ JSON validation + retry |
| PARSE-05 | ✓ review-only until confirm |
| PARSE-06 | ✓ confirm/edit/discard |
| SETT-01 | ✓ APIKeySettingsView |
| SETT-02 | ✓ missing key blocks parse |

## Gaps

None identified at code level. Runtime verification pending human/device testing.
