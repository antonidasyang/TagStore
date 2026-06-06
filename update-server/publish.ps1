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
    [string]$McAlias,
    [string]$Bucket,
    [string]$BaseUrl,
    # Gitignored file holding MinIO endpoint + access/secret keys.
    [string]$CredentialsFile = (Join-Path $PSScriptRoot "minio.secret.env")
)

$ErrorActionPreference = "Stop"

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# --- Load MinIO credentials/config from the (gitignored) secret file ---------
function Read-EnvFile([string]$path) {
    $map = @{}
    if (-not (Test-Path $path)) { return $map }
    foreach ($line in Get-Content -LiteralPath $path) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $i = $t.IndexOf("=")
        if ($i -lt 1) { continue }
        $k = $t.Substring(0, $i).Trim()
        $v = $t.Substring($i + 1).Trim().Trim('"').Trim("'")
        $map[$k] = $v
    }
    return $map
}

$cfg = Read-EnvFile $CredentialsFile

# Precedence: explicit -Param > secret file > env var > built-in default.
function Resolve-Setting($paramVal, $cfgKey, $envName, $default) {
    if ($paramVal) { return $paramVal }
    if ($cfg.ContainsKey($cfgKey) -and $cfg[$cfgKey]) { return $cfg[$cfgKey] }
    $e = [Environment]::GetEnvironmentVariable($envName)
    if ($e) { return $e }
    return $default
}
$McAlias = Resolve-Setting $McAlias "MINIO_ALIAS"    "MC_ALIAS" "d2s"
$Bucket  = Resolve-Setting $Bucket  "MINIO_BUCKET"   "BUCKET"   "tagstore-updates"
$BaseUrl = (Resolve-Setting $BaseUrl "MINIO_BASE_URL" "BASE_URL" "https://oss.d2ssoft.com/tagstore-updates").TrimEnd('/')

if (-not (Get-Command mc.exe -ErrorAction SilentlyContinue) -and
    -not (Get-Command mc    -ErrorAction SilentlyContinue)) {
    throw "MinIO client 'mc.exe' not found on PATH. Download: https://dl.min.io/client/mc/release/windows-amd64/mc.exe"
}

# Configure the mc alias from the secret file (keys never touch the command line).
$endpoint = $cfg["MINIO_ENDPOINT"]
$access   = $cfg["MINIO_ACCESS_KEY"]
$secret   = $cfg["MINIO_SECRET_KEY"]
if ($endpoint -and $access -and $secret) {
    Write-Step "configuring mc alias '$McAlias' -> $endpoint (from $(Split-Path $CredentialsFile -Leaf))"
    & mc alias set $McAlias $endpoint $access $secret | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "mc alias set failed ($LASTEXITCODE). Check the keys in $CredentialsFile." }
} elseif (-not (Test-Path $CredentialsFile)) {
    throw "Credentials file not found: $CredentialsFile`nCopy minio.secret.env.example to minio.secret.env and fill in your keys."
} else {
    Write-Warning "No MINIO_* keys in $CredentialsFile; assuming 'mc alias set $McAlias ...' was configured manually."
}

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
