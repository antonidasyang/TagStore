<#
.SYNOPSIS
    Publish a TagStore release to the MinIO update bucket (Windows / PowerShell).

.DESCRIPTION
    PowerShell equivalent of publish.sh — no WSL/Git-Bash needed. Uploads the
    platform package(s), computes SHA-256, generates latest.json, and uploads
    the manifest with Cache-Control: no-cache. The "update server" is just a
    public MinIO bucket; this script writes the two static objects the app reads.

    Requires the MinIO client `mc.exe` on PATH and a one-time alias + public
    bucket (see update-server\README.md). Download mc for Windows:
        https://dl.min.io/client/mc/release/windows-amd64/mc.exe

.PARAMETER Version  Release version, e.g. 1.0.0.5 (compared against APP_VERSION).
.PARAMETER Win      Path to the Windows installer (TagStoreSetup_<ver>.exe).
.PARAMETER Mac      Path to the macOS package (optional).
.PARAMETER Linux    Path to the Linux package (optional).
.PARAMETER Notes    Release notes shown in the in-app update dialog.
.PARAMETER McAlias  mc alias name (default: d2s).
.PARAMETER Bucket   Bucket name (default: tagstore-updates).
.PARAMETER BaseUrl  Public base URL, no trailing slash
                    (default: https://oss.d2ssoft.com/tagstore-updates).

.EXAMPLE
    .\publish.ps1 -Version 1.0.0.5 `
        -Win ..\installer\TagStoreSetup_1.0.0.5.exe `
        -Notes "Improved AI tagging relevance and consolidated near-duplicate tags."
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version,
    [string]$Win,
    [string]$Mac,
    [string]$Linux,
    [string]$Notes = "",
    [string]$McAlias = $(if ($env:MC_ALIAS) { $env:MC_ALIAS } else { "d2s" }),
    [string]$Bucket  = $(if ($env:BUCKET)   { $env:BUCKET }   else { "tagstore-updates" }),
    [string]$BaseUrl = $(if ($env:BASE_URL) { $env:BASE_URL } else { "https://oss.d2ssoft.com/tagstore-updates" })
)

$ErrorActionPreference = "Stop"
$BaseUrl = $BaseUrl.TrimEnd('/')

if (-not (Get-Command mc.exe -ErrorAction SilentlyContinue) -and
    -not (Get-Command mc    -ErrorAction SilentlyContinue)) {
    throw "MinIO client 'mc.exe' not found on PATH. Download: https://dl.min.io/client/mc/release/windows-amd64/mc.exe"
}

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# Build the platforms map, uploading each package as we go.
$platforms = [ordered]@{}
function Add-Platform([string]$key, [string]$file) {
    if (-not $file) { return }
    if (-not (Test-Path $file)) { throw "$key package not found: $file" }
    $name   = Split-Path $file -Leaf
    $remote = "$McAlias/$Bucket/$Version/$name"
    Write-Step "uploading $key : $file -> $remote"
    & mc cp $file $remote
    if ($LASTEXITCODE -ne 0) { throw "mc cp failed for $file ($LASTEXITCODE)" }
    $hash = (Get-FileHash $file -Algorithm SHA256).Hash.ToLower()
    $platforms[$key] = [ordered]@{
        url    = "$BaseUrl/$Version/$name"
        sha256 = $hash
    }
}

Add-Platform "windows" $Win
Add-Platform "macos"   $Mac
Add-Platform "linux"   $Linux

if ($platforms.Count -eq 0) {
    throw "No packages given. Pass at least one of -Win / -Mac / -Linux."
}

$manifest = [ordered]@{
    version   = $Version
    pubDate   = (Get-Date -Format "yyyy-MM-dd")
    notes     = $Notes
    platforms = $platforms
}

# Serialize. ConvertTo-Json escapes the notes string for us.
$json = $manifest | ConvertTo-Json -Depth 5

Write-Step "generated manifest:"
Write-Host $json

# Write latest.json as UTF-8 *without* BOM — Qt's QJsonDocument::fromJson does
# not skip a leading BOM and would fail to parse it.
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) "tagstore-latest.json"
[System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Step "uploading manifest (Cache-Control: no-cache)"
& mc cp --attr "Cache-Control=no-cache" $tmp "$McAlias/$Bucket/latest.json"
if ($LASTEXITCODE -ne 0) { throw "mc cp failed for latest.json ($LASTEXITCODE)" }
Remove-Item $tmp -ErrorAction SilentlyContinue

Write-Host ""
Write-Step "Done. Clients will see $Version at $BaseUrl/latest.json"
