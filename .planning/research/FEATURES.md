# Features Research — v2.0 AI Native

**Project:** HomeworkPlan v2.0  
**Researched:** 2026-06-22  
**Context:** Subsequent milestone — transform interaction layer on v1.0 foundation

## v1.0 Baseline (Already Built)

Today/All/Settings tabs, manual CRUD, screenshot+paste import, OCR+DeepSeek parse, confirm gate, recurring rules, reminders, subject forms.

## Table Stakes (Must Have for AI Native Feel)

| Feature | Why | Complexity |
|---------|-----|------------|
| Single input action surface | User's core ask — one box for everything | M |
| Tool-backed write operations | Import/add/edit must invoke real services, not fake chat | L |
| Confirmation before persist | Parent trust — non-negotiable from v1.0 | M |
| Agent explains what it will do | "我将添加 3 条数学作业，请确认" before save | M |
| Text NL task creation | "明天交英语抄写第三课" | M |
| Query answers on home | Home stays read-focused; agent can still answer "本周还有多少未做" via tools | S |

## Differentiators

| Feature | Why | Complexity |
|---------|-----|------------|
| Voice → homework | Hands-free while helping child | M |
| Image paste in action box | No separate import screen navigation | M |
| NL subject/recurring admin | "每天练字" replaces form wizard | L |
| Collapsible home sections | Clean query view with depth on demand | M |
| Merged today + history | One tab to see all context | M |

## Anti-Features (Deliberately NOT Build)

| Anti-feature | Reason |
|--------------|--------|
| Autonomous agent without confirm | High mis-parse cost for homework |
| Full ChatGPT clone UI | User wants simple input, not conversation product |
| Remove manual fallback entirely | Agent/API failure must not brick app |
| Agent modifies completed tasks silently | Trust violation |
| Multi-agent swarm | Single orchestrator sufficient |
| Settings forms removed before NL works | Keep read-only fallback links until Phase 4 |

## Feature Dependencies

```
ToolRegistry (foundation)
  ├── Action Console text NL
  ├── Multimodal attach (image/voice)
  └── NL subject/recurring

Home merge (independent of agent, can parallel after Phase 1)
  └── Collapsible sections depend on unified list data source
```

## Complexity Summary

- **Phase 1 deliverable:** Type in Action tab → agent adds homework with confirm
- **Phase 2 deliverable:** Paste screenshot or speak → same flow
- **Phase 3 deliverable:** Home shows today + history collapsed
- **Phase 4 deliverable:** "加一门科学" / "取消每天练字" works; Settings slimmed
