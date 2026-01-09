#requires -Version 7.0
<#
.SYNOPSIS
  Extract a single ChatGPT conversation from an OpenAI "Export Data" ZIP and write a Markdown transcript.

USAGE
  # List conversations
  pwsh -File .\tools\extract-chatgpt-conversation.ps1 -ExportZipPath "C:\Temp\openai-export.zip" -ListConversations

  # Extract by title (contains match, newest chosen)
  pwsh -File .\tools\extract-chatgpt-conversation.ps1 -ExportZipPath "C:\Temp\openai-export.zip" -SearchTitle "re-creational prompting" -OutputMarkdownPath ".\TRANSCRIPT.md"

  # Extract by conversation id (exact)
  pwsh -File .\tools\extract-chatgpt-conversation.ps1 -ExportZipPath "C:\Temp\openai-export.zip" -ConversationId "<id>" -OutputMarkdownPath ".\TRANSCRIPT.md"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExportZipPath,

    [Parameter(Mandatory = $false)]
    [switch]$ListConversations,

    [Parameter(Mandatory = $false)]
    [int]$ListMax = 200,

    [Parameter(Mandatory = $false)]
    [string]$SearchTitle,

    [Parameter(Mandatory = $false)]
    [string]$ConversationId,

    [Parameter(Mandatory = $false)]
    [string]$OutputMarkdownPath = ".\TRANSCRIPT.md",

    [Parameter(Mandatory = $false)]
    [string]$WorkDirectory = ".\.tmp_openai_export",

    [Parameter(Mandatory = $false)]
    [switch]$KeepWorkDirectory,

    [Parameter(Mandatory = $false)]
    [string]$AttachmentsOutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBom)
}

function Convert-UnixSecondsToIsoUtc {
    param([double]$UnixSeconds)
    if ($UnixSeconds -le 0) { return $null }
    try {
        return ([DateTimeOffset]::FromUnixTimeSeconds([int64][Math]::Floor($UnixSeconds))).ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
    } catch {
        return $null
    }
}

function Get-ConversationsArray {
    param([Parameter(Mandatory = $true)]$ParsedJson)

    if ($ParsedJson -is [System.Array]) { return $ParsedJson }

    foreach ($key in @('conversations', 'items', 'data')) {
        if ($ParsedJson.ContainsKey($key) -and ($ParsedJson[$key] -is [System.Array])) {
            return $ParsedJson[$key]
        }
    }

    throw "Unsupported conversations.json shape. Expected an array (or an object containing an array)."
}

function Get-ChatMessageText {
    param([Parameter(Mandatory = $true)]$Message)

    if (-not $Message) { return '' }
    if (-not $Message.ContainsKey('content')) { return '' }

    $content = $Message['content']
    if (-not $content) { return '' }

    if ($content -is [string]) { return $content }

    if ($content.ContainsKey('parts') -and ($content['parts'] -is [System.Array])) {
        return ($content['parts'] -join "`n")
    }

    if ($content.ContainsKey('text')) {
        return [string]$content['text']
    }

    return ''
}

function Get-ChatAttachmentNames {
    param([Parameter(Mandatory = $true)]$Message)

    $result = New-Object System.Collections.Generic.HashSet[string]
    if (-not $Message) { return $result }

    $candidates = @()

    if ($Message.ContainsKey('metadata') -and $Message['metadata']) {
        $metadata = $Message['metadata']
        foreach ($key in @('attachments', 'files', 'file_ids', 'uploaded_files')) {
            if ($metadata.ContainsKey($key) -and $metadata[$key]) { $candidates += ,@($metadata[$key]) }
        }
    }

    if ($Message.ContainsKey('content') -and $Message['content']) {
        $content = $Message['content']
        if ($content -isnot [string] -and $content.ContainsKey('attachments') -and $content['attachments']) {
            $candidates += ,@($content['attachments'])
        }
    }

    foreach ($cand in $candidates) {
        if ($cand -is [System.Array]) {
            foreach ($item in $cand) {
                if ($item -is [string]) {
                    if ($item.Trim()) { [void]$result.Add($item.Trim()) }
                } elseif ($item -and ($item -is [hashtable])) {
                    foreach ($k in @('name', 'filename')) {
                        if ($item.ContainsKey($k) -and [string]$item[$k]) {
                            $name = ([string]$item[$k]).Trim()
                            if ($name) { [void]$result.Add($name) }
                        }
                    }
                }
            }
        } elseif ($cand -is [string]) {
            if ($cand.Trim()) { [void]$result.Add($cand.Trim()) }
        }
    }

    return $result
}

function Get-FirstFileByName {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$FileName
    )
    return Get-ChildItem -Path $RootPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $FileName } |
        Select-Object -First 1
}

