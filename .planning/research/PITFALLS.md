# Pitfalls Research — v2.0 AI Native

**Project:** HomeworkPlan v2.0  
**Researched:** 2026-06-22

## P1: Agent Writes Without Confirmation

**Warning signs:** Tasks appear in Home before user taps confirm; tests skip ConfirmationGate  
**Prevention:** ToolExecutor returns `Proposal` type for all mutating tools; only `confirm(proposalId)` calls repository write  
**Phase:** 1

## P2: Duplicating Business Logic in Tools

**Warning signs:** Tool implementations copy-paste repository logic; ImportService bypassed  
**Prevention:** Tools are thin adapters — max 10 lines calling existing service methods  
**Phase:** 1

## P3: Removing Forms Before NL Reliable

**Warning signs:** User stuck when agent mis-parses "每周一三五"; no manual escape hatch  
**Prevention:** Phase 4 removes Settings form entry; Phases 1-3 keep fallback navigation  
**Phase:** 4

## P4: Infinite Agent Loops / Runaway API Cost

**Warning signs:** Orchestrator loops >5 times; repeated failed tool calls  
**Prevention:** Hard cap 5 tool rounds; dedupe identical tool calls in same session  
**Phase:** 1

## P5: Speech Permission Friction

**Warning signs:** Mic button crashes without Info.plist; silent failure on deny  
**Prevention:** Graceful degrade to text-only; inline permission rationale before first record  
**Phase:** 2

## P6: Home Merge Performance

**Warning signs:** Loading all history tasks on launch; janky collapse animations  
**Prevention:** Lazy load date sections; default collapsed for non-today; paginate All history  
**Phase:** 3

## P7: Tool Schema Hallucination

**Warning signs:** LLM calls `add_homework` instead of `create_task`; crashes on unknown tool  
**Prevention:** Strict tool name validation; retry with error message to LLM once  
**Phase:** 1

## P8: OCR + Agent Double Parse

**Warning signs:** Vision OCR then LLM re-OCR same image; 2x latency/cost  
**Prevention:** Pass OCR text as tool input; image tool uses pre-extracted text  
**Phase:** 2

## P9: Breaking v1.0 iCloud Sync

**Warning signs:** New models break CloudKit schema; migration missing  
**Prevention:** Agent session state NOT in SwiftData; only existing @Model types persist  
**Phase:** 1

## P10: Tab Confusion During Migration

**Warning signs:** 5 tabs temporarily; duplicate add flows  
**Prevention:** Feature flag or single PR cutover per phase; Phase 3 removes old tabs atomically  
**Phase:** 3
