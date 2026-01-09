<!--
AUTO_VERSION_BLOCK
version: b2fa8da-dirty
commit: b2fa8da
updated_utc: 2026-01-09 12:53:27 UTC
AUTO_VERSION_BLOCK
-->
# re-creational prompting

This repository documents a workflow for **re-creating the state of an existing AI conversation** (from ChatGPT, Claude, Perplexity, Grok, etc.) in a new chat or a new GPT—especially when the original thread is long and includes iterative drafts and uploaded documents.

The core idea: from a transcript + attachments, generate two artifacts:

## A) Durable result document (Markdown)
A structured document with:
1) **Tasks and questions from the user** (chronological, linked to message references)  
2) **Responses from the AI** (what the assistant produced, tied to tasks)  
3) **Consolidated results so far** (complete current-state documentation, *not* a high-level summary; redundancy removed)

## B) Continuation prompt
A single prompt that allows continuing the conversation seamlessly, including:
1) A **role** for the AI to take on  
2) **Context** (goals, constraints, definitions, decisions, current artifacts, open items)  
3) “Where we left off / Next step”

---

## Recommended input formats

### Markdown transcript (preferred)
- Chronological
- Clear speaker labels: User: / Assistant:
- Message IDs (M1, M2, …)
- Attachments listed at the end with which message they belong to

### JSON export (optional)
- Array of messages with roles and content
- Attachments linked to message IDs if applicable

---

## Repository contents
- **GPT_INSTRUCTIONS.md** — instructions you can paste into the “Instructions” field when building a custom GPT.
- (Optional) Add examples under /examples later:
  - xample_transcript.md
  - xample_output_A.md
  - xample_output_B_prompt.txt

---

## Suggested next steps
- Add an xamples/ folder with a real transcript + generated outputs.
- Add a small parser script (PowerShell or Python) that converts JSON exports into the canonical Markdown transcript format.

<!-- GPT_BUILDER_SETUP -->

## GPT Builder setup (8,000 char limit)
- Paste GPT_INSTRUCTIONS_CORE.md into the GPT **Instructions** field.
- Upload the files in knowledge/ as GPT **Knowledge**:
  - KNOWLEDGE_EXPORT_GUIDE.md
  - KNOWLEDGE_HELPER_SCRIPTS.md
- Add a conversation starter: Instructions, please!
