<!--
AUTO_VERSION_BLOCK
version: d5a4f82-dirty
commit: d5a4f82
updated_utc: 2026-01-09 11:47:07 UTC
AUTO_VERSION_BLOCK
-->

# KNOWLEDGE — Export / Transcript Guide (ChatGPT, Claude, Perplexity, Grok, Z.ai)

Use this when the user asks: “Instructions, please!” or “How do I export/get a transcript?”

## General best practice (in order)
1) Native export (Markdown/PDF/Docx/JSON)
2) Share link (snapshot) + copy into TRANSCRIPT.md
3) Prompt inside the chat to output a Markdown transcript
4) Manual copy/paste (in parts)

Always mention:
- Remove secrets before sharing.
- Re-upload referenced attachments if possible (exports/share links often omit file binaries).
- If long: provide PART 1 / PART 2 / … without skipping.

---

## ChatGPT (OpenAI)

### Option 1 — Share link (fast snapshot)
1) Open the chat.
2) Use Share to create a shareable link (snapshot).
3) Open the link and copy into a local TRANSCRIPT.md.

Attachments note: share snapshots may not include the original uploaded files. If files mattered, re-upload them.

### Option 2 — Official Data Export (account-wide ZIP)
1) Settings → Data Controls → Export Data
2) Confirm export and download the ZIP from the email
3) Use the archive to extract the single conversation you need (see helper scripts)

Attachments note: files may not be included as binaries in the export; verify the ZIP contents.

### Option 3 — Prompt-in-chat (best for short/medium)
Paste into the existing chat:
“Please output the full conversation so far as a single Markdown transcript with clear speaker labels (User/Assistant) in chronological order, preserving code blocks. Add an Attachments section listing any uploaded files mentioned and the message where each first appears. If it’s too long, split into PART 1 / PART 2 / … without omitting anything.”

---

## Claude (Anthropic)

### Option 1 — Share link (snapshot)
1) Open the chat.
2) Click Share and create/copy the link.
3) Open the shared snapshot and copy into TRANSCRIPT.md.

Attachments note: snapshots typically include text, but often not the original file binaries. Re-upload files separately if needed.

### Option 2 — Export (depends on plan/workspace)
If export is available in your environment, export and provide the resulting archive/JSON.

### Option 3 — Prompt-in-chat
“Please output the full conversation so far as a single Markdown transcript with speaker labels, chronological order, preserving code blocks, and an Attachments section listing referenced files. Split into PART 1 / PART 2 if needed; do not summarize or omit messages.”

---

## Perplexity

### Option 1 — Export button (best)
1) Open the Thread.
2) Use Export and choose Markdown (or PDF/DOCX if preferred).
3) Save as TRANSCRIPT.md (or convert).

Attachments note: exports may omit original file binaries; provide them separately if needed.

### Option 2 — Share thread
Open the thread → Share → copy link → open link → copy into TRANSCRIPT.md.

### Option 3 — Prompt-in-thread
“Please output this entire thread as a single Markdown transcript with speaker labels and an Attachments section listing referenced files/images.”

---

## Grok (xAI)

### Option 1 — Share link
Open the conversation → Share → create link → copy into TRANSCRIPT.md.

Privacy note: treat share links as potentially public; remove sensitive info.

### Option 2 — Manual copy/paste
If no export exists: copy the conversation into TRANSCRIPT.md (use parts if needed).

### Option 3 — Prompt-in-chat
“Please output the full conversation so far as a single Markdown transcript with speaker labels and an Attachments section. Split into PART 1 / PART 2 without skipping.”

---

## Z.ai (chat.z.ai / GLM)

### Option 1 — Export/Download (if the UI supports it)
Look for Export / Download / History / Share in the UI. Export text/markdown if available.

### Option 2 — API/developer route (if applicable)
Retrieve conversation history via API and save as JSON/Markdown.

### Option 3 — Manual copy/paste + Prompt-in-chat
If export/share isn’t available, copy into TRANSCRIPT.md and use the same transcript prompt pattern (labels, chronological, attachments list).