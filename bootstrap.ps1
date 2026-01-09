<#
.SYNOPSIS
  Repo bootstrap (run from repo root):
  - Creates tools/ and .githooks/ if missing
  - Writes tools/update-autoversion.ps1
  - Writes .githooks/pre-commit
  - Sets git config core.hooksPath = .githooks (repo-local)
  - Ensures .gitattributes forces LF for hooks
  - Optionally adds AUTO_VERSION_BLOCK to markdown files (idempotent)
  - Updates all AUTO_VERSION_BLOCK values immediately

.REQUIREMENTS
  - PowerShell 7+
  - git on PATH
  - pwsh on PATH (for the hook)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [bool]$AddAutoVersionBlockToAllMarkdownFiles = $true,

    [Parameter(Mandatory = $false)]
    [string[]]$MarkdownExcludeDirectoryNames = @(".git", "node_modules", ".venv", ".tmp", ".tmp_openai_export")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "Please run with PowerShell 7 (pwsh). Example: pwsh -File .\bootstrap.ps1"
}

function Assert-CommandExists {
    param([Parameter(Mandatory = $true)][string]$CommandName)

    $command = Get-Command -Name $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$CommandName' was not found on PATH."
    }
}

function New-DirectoryIfNotExists {
    param([Parameter(Mandatory = $true)][string]$DirectoryPath)

    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        New-Item -ItemType Directory -Path $DirectoryPath | Out-Null
    }
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $parentDirectoryPath = Split-Path -Path $FilePath -Parent
    if ($parentDirectoryPath) {
        New-DirectoryIfNotExists -DirectoryPath $parentDirectoryPath
    }

    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBomEncoding)
}

function Get-RepositoryRoot {
    $repoRoot = (& git rev-parse --show-toplevel 2>$null).Trim()
    if (-not $repoRoot) {
        throw "Not a git repository (or git not initialized). Run 'git init' in this folder first."
    }
    return $repoRoot
}

function Get-AllMarkdownFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string[]]$ExcludeDirectoryNames
    )

    Get-ChildItem -Path $RootPath -Recurse -File -Filter "*.md" |
        Where-Object {
            $fullNameLower = $_.FullName.ToLowerInvariant()
            foreach ($excludeName in $ExcludeDirectoryNames) {
                $excludeToken = [System.IO.Path]::DirectorySeparatorChar + $excludeName.ToLowerInvariant() + [System.IO.Path]::DirectorySeparatorChar
                if ($fullNameLower.Contains($excludeToken)) { return $false }
            }
            return $true
        }
}

function Add-AutoVersionBlockIfMissing {
    param([Parameter(Mandatory = $true)][string]$MarkdownFilePath)

    $content = Get-Content -LiteralPath $MarkdownFilePath -Raw
    $pattern = '(?s)<!--\s*AUTO_VERSION_BLOCK.*?AUTO_VERSION_BLOCK\s*-->'

    if ($content -match $pattern) {
        return $false
    }

    $autoBlock = @'
<!--
AUTO_VERSION_BLOCK
version: {{GIT_DESCRIBE}}
commit: {{GIT_SHA}}
updated_utc: {{UPDATED_UTC}}
AUTO_VERSION_BLOCK
-->

'@

    Write-Utf8NoBomFile -FilePath $MarkdownFilePath -Content ($autoBlock + $content)
    return $true
}

# ------------------ Start ------------------
Assert-CommandExists -CommandName "git"
Assert-CommandExists -CommandName "pwsh"

$repositoryRoot = Get-RepositoryRoot
Set-Location -Path $repositoryRoot

$toolsDirectoryPath = Join-Path -Path $repositoryRoot -ChildPath "tools"
$hooksDirectoryPath = Join-Path -Path $repositoryRoot -ChildPath ".githooks"

New-DirectoryIfNotExists -DirectoryPath $toolsDirectoryPath
New-DirectoryIfNotExists -DirectoryPath $hooksDirectoryPath

# 1) Write tools/update-autoversion.ps1
$updateAutoVersionScriptPath = Join-Path -Path $toolsDirectoryPath -ChildPath "update-autoversion.ps1"

$updateAutoVersionScriptContent = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = "",

    [Parameter(Mandatory = $false)]
    [string[]]$MarkdownExcludeDirectoryNames = @(".git", "node_modules", ".venv", ".tmp", ".tmp_openai_export")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-CommandExists {
    param([Parameter(Mandatory = $true)][string]$CommandName)

    $command = Get-Command -Name $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$CommandName' was not found on PATH."
    }
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBomEncoding)
}

function Get-RepositoryRoot {
    if ($RepositoryRoot -and (Test-Path -LiteralPath $RepositoryRoot)) {
        return $RepositoryRoot
    }
    $root = (& git rev-parse --show-toplevel 2>$null).Trim()
    if (-not $root) { throw "Could not determine repository root." }
    return $root
}