# ---------------- Main ----------------
if (-not (Test-Path -LiteralPath $ExportZipPath)) {
    throw "Export ZIP not found: $ExportZipPath"
}

if (-not $ListConversations) {
    if ([string]::IsNullOrWhiteSpace($SearchTitle) -and [string]::IsNullOrWhiteSpace($ConversationId)) {
        throw "Provide -SearchTitle or -ConversationId, or use -ListConversations."
    }
    if (-not [string]::IsNullOrWhiteSpace($SearchTitle) -and -not [string]::IsNullOrWhiteSpace($ConversationId)) {
        throw "Use either -SearchTitle OR -ConversationId (not both)."
    }
}

if (Test-Path -LiteralPath $WorkDirectory) {
    Remove-Item -LiteralPath $WorkDirectory -Recurse -Force
}
New-DirectoryIfNotExists -Path $WorkDirectory

Expand-Archive -LiteralPath $ExportZipPath -DestinationPath $WorkDirectory -Force

$conversationsJsonFile = Get-ChildItem -Path $WorkDirectory -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ieq 'conversations.json' } |
    Select-Object -First 1

if (-not $conversationsJsonFile) {
    $chatHtmlFile = Get-ChildItem -Path $WorkDirectory -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq 'chat.html' } |
        Select-Object -First 1

    $msg = @()
    $msg += "conversations.json was not found in this export ZIP."
    if ($chatHtmlFile) {
        $msg += "Found chat.html at: $($chatHtmlFile.FullName)"
        $msg += ""
        $msg += "Workarounds:"
        $msg += "1) Open chat.html in a browser, locate the conversation, copy/paste into TRANSCRIPT.md."
        $msg += "2) Use ChatGPT Share link (snapshot) and copy content."
    } else {
        $msg += "chat.html not found either; export structure may differ."
    }
    throw ($msg -join "`n")
}

$jsonText = Get-Content -LiteralPath $conversationsJsonFile.FullName -Raw
$parsedJson = $jsonText | ConvertFrom-Json -AsHashtable
$conversations = Get-ConversationsArray -ParsedJson $parsedJson

if ($ListConversations) {
    $conversations |
        Select-Object -First $ListMax |
        ForEach-Object {
            $idValue = if ($_.ContainsKey('id')) { [string]$_.id } else { '' }
            $titleValue = if ($_.ContainsKey('title')) { [string]$_.title } else { '' }
            $updatedValue = if ($_.ContainsKey('update_time')) { Convert-UnixSecondsToIsoUtc -UnixSeconds $_.update_time } else { '' }
            [PSCustomObject]@{ title = $titleValue; id = $idValue; updated_utc = $updatedValue }
        } |
        Format-Table -AutoSize

    if (-not $KeepWorkDirectory) { Remove-Item -LiteralPath $WorkDirectory -Recurse -Force }
    return
}

# Select conversation
$conversationCandidates = @()
if (-not [string]::IsNullOrWhiteSpace($ConversationId)) {
    $conversationCandidates = $conversations | Where-Object { $_.ContainsKey('id') -and ([string]$_.id) -eq $ConversationId }
} else {
    $needle = $SearchTitle.ToLowerInvariant()
    $conversationCandidates = $conversations | Where-Object {
        $_.ContainsKey('title') -and $_.title -and ([string]$_.title).ToLowerInvariant().Contains($needle)
    }
}

if (-not $conversationCandidates -or $conversationCandidates.Count -eq 0) {
    throw "No conversation matched. Use -ListConversations to discover titles/ids."
}

$selectedConversation = $conversationCandidates | Sort-Object -Property @{
    Expression = { if ($_.ContainsKey('update_time')) { $_.update_time } else { 0 } }
    Descending = $true
}, @{
    Expression = { if ($_.ContainsKey('create_time')) { $_.create_time } else { 0 } }
    Descending = $true
} | Select-Object -First 1

$title = if ($selectedConversation.ContainsKey('title')) { [string]$selectedConversation.title } else { '' }
$conversationId = if ($selectedConversation.ContainsKey('id')) { [string]$selectedConversation.id } else { '' }
$createdIso = if ($selectedConversation.ContainsKey('create_time')) { Convert-UnixSecondsToIsoUtc -UnixSeconds $selectedConversation.create_time } else { $null }
$updatedIso = if ($selectedConversation.ContainsKey('update_time')) { Convert-UnixSecondsToIsoUtc -UnixSeconds $selectedConversation.update_time } else { $null }

if (-not $selectedConversation.ContainsKey('mapping')) {
    throw "Selected conversation has no 'mapping' field. Export format may have changed."
}

