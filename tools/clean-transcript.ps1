<#
.SYNOPSIS
  Cleans a transcript produced by extract-chatgpt-conversation.ps1 by removing assistant
  messages that contain only tool-call JSON (e.g., {"search_query":[...]}).

USAGE
  pwsh -File .\tools\clean-transcript.ps1 -InputPath .\TRANSCRIPT.md -OutputPath .\TRANSCRIPT.cleaned.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Set-Utf8NoBomFileContent {
    param([string]$FilePath, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBom)
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input not found: $InputPath"
}

$raw = Get-Content -LiteralPath $InputPath -Raw

# Matches one message block:
# [M#] Assistant (...):
# ```text
# {...json...}
# ```
$pattern = '(?s)\[M\d+\]\s+Assistant.*?\n```text\s*\n(.*?)\n```\s*\n'

$toolKeys = @(
    '"search_query"', '"open"', '"click"', '"find"', '"screenshot"', '"image_query"',
    '"product_query"', '"sports"', '"finance"', '"weather"', '"calculator"', '"time"'
)

$cleaned = [System.Text.RegularExpressions.Regex]::Replace(
    $raw,
    $pattern,
    {
        param($match)
        $content = $match.Groups[1].Value.Trim()

        # Detect "pure tool-call JSON"
        $isJsonLike = $content.StartsWith("{") -and $content.EndsWith("}")
        $containsToolKey = $false
        foreach ($k in $toolKeys) {
            if ($content.Contains($k)) { $containsToolKey = $true; break }
        }

        if ($isJsonLike -and $containsToolKey) {
            # Remove this entire assistant message block
            return ""
        }

        # Keep unchanged
        return $match.Value
    }
)

# Optional: collapse extra blank lines
$cleaned = [System.Text.RegularExpressions.Regex]::Replace($cleaned, "(\r?\n){3,}", "`n`n")

Set-Utf8NoBomFileContent -FilePath $OutputPath -Content $cleaned
Write-Host "Wrote cleaned transcript: $OutputPath"