function Get-AllMarkdownFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string[]]$ExcludeDirectoryNames
    )

    Get-ChildItem -Path $RootPath -Recurse -File -Filter "*.md" |
        Where-Object {
            $fullNameLower = $_.FullName.ToLowerInvariant()
            foreach ($excludeName in $ExcludeDirectoryNames) {
                $excludeToken = [System.IO.Path]::DirectorySeparatorChar + $excludeName.ToLowerInvariant() + [System.IO.Path]::DirectorySeparatorChar
                if ($fullNameLower.Contains($excludeToken)) { return $false }
            }
            return $true
        }
}

Assert-CommandExists -CommandName "git"

$repositoryRootPath = Get-RepositoryRoot
Set-Location -Path $repositoryRootPath

$gitDescribe = (& git describe --tags --always --dirty 2>$null).Trim()
if (-not $gitDescribe) { $gitDescribe = "unknown" }

$gitSha = (& git rev-parse --short HEAD 2>$null).Trim()
if (-not $gitSha) { $gitSha = "unknown" }

$updatedUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")

$pattern = '(?s)<!--\s*AUTO_VERSION_BLOCK.*?AUTO_VERSION_BLOCK\s*-->'
$markdownFiles = Get-AllMarkdownFiles -RootPath $repositoryRootPath -ExcludeDirectoryNames $MarkdownExcludeDirectoryNames

foreach ($markdownFile in $markdownFiles) {
    $content = Get-Content -LiteralPath $markdownFile.FullName -Raw
    if ($content -notmatch $pattern) { continue }

    $replacement = @"
<!--
AUTO_VERSION_BLOCK
version: $gitDescribe
commit: $gitSha
updated_utc: $updatedUtc
AUTO_VERSION_BLOCK
-->
"@

    $newContent = [System.Text.RegularExpressions.Regex]::Replace($content, $pattern, $replacement)
    if ($newContent -ne $content) {
        Write-Utf8NoBomFile -FilePath $markdownFile.FullName -Content $newContent
    }
}
'@

Write-Utf8NoBomFile -FilePath $updateAutoVersionScriptPath -Content $updateAutoVersionScriptContent

# 2) Write .githooks/pre-commit
$preCommitHookPath = Join-Path -Path $hooksDirectoryPath -ChildPath "pre-commit"
$preCommitHookContent = "#!/usr/bin/env sh`nset -e`n`n# Update AUTO_VERSION_BLOCK in all markdown files that have it`npwsh -NoProfile -ExecutionPolicy Bypass -File tools/update-autoversion.ps1`n`n# Stage markdown changes only`ngit add -- `"*.md`"`n"
Write-Utf8NoBomFile -FilePath $preCommitHookPath -Content $preCommitHookContent

# 3) Configure hooks path
& git config core.hooksPath ".githooks" | Out-Null

# 4) Ensure .gitattributes forces LF for hooks
$gitAttributesPath = Join-Path -Path $repositoryRoot -ChildPath ".gitattributes"
$requiredLines = @(
    "* text=auto",
    ".githooks/* text eol=lf"
)

if (-not (Test-Path -LiteralPath $gitAttributesPath)) {
    Write-Utf8NoBomFile -FilePath $gitAttributesPath -Content (($requiredLines -join "`n") + "`n")
} else {
    $existingText = Get-Content -LiteralPath $gitAttributesPath -Raw
    $toAppend = @()
    foreach ($line in $requiredLines) {
        if (-not ($existingText -match [regex]::Escape($line))) {
            $toAppend += $line
        }
    }
    if ($toAppend.Count -gt 0) {
        $newText = $existingText.TrimEnd() + "`n" + ($toAppend -join "`n") + "`n"
        Write-Utf8NoBomFile -FilePath $gitAttributesPath -Content $newText
    }
}

# 5) Optionally add AUTO_VERSION_BLOCK to all markdown files
if ($AddAutoVersionBlockToAllMarkdownFiles) {
    $markdownFiles = Get-AllMarkdownFiles -RootPath $repositoryRoot -ExcludeDirectoryNames $MarkdownExcludeDirectoryNames
    foreach ($markdownFile in $markdownFiles) {
        [void](Add-AutoVersionBlockIfMissing -MarkdownFilePath $markdownFile.FullName)
    }
}

# 6) Update blocks now
& pwsh -NoProfile -ExecutionPolicy Bypass -File $updateAutoVersionScriptPath -RepositoryRoot $repositoryRoot | Out-Null

Write-Host ""
Write-Host "Bootstrap complete." -ForegroundColor Green
Write-Host "Configured: git config core.hooksPath .githooks"
Write-Host "Created/updated: .githooks/pre-commit"
Write-Host "Created/updated: tools/update-autoversion.ps1"
Write-Host "Created/updated: .gitattributes"
Write-Host ""
Write-Host "Next:"
Write-Host "  git status"
Write-Host "  git add -A"
Write-Host "  git commit -m `"Bootstrap hooks + autoversion (approved verbs)`""
