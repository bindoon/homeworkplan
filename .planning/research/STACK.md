# Stack Research — v2.0 AI Native Additions

**Project:** HomeworkPlan v2.0 AI Native  
**Researched:** 2026-06-22  
**Scope:** Stack additions only — v1.0 stack (SwiftUI, SwiftData, Vision, DeepSeek, Keychain) unchanged

## v1.0 Baseline (Unchanged)

SwiftUI + MVVM, SwiftData + CloudKit, Apple Vision OCR, DeepSeek Chat Completions (JSON mode), Keychain, UNUserNotificationCenter, zero external SPM.

## Recommended Additions

### LLM Tool-Calling

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Tool protocol | Swift `AgentTool` protocol + JSON Schema definitions | Type-safe, testable, no runtime reflection |
| LLM API | DeepSeek Chat Completions with `tools` parameter | Already integrated; supports OpenAI-compatible function calling |
| Agent loop | `AgentOrchestrator` @MainActor async loop | Max 5 tool rounds, then force user-facing summary |
| Response format | Structured `AgentTurn` (message, pendingConfirmation, toolCalls) | Drives Action Console UI |

**Confidence:** HIGH — DeepSeek documents function calling; existing `ParseService` pattern extends naturally.

### Speech Input

| Component | Choice | Rationale |
|-----------|--------|-----------|
| STT | `SFSpeechRecognizer` + `AVAudioEngine` | Native, free, zh-CN supported on device |
| Permissions | `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription` | Required Info.plist keys |
| UX | Press-hold or tap-to-record button on Action Console | Simpler than continuous dictation for short homework descriptions |

**Confidence:** HIGH — standard iOS pattern.

### Multimodal Attachments

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Image attach | `PhotosPicker` + pasteboard `UIImage` in Action Console | Reuse v1.0 screenshot flow; pass image to `import_from_image` tool |
| Image in agent context | Base64 thumbnail + OCR text pre-extracted locally | Keep Extension/API payload small; Vision runs before LLM |

**Confidence:** HIGH — v1.0 already has PhotosPicker + OCR pipeline.

### UI Shell

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Tab structure | 2-tab `TabView` (Home, Action) + Settings via toolbar gear or third minimal tab | User requested 2 primary tabs |
| Action Console | `ScrollView` + `TextField` + attachment bar + confirmation cards | Chat-like but not full chat clone — focus on one input |

## What NOT to Add

| Avoid | Why |
|-------|-----|
| LangChain / external agent frameworks | Overkill for single-user iOS app; adds SPM dependency |
| On-device LLM (Core ML) | Quality insufficient for Chinese homework parsing vs DeepSeek |
| Separate backend agent service | Violates local-first constraint |
| RAG / vector DB | Homework context fits in prompt + tool results |
| Full chat history persistence | complicates SwiftData; session-scoped history sufficient for v2.0 |

## Integration Points

```
ActionConsoleView
  → AgentOrchestrator.run(userInput, attachments)
    → DeepSeek (tools: ToolRegistry.schemas)
    → ToolExecutor.execute(call) → existing ImportService / TaskRepository / etc.
    → ConfirmationGate → TaskCandidateReviewView pattern
    → Persist on approve
```

## Info.plist Additions

- `NSSpeechRecognitionUsageDescription` — 语音描述作业时需要
- `NSMicrophoneUsageDescription` — 录制语音时需要
