<!--
AUTO_VERSION_BLOCK
version: b2fa8da-dirty
commit: b2fa8da
updated_utc: 2026-01-09 12:53:27 UTC
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