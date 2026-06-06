<#
.SYNOPSIS
    Build, deploy (windeployqt + QML), and package TagStore on Windows.

.DESCRIPTION
    End-to-end Windows release pipeline:
      1. (optional) CMake configure + Release build. The Release build already
         copies TagStore.exe into installer\bin\ (see CMakeLists.txt).
      2. windeployqt6 --qmldir ..\qml   -> pulls every Qt DLL *and* the QML
         runtime/plugins into installer\bin\ so the app runs on a clean PC.
      3. (optional) Inno Setup (ISCC) -> installer\TagStoreSetup_<ver>.exe.

    The Qt install directory is read from an environment variable; no path is
    hard-coded. It checks, in order:
        QT_ROOT_DIR, QTDIR, QT_DIR, Qt6_DIR
    Point one of them at the Qt kit prefix, e.g.
        setx QTDIR C:\Qt\6.10.0\llvm-mingw_64
    (the one that contains \bin\windeployqt6.exe). If none is set, the script
    falls back to windeployqt6/windeployqt found on PATH.

.PARAMETER Configure   Run "cmake -G Ninja -DCMAKE_BUILD_TYPE=Release" first.
.PARAMETER Build       Run "cmake --build" (Release).
.PARAMETER Installer   Run Inno Setup (ISCC) to produce the setup .exe.
.PARAMETER All         Shorthand for -Configure -Build -Installer.
.PARAMETER BuildDir    Build directory (default: build).

.EXAMPLE
    # Full pipeline from a clean checkout
    .\installer\deploy-windows.ps1 -All

.EXAMPLE
    # You already built; just run windeployqt + make the installer
    .\installer\deploy-windows.ps1 -Installer
#>
[CmdletBinding()]
param(
    [switch]$Configure,
    [switch]$Build,
    [switch]$Installer,
    [switch]$All,
    [string]$BuildDir = "build"
)

$ErrorActionPreference = "Stop"

if ($All) { $Configure = $true; $Build = $true; $Installer = $true }

# --- Resolve repo paths -----------------------------------------------------
$RepoRoot  = Split-Path -Parent $PSScriptRoot          # installer\.. = repo root
$QmlDir    = Join-Path $RepoRoot "qml"
$BinDir    = Join-Path $RepoRoot "installer\bin"
$SetupIss  = Join-Path $RepoRoot "installer\setup.iss"
$Exe       = Join-Path $BinDir "TagStore.exe"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# --- Locate windeployqt -----------------------------------------------------
function Find-WinDeployQt {
    foreach ($var in 'QT_ROOT_DIR','QTDIR','QT_DIR','Qt6_DIR') {
        $root = [Environment]::GetEnvironmentVariable($var)
        if (-not $root) { continue }
        # Qt6_DIR often points at lib\cmake\Qt6; climb back to the kit prefix.
        $candidates = @(
            (Join-Path $root "bin\windeployqt6.exe"),
            (Join-Path $root "bin\windeployqt.exe"),
            (Join-Path $root "..\..\..\bin\windeployqt6.exe"),
            (Join-Path $root "..\..\..\bin\windeployqt.exe")
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { return (Resolve-Path $c).Path }
        }
    }
    foreach ($name in 'windeployqt6.exe','windeployqt.exe') {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    throw "windeployqt not found. Set QTDIR to your Qt kit prefix (e.g. C:\Qt\6.10.0\llvm-mingw_64) or add it to PATH."
}

# --- 1. Configure -----------------------------------------------------------
if ($Configure) {
    Write-Step "CMake configure (Release, Ninja)"
    Push-Location $RepoRoot
    try {
        cmake -B $BuildDir -S . -G "Ninja" -DCMAKE_BUILD_TYPE=Release
    } finally { Pop-Location }
}

# --- 2. Build ---------------------------------------------------------------
if ($Build) {
    Write-Step "CMake build (Release)"
    Push-Location $RepoRoot
    try {
        cmake --build $BuildDir --target TagStore --config Release -j
    } finally { Pop-Location }
}

if (-not (Test-Path $Exe)) {
    throw "TagStore.exe not found at $Exe. Run a Release build first (-Build), which copies it into installer\bin."
}

# --- 3. windeployqt (Qt DLLs + QML) ----------------------------------------
$WinDeployQt = Find-WinDeployQt
Write-Step "windeployqt: $WinDeployQt"
Write-Host "    target : $Exe"
Write-Host "    qmldir : $QmlDir"

# --qmldir scans the QML sources so the QML modules/plugins this app imports
# get deployed alongside the Qt DLLs. --compiler-runtime copies the C/C++
# runtime. For LLVM-MinGW kits you may also need libc++.dll / libunwind.dll /
# libwinpthread.dll from <QtKit>\bin if the app fails to start on a clean PC.
& $WinDeployQt `
    --release `
    --qmldir $QmlDir `
    --compiler-runtime `
    --no-translations `
    $Exe
if ($LASTEXITCODE -ne 0) { throw "windeployqt failed ($LASTEXITCODE)." }

# Ensure the license files Inno expects are present next to the binary.
foreach ($f in @("LICENSE","LICENSE.txt","LICENSE_CN.txt")) {
    $src = Join-Path $RepoRoot $f
    if ((Test-Path $src) -and -not (Test-Path (Join-Path $BinDir $f))) {
        Copy-Item $src $BinDir -ErrorAction SilentlyContinue
    }
}

Write-Step "Deploy complete. Standalone app is in: $BinDir"

# --- 4. Inno Setup installer ------------------------------------------------
if ($Installer) {
    function Find-ISCC {
        $cmd = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        foreach ($p in @(
            "$env:INNO_SETUP\ISCC.exe",
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe")) {
            if ($p -and (Test-Path $p)) { return $p }
        }
        throw "ISCC.exe (Inno Setup 6) not found. Install it or set INNO_SETUP to its folder."
    }
    $Iscc = Find-ISCC
    Write-Step "Inno Setup: $Iscc"
    Push-Location (Join-Path $RepoRoot "installer")
    try {
        & $Iscc $SetupIss
        if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)." }
    } finally { Pop-Location }

    $setup = Get-ChildItem (Join-Path $RepoRoot "installer") -Filter "TagStoreSetup_*.exe" |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($setup) {
        $ver = (Get-Content (Join-Path $RepoRoot "version.txt")).Trim()
        Write-Host ""
        Write-Step "Installer ready: $($setup.FullName)"
        Write-Host "Next, publish it to the MinIO update bucket (from WSL/Git-Bash):" -ForegroundColor Yellow
        Write-Host "    cd update-server" -ForegroundColor Yellow
        Write-Host "    ./publish.sh $ver --win `"$($setup.FullName)`" --notes `"...`"" -ForegroundColor Yellow
    }
}
