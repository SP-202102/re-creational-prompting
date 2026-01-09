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

# Pre-commit cannot know the future commit hash; use current HEAD for a stable reference.
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