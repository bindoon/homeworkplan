---
phase: 02-multimodal-action-console
plan: 01
subsystem: ui
tags: [swiftui, speech, ocr, agent, multimodal]

requires:
  - phase: 01-agent-foundation-text-action-console
    provides: AgentOrchestrator, ToolExecutor, ActionConsoleView
provides:
  - SpeechInputService with zh-CN SFSpeechRecognizer
  - Screenshot paste/attach with local OCR pre-extraction
  - import_from_image agent tool using pre-extracted OCR text
  - Hold-to-record mic in Action Console input bar
affects: [03-unified-home, 04-nl-admin]

tech-stack:
  added: [Speech framework, AVAudioSession]
  patterns: [UserMessageAttachment pipeline, pre-OCR before LLM]

key-files:
  created:
    - HomeworkPlan/Services/Agent/SpeechInputService.swift
    - HomeworkPlanTests/HomeworkPlanTests/SpeechInputServiceTests.swift
  modified:
    - HomeworkPlan/ViewModels/ActionConsoleViewModel.swift
    - HomeworkPlan/Views/Agent/ActionConsoleView.swift
    - HomeworkPlan/Services/Agent/AgentOrchestrator.swift
    - HomeworkPlan/Services/Agent/ToolExecutor.swift
    - HomeworkPlan/Services/Agent/ToolRegistry.swift
    - HomeworkPlan/Services/Import/ImportService.swift

key-decisions:
  - "Local OCR runs in ViewModel before sendUserMessage; LLM receives ocr_text block and must call import_from_image"
  - "import_from_image receives UserMessageAttachment via ToolExecutor.execute attachment parameter to avoid re-OCR"
  - "Speech permission denial degrades to text-only with inline hint, mic button dimmed"

requirements-completed: [ACTN-04, ACTN-05]

duration: 25min
completed: 2026-06-22
---

# Phase 2 Plan 01: Multimodal Action Console Summary

**Action Console 贴图本地 OCR + import_from_image 管道，以及 zh-CN 按住录音语音输入**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-22T11:18:00Z
- **Completed:** 2026-06-22T11:23:00Z
- **Tasks:** 10
- **Files modified:** 15

## Accomplishments

- 用户可在 Action Console 粘贴/选取截图，本地 Vision OCR 后送入 Agent
- 新增 `import_from_image` 工具，使用预提取 `ocr_text`，不重复 OCR
- 按住/点击麦克风按钮，SFSpeechRecognizer（zh-CN）转写后自动发送
- 麦克风/语音识别权限拒绝时优雅降级为纯文字输入

## Task Commits

1. **SpeechInputService** - `b3d4e23`
2. **import_from_image + orchestrator attachment** - `3b159a6`
3. **Action Console multimodal UI** - `cda2a8b`
4. **Info.plist permissions** - `d1a4c93` (+ pbxproj in `b3d4e23`)
5. **Tests** - `a4f7f6e`
6. **Phase docs** - `2164379`

## Files Created/Modified

- `HomeworkPlan/Services/Agent/SpeechInputService.swift` — 语音识别封装与权限处理
- `HomeworkPlan/Services/Agent/AgentOrchestrator.swift` — `sendUserMessage(text:attachment:)`
- `HomeworkPlan/Services/Agent/ToolExecutor.swift` — `import_from_image` + attachment 参数
- `HomeworkPlan/ViewModels/ActionConsoleViewModel.swift` — 贴图 OCR、录音状态
- `HomeworkPlan/Views/Agent/ActionConsoleView.swift` — 贴图/麦克风输入栏

## Decisions Made

- OCR 在 ViewModel 层完成，Orchestrator 将 OCR 块注入 LLM 用户消息
- `ImportService.processImage(_:preExtractedText:)` 跳过二次 OCR
- 录音结束自动调用 `sendMessage()`，与「文字送入 agent」一致

## Deviations from Plan

None - plan executed as specified.

## Issues Encountered

- xcodebuild 需使用 iPhone 17 模拟器（本机无 iPhone 16 runtime）；14 项相关单元测试已通过

## Next Phase Readiness

- Phase 3 Unified Home 可复用 Action Console 多模态能力
- 设备端 UAT：贴图导入与真机麦克风权限流程待人工验证

## Self-Check: PASSED

---
*Phase: 02-multimodal-action-console*
*Completed: 2026-06-22*