$mapping = $selectedConversation.mapping
$currentNodeId = if ($selectedConversation.ContainsKey('current_node')) { [string]$selectedConversation.current_node } else { '' }

# Build node order (current -> root, then reverse)
$nodeIds = New-Object System.Collections.Generic.List[string]
if ($currentNodeId -and $mapping.ContainsKey($currentNodeId)) {
    $walkerId = $currentNodeId
    while ($walkerId) {
        [void]$nodeIds.Add($walkerId)
        $parentId = $mapping[$walkerId]['parent']
        if (-not $parentId) { break }
        $walkerId = [string]$parentId
    }
    $nodeIds.Reverse()
} else {
    foreach ($key in $mapping.Keys) { [void]$nodeIds.Add([string]$key) }
}

# Output
$outputLines = New-Object System.Collections.Generic.List[string]
$allAttachments = New-Object System.Collections.Generic.HashSet[string]
$messageCounter = 0

$outputLines.Add('# Conversation Transcript')
$outputLines.Add('')
if ($title) { $outputLines.Add("**Title:** $title") }
if ($conversationId) { $outputLines.Add("**Conversation ID:** $conversationId") }
if ($createdIso) { $outputLines.Add("**Created:** $createdIso") }
if ($updatedIso) { $outputLines.Add("**Updated:** $updatedIso") }
$outputLines.Add('')
$outputLines.Add('---')
$outputLines.Add('')
$outputLines.Add('## Messages')
$outputLines.Add('')

foreach ($nodeId in $nodeIds) {
    $node = $mapping[$nodeId]
    if (-not $node) { continue }
    if (-not $node.ContainsKey('message')) { continue }

    $message = $node.message
    if (-not $message) { continue }

    $text = Get-ChatMessageText -Message $message
    if ([string]::IsNullOrWhiteSpace($text)) { continue }

    $role = ''
    if ($message.ContainsKey('author') -and $message.author -and $message.author.ContainsKey('role')) {
        $role = [string]$message.author.role
    }

    $speaker = switch -Regex ($role) {
        'user' { 'User'; break }
        'assistant' { 'Assistant'; break }
        'system' { 'System'; break }
        default { if ($role) { $role } else { 'Unknown' } }
    }

    $timestampIso = $null
    if ($message.ContainsKey('create_time')) { $timestampIso = Convert-UnixSecondsToIsoUtc -UnixSeconds $message.create_time }

    $attachmentNames = Get-ChatAttachmentNames -Message $message
    foreach ($a in $attachmentNames) { if ($a) { [void]$allAttachments.Add($a) } }

    $messageCounter++
    $header = if ($timestampIso) {
        ('[M{0}] {1} ({2}):' -f $messageCounter, $speaker, $timestampIso)
    } else {
        ('[M{0}] {1}:' -f $messageCounter, $speaker)
    }

    $outputLines.Add($header)
    $outputLines.Add('')
    $outputLines.Add('```text')
    $outputLines.Add($text.TrimEnd())
    $outputLines.Add('```')
    $outputLines.Add('')
}

$outputLines.Add('---')
$outputLines.Add('')
$outputLines.Add('## Attachments (best effort)')
$outputLines.Add('')

if ($allAttachments.Count -eq 0) {
    $outputLines.Add('- No attachment metadata detected in conversations.json. (If uploads were used, re-upload them alongside this transcript.)')
} else {
    foreach ($name in ($allAttachments | Sort-Object)) { $outputLines.Add("- $name") }
}

Set-Utf8NoBomFileContent -FilePath $OutputMarkdownPath -Content ($outputLines -join "`n")
Write-Host ("Wrote transcript: {0}" -f $OutputMarkdownPath) -ForegroundColor Green

# Best-effort: copy attachment binaries if requested
if ($AttachmentsOutputDirectory) {
    New-DirectoryIfNotExists -Path $AttachmentsOutputDirectory
    $copiedCount = 0

    foreach ($name in ($allAttachments | Sort-Object)) {
        $found = Get-FirstFileByName -RootPath $WorkDirectory -FileName $name
        if ($found) {
            Copy-Item -LiteralPath $found.FullName -Destination (Join-Path $AttachmentsOutputDirectory $found.Name) -Force
            $copiedCount++
        }
    }

    if ($copiedCount -gt 0) {
        Write-Host ("Copied {0} attachment file(s) to: {1}" -f $copiedCount, $AttachmentsOutputDirectory) -ForegroundColor Green
    } else {
        Write-Host "No attachment binaries found in the ZIP to copy (common). You may need to re-download uploads separately." -ForegroundColor Yellow
    }
}

if (-not $KeepWorkDirectory) {
    Remove-Item -LiteralPath $WorkDirectory -Recurse -Force
}
