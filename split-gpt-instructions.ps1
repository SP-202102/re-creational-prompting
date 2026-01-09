<#
.SYNOPSIS
  Creates a split of GPT instructions to fit the 8,000 character limit for the GPT "Instructions" field:
   - GPT_INSTRUCTIONS_CORE.md (fits under 8k chars)
   - knowledge/KNOWLEDGE_EXPORT_GUIDE.md
   - knowledge/KNOWLEDGE_HELPER_SCRIPTS.md

  Also optionally updates README.md with short setup guidance.

.REQUIREMENTS
  - PowerShell 7+
  - (Optional) git on PATH to detect repo root; otherwise uses current directory

.USAGE
  pwsh -File .\split-gpt-instructions.ps1
  pwsh -File .\split-gpt-instructions.ps1 -UpdateReadme:$false
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [bool]$UpdateReadme = $true,

    [Parameter(Mandatory = $false)]
    [int]$CoreMaxCharacters = 8000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "Please run with PowerShell 7 (pwsh). Example: pwsh -File .\split-gpt-instructions.ps1"
}

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$CommandName)
    return [bool](Get-Command -Name $CommandName -ErrorAction SilentlyContinue)
}

function Get-RepositoryRootOrCurrent {
    if (Test-CommandExists -CommandName "git") {
        $root = (& git rev-parse --show-toplevel 2>$null).Trim()
        if ($root) { return $root }
    }
    return (Get-Location).Path
}

function New-DirectoryIfNotExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Set-Utf8NoBomFileContent {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $parent = Split-Path -Path $FilePath -Parent
    if ($parent) { New-DirectoryIfNotExists -Path $parent }

    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBomEncoding)
}

function Get-CharacterCount {
    param([Parameter(Mandatory = $true)][string]$Text)
    return ($Text.ToCharArray().Count)
}

$repoRoot = Get-RepositoryRootOrCurrent
Set-Location -Path $repoRoot

$knowledgeDirectoryPath = Join-Path $repoRoot "knowledge"
New-DirectoryIfNotExists -Path $knowledgeDirectoryPath

# -----------------------------
# File contents (authoritative)
# -----------------------------

$coreContent = @'
<!--
AUTO_VERSION_BLOCK
version: {{GIT_DESCRIBE}}
commit: {{GIT_SHA}}
updated_utc: {{UPDATED_UTC}}
AUTO_VERSION_BLOCK
-->

# GPT Instructions (CORE) — Re-creational Prompting

You are a Conversation Reconstruction & Results Librarian.

## Mission
From a provided transcript (and optional attachments), produce two deliverables:
A) RESULT.md — tasks/questions, AI responses, consolidated results so far
B) CONTINUATION_PROMPT.md — a paste-ready prompt to continue seamlessly in a new chat/GPT

## Source of truth
- Use ONLY the provided transcript and uploaded files as factual sources.
- Knowledge files are allowed ONLY for “how to export/get a transcript” instructions and helper script references.
- Never invent missing facts/outputs. If unknown, write: “Unknown / not in transcript/files”.

## Mode switch
If the user says: “Instructions, please!” (or clearly asks how to export/get a transcript)
- Do NOT reconstruct.
- Provide platform-specific export/share steps by summarizing KNOWLEDGE_EXPORT_GUIDE.md.
- Mention relevant helper scripts from KNOWLEDGE_HELPER_SCRIPTS.md if needed.
- End with: “Paste your transcript (and upload referenced files) when ready for RESULT.md + CONTINUATION_PROMPT.md.”

## Preferred inputs
1) Markdown transcript: chronological, speaker labels (User/Assistant), preserves code blocks, includes an Attachments section.
2) JSON export (platform export).
3) Share link or copied thread text.
If attachments are referenced but missing, record them as missing.

## Reconstruction workflow (when transcript is provided)
1) Parse & index messages chronologically. Assign IDs if missing: M1, M2, …
2) Extract user tasks/questions:
   - Create Task IDs: T1, T2, …
   - For each: title, ask, message refs, dependencies, status (Done/Partial/Open/Blocked), acceptance criteria if stated.
3) Extract AI responses per task:
   - What the AI produced (decisions, drafts, code, tables), with message refs.
4) Consolidate results so far (current state):
   - Merge iterative versions into the best current version.
   - Remove redundancy and superseded intermediate content.
   - Preserve still-relevant alternatives as Option A/B only if supported by the transcript.
   - Include requirements, constraints, decisions, artifacts, assumptions (marked), open questions, risks, next steps.
   - Cite document-derived facts inline as: (Attachment: filename.ext, referenced in M#).

## Output format
Deliverable A — RESULT.md with exactly:
1) Tasks and questions from the user (T#)
2) Responses from the AI (mapped to T#)
3) Consolidated results so far (current state, de-duplicated)

Deliverable B — CONTINUATION_PROMPT.md (single paste-ready prompt) including:
- Role for the AI
- Context (goals/constraints/definitions/decisions/artifacts/open items)
- Where we left off + next steps
- Final line: “Ask if any required info is missing from the transcript/files.”
'@

$exportGuideContent = @'
<!--
AUTO_VERSION_BLOCK
version: {{GIT_DESCRIBE}}
commit: {{GIT_SHA}}
updated_utc: {{UPDATED_UTC}}
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
'@

$helperScriptsContent = @'
<!--
AUTO_VERSION_BLOCK
version: {{GIT_DESCRIBE}}
commit: {{GIT_SHA}}
updated_utc: {{UPDATED_UTC}}
AUTO_VERSION_BLOCK
-->

# KNOWLEDGE — Helper Scripts & Repo Automation

This knowledge file describes the helper scripts in this repository.

## 1) Autoversion + hooks
- bootstrap.ps1
  - creates: tools/, .githooks/
  - writes: tools/update-autoversion.ps1, .githooks/pre-commit
  - sets: git config core.hooksPath .githooks
  - updates AUTO_VERSION_BLOCK in markdown files

Usage:
- Run once per clone (repo-local config):
  pwsh -File .\bootstrap.ps1

Notes:
- Pre-commit updates version info based on current HEAD (pre-commit cannot know the future commit hash).
- If you only want certain docs versioned, add AUTO_VERSION_BLOCK only to those files.

## 2) Instruction splitting (this repo)
- split-gpt-instructions.ps1
  - creates GPT_INSTRUCTIONS_CORE.md (fits GPT 8k limit)
  - creates knowledge/KNOWLEDGE_EXPORT_GUIDE.md
  - creates knowledge/KNOWLEDGE_HELPER_SCRIPTS.md

Usage:
  pwsh -File .\split-gpt-instructions.ps1

## 3) Optional future helper: ChatGPT export ZIP → single conversation transcript
If you add a script like tools/extract-chatgpt-conversation.ps1 later, it should:
- take the OpenAI export ZIP
- extract one conversation by title/id
- write a canonical TRANSCRIPT.md with speaker labels and an Attachments list
'@

# -----------------------------
# Write files
# -----------------------------
$corePath = Join-Path $repoRoot "GPT_INSTRUCTIONS_CORE.md"
$exportGuidePath = Join-Path $knowledgeDirectoryPath "KNOWLEDGE_EXPORT_GUIDE.md"
$helperScriptsPath = Join-Path $knowledgeDirectoryPath "KNOWLEDGE_HELPER_SCRIPTS.md"

Set-Utf8NoBomFileContent -FilePath $corePath -Content $coreContent
Set-Utf8NoBomFileContent -FilePath $exportGuidePath -Content $exportGuideContent
Set-Utf8NoBomFileContent -FilePath $helperScriptsPath -Content $helperScriptsContent

# -----------------------------
# Verify core length
# -----------------------------
$coreCharCount = Get-CharacterCount -Text $coreContent
Write-Host ""
Write-Host "Created/updated:" -ForegroundColor Green
Write-Host " - $corePath"
Write-Host " - $exportGuidePath"
Write-Host " - $helperScriptsPath"
Write-Host ""
Write-Host "CORE char count: $coreCharCount (limit: $CoreMaxCharacters)"

if ($coreCharCount -gt $CoreMaxCharacters) {
    Write-Warning "GPT_INSTRUCTIONS_CORE.md exceeds $CoreMaxCharacters characters. You must shorten it."
} else {
    Write-Host "CORE fits within the GPT Instructions limit." -ForegroundColor Green
}

# -----------------------------
# Optional: Update README
# -----------------------------
if ($UpdateReadme) {
    $readmePath = Join-Path $repoRoot "README.md"
    if (Test-Path -LiteralPath $readmePath) {
        $readmeText = Get-Content -LiteralPath $readmePath -Raw

        $marker = "<!-- GPT_BUILDER_SETUP -->"
        $block = @"
$marker

## GPT Builder setup (8,000 char limit)
- Paste `GPT_INSTRUCTIONS_CORE.md` into the GPT **Instructions** field.
- Upload the files in `knowledge/` as GPT **Knowledge**:
  - `KNOWLEDGE_EXPORT_GUIDE.md`
  - `KNOWLEDGE_HELPER_SCRIPTS.md`
- Add a conversation starter: `Instructions, please!`
"@

        if ($readmeText -notmatch [regex]::Escape($marker)) {
            $newReadmeText = $readmeText.TrimEnd() + "`n`n" + $block + "`n"
            Set-Utf8NoBomFileContent -FilePath $readmePath -Content $newReadmeText
            Write-Host "README updated with GPT Builder setup block." -ForegroundColor Green
        } else {
            Write-Host "README already contains GPT Builder setup marker; not updating." -ForegroundColor Yellow
        }
    }
}
