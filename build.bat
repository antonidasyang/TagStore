@echo off
REM ===========================================================================
REM  build.bat -- one-shot Windows build of TagStore that SELF-SETS-UP the Qt6
REM  toolchain, so plain "build.bat" just works without opening Qt Creator.
REM
REM  Usage:
REM      build.bat                 configure + build, Debug, incremental
REM      build.bat release         configure + build, Release (also copies
REM                                TagStore.exe into installer\bin)
REM      build.bat debug           explicit Debug (same as no arg)
REM      build.bat clean           wipe build\ first, then a Debug build
REM      build.bat release clean   wipe build\ first, then a Release build
REM      build.bat package         Release build + windeployqt + Inno Setup
REM                                -> installer\TagStoreSetup_<ver>.exe
REM
REM  Args are order-independent: "release"/"debug" pick the config, "clean"
REM  forces a from-scratch reconfigure, "package" implies Release and runs the
REM  full installer pipeline (windeployqt with the SAME kit used to build, then
REM  ISCC). TagStore uses qt_add_qml_module (Qt6),
REM  which tracks QML + qmlcache correctly, so incremental builds are safe --
REM  "clean" is only needed after a toolchain / CMake-option change (including
REM  the FIRST run after switching kit or compiler).
REM
REM  Set BUILD_DIR to use a directory other than build\.
REM
REM  Toolchain auto-setup:
REM    * Qt kit (QT_PREFIX): an exact QT_PREFIX wins untouched (escape hatch to
REM      force a specific kit, e.g. an MSVC one). Otherwise any Qt hint
REM      (QTDIR / QT_DIR / QT_ROOT_DIR / Qt6_DIR) or a scan of the standard
REM      roots (C:\Qt, %USERPROFILE%\Qt, %USERPROFILE%\Tools\Qt) is climbed to
REM      the Qt *version* dir, and the best kit is picked, preferring MinGW
REM      (TagStore ships MinGW): llvm-mingw_64, then mingw_64, then
REM      msvc2022_64 / msvc2019_64.
REM    * compiler is chosen to MATCH the kit -- clang++ for llvm-mingw, g++ for
REM      mingw, MSVC cl (auto vcvars64) for an msvc kit -- so the kit's Qt libs
REM      always link. The matching toolchain bin is prepended to PATH.
REM    * cmake / ninja: the Qt install's bundled copies under <QtRoot>\Tools are
REM      preferred over PATH, so a stale ninja (e.g. from a conda env) can't
REM      trigger "multiple outputs aren't supported by depslog".
REM  If the kit / compiler / cmake / ninja is still missing, it says which one
REM  and where to get it, then exits -- it never runs a broken cmake.
REM
REM  ASCII-only on purpose: cmd.exe parses .bat in the system codepage, not
REM  UTF-8. No parenthesised if/else blocks and no '>' inside echo text (both
REM  upset the cmd parser); validation and errors use goto labels instead.
REM ===========================================================================

setlocal

set "ROOT=%~dp0"
if not defined BUILD_DIR set "BUILD_DIR=build"
set "BUILD_TYPE=Debug"
set "CLEAN=0"
set "PACKAGE=0"

REM --- Parse args (order-independent) ----------------------------------------
:parseargs
if "%~1"=="" goto :args_done
set "ARGOK=0"
if /I "%~1"=="release" set "BUILD_TYPE=Release"
if /I "%~1"=="release" set "ARGOK=1"
if /I "%~1"=="debug"   set "BUILD_TYPE=Debug"
if /I "%~1"=="debug"   set "ARGOK=1"
if /I "%~1"=="clean"   set "CLEAN=1"
if /I "%~1"=="clean"   set "ARGOK=1"
if /I "%~1"=="package" set "PACKAGE=1"
if /I "%~1"=="package" set "ARGOK=1"
if "%ARGOK%"=="0" goto :bad_arg
shift
goto :parseargs
:args_done
REM Packaging is always a Release build (windeployqt --release + the installer
REM expect the release Qt DLLs), so force it regardless of arg order.
if "%PACKAGE%"=="1" set "BUILD_TYPE=Release"

REM --- Resolve the Qt kit (QT_PREFIX) ----------------------------------------
REM Exact QT_PREFIX wins untouched.
if defined QT_PREFIX goto :have_prefix

REM Take the first Qt hint that is set, normalise a \lib\cmake\Qt6 suffix, then
REM climb to the version dir and pick the best kit from it.
set "QT_HINT="
if not defined QT_HINT if defined QTDIR      set "QT_HINT=%QTDIR%"
if not defined QT_HINT if defined QT_DIR      set "QT_HINT=%QT_DIR%"
if not defined QT_HINT if defined QT_ROOT_DIR set "QT_HINT=%QT_ROOT_DIR%"
if not defined QT_HINT if defined Qt6_DIR     set "QT_HINT=%Qt6_DIR%"
if defined QT_HINT set "QT_HINT=%QT_HINT:/=\%"
if defined QT_HINT set "QT_HINT=%QT_HINT:\lib\cmake\Qt6=%"
if defined QT_HINT for %%I in ("%QT_HINT%\..") do call :pick_kit "%%~fI"
if defined QT_PREFIX goto :have_prefix

REM No usable hint -- scan the standard roots (newest version wins).
echo [build] No Qt hint set; scanning C:\Qt, %USERPROFILE%\Qt, %USERPROFILE%\Tools\Qt ...
for /d %%d in ("C:\Qt\6.*")                  do call :pick_kit "%%d"
for /d %%d in ("%USERPROFILE%\Qt\6.*")        do call :pick_kit "%%d"
for /d %%d in ("%USERPROFILE%\Tools\Qt\6.*")  do call :pick_kit "%%d"
if defined QT_PREFIX goto :have_prefix
goto :no_qt

:have_prefix
set "QT_PREFIX=%QT_PREFIX:/=\%"
set "QT_PREFIX=%QT_PREFIX:\lib\cmake\Qt6=%"
if not exist "%QT_PREFIX%\lib\cmake\Qt6\Qt6Config.cmake" goto :bad_prefix
REM QT_PREFIX = ...\Qt\6.x.y\<kit>  ->  Qt root = ...\Qt  ->  ...\Qt\Tools
for %%I in ("%QT_PREFIX%\..\..") do set "QT_ROOT=%%~fI"
set "QT_TOOLS=%QT_ROOT%\Tools"
for %%K in ("%QT_PREFIX%") do set "QT_KIT=%%~nxK"
echo [build] Qt kit: %QT_PREFIX%

REM --- cmake / ninja (prefer the Qt-bundled copies over PATH) -----------------
REM A stale ninja on PATH (conda envs ship old ones) triggers
REM "multiple outputs aren't supported by depslog" on Qt's moc rules, so put
REM the Qt install's known-good cmake/ninja first.
if exist "%QT_TOOLS%\CMake_64\bin\cmake.exe" set "PATH=%QT_TOOLS%\CMake_64\bin;%PATH%"
if exist "%QT_TOOLS%\Ninja\ninja.exe"        set "PATH=%QT_TOOLS%\Ninja;%PATH%"
where cmake >nul 2>nul || goto :no_cmake
where ninja >nul 2>nul || goto :no_ninja

REM --- compiler, matched to the kit ------------------------------------------
set "MSVC=0"
set "CXX_NAME="
echo.%QT_KIT%|findstr /i "llvm-mingw" >nul && goto :cc_llvm
echo.%QT_KIT%|findstr /i "mingw"      >nul && goto :cc_mingw
echo.%QT_KIT%|findstr /i "msvc"       >nul && goto :cc_msvc
goto :cc_mingw

:cc_llvm
for /d %%d in ("%QT_TOOLS%\llvm-mingw*") do if exist "%%d\bin\clang++.exe" set "PATH=%%d\bin;%PATH%"
where clang++ >nul 2>nul || goto :no_compiler
set "CXX_NAME=clang++"
goto :have_cc

:cc_mingw
for /d %%d in ("%QT_TOOLS%\mingw*") do if exist "%%d\bin\g++.exe" set "PATH=%%d\bin;%PATH%"
where g++ >nul 2>nul || goto :no_compiler
set "CXX_NAME=g++"
goto :have_cc

:cc_msvc
call :setup_msvc
where cl >nul 2>nul || goto :no_msvc
set "MSVC=1"
goto :have_cc

:have_cc
if "%MSVC%"=="1"     echo [build] Compiler: MSVC cl
if not "%MSVC%"=="1" echo [build] Compiler: %CXX_NAME%

REM Kit bin on PATH so AUTOMOC/rcc/qmltyperegistrar and the Qt DLLs they load
REM resolve during the build.
set "PATH=%QT_PREFIX%\bin;%PATH%"

REM Only pass CMAKE_CXX_COMPILER for the MinGW/Clang kits; for MSVC, vcvars has
REM already put cl on PATH and CMake auto-detects it. (The project is CXX-only,
REM so no CMAKE_C_COMPILER is passed -- it would just warn "not used".)
set "CXX_ARG="
if not "%MSVC%"=="1" set "CXX_ARG=-DCMAKE_CXX_COMPILER=%CXX_NAME%"

pushd "%ROOT%"

REM --- optional clean --------------------------------------------------------
if not "%CLEAN%"=="1" goto :configure
if not exist "%BUILD_DIR%" goto :configure
echo [build] Cleaning %BUILD_DIR% ...
rmdir /S /Q "%BUILD_DIR%"

REM --- configure + build -----------------------------------------------------
:configure
echo.
echo ===========================================================================
echo  Building TagStore  --  %BUILD_TYPE%  (Ninja, incremental)
echo ===========================================================================
echo.
echo [build] Configuring ...
cmake -B "%BUILD_DIR%" -S . -G Ninja -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DCMAKE_PREFIX_PATH="%QT_PREFIX%" %CXX_ARG%
if errorlevel 1 goto :cfg_fail

echo [build] Compiling target TagStore ...
cmake --build "%BUILD_DIR%" --target TagStore
if errorlevel 1 goto :build_fail

popd
echo.
echo [build] Build OK -- %BUILD_TYPE%.
echo         %ROOT%%BUILD_DIR%\TagStore.exe
if /I "%BUILD_TYPE%"=="Release" echo         %ROOT%installer\bin\TagStore.exe   [release copy]
if not "%PACKAGE%"=="1" goto :all_done

REM --- packaging: windeployqt (same kit) + licenses + Inno Setup -------------
echo.
echo [build] Packaging (windeployqt + Inno Setup) ...

REM Rebuild installer\bin from scratch. Inno packs ".\bin\*.*" verbatim, and
REM nothing else here removes leftovers -- a stale or foreign-Qt DLL surviving
REM in this dir gets shipped and mismatches the freshly built exe, which is what
REM causes "entry point ... could not be located in Qt6Network.dll" on a clean
REM PC. Wiping guarantees the installer only carries this kit's consistent set.
set "BIN=%ROOT%installer\bin"
if exist "%BIN%" rmdir /S /Q "%BIN%"
mkdir "%BIN%"
copy /Y "%ROOT%%BUILD_DIR%\TagStore.exe" "%BIN%\TagStore.exe" >nul
if errorlevel 1 goto :pkg_fail

set "WINDEPLOY=%QT_PREFIX%\bin\windeployqt6.exe"
if not exist "%WINDEPLOY%" set "WINDEPLOY=%QT_PREFIX%\bin\windeployqt.exe"
if not exist "%WINDEPLOY%" goto :no_windeploy
echo [build] windeployqt: %WINDEPLOY%
"%WINDEPLOY%" --release --qmldir "%ROOT%qml" --compiler-runtime --no-translations "%BIN%\TagStore.exe"
if errorlevel 1 goto :pkg_fail

REM setup.iss shows license pages from bin\LICENSE.txt / bin\LICENSE_CN.txt.
if exist "%ROOT%installer\LICENSE.txt"    copy /Y "%ROOT%installer\LICENSE.txt"    "%BIN%\LICENSE.txt"    >nul
if exist "%ROOT%installer\LICENSE_CN.txt" copy /Y "%ROOT%installer\LICENSE_CN.txt" "%BIN%\LICENSE_CN.txt" >nul

set "ISCC="
for %%X in (ISCC.exe) do if not defined ISCC set "ISCC=%%~$PATH:X"
if not defined ISCC if defined INNO_SETUP if exist "%INNO_SETUP%\ISCC.exe" set "ISCC=%INNO_SETUP%\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles(x86)%\Inno Setup 7\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 7\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles%\Inno Setup 7\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 7\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not defined ISCC goto :no_iscc
echo [build] Inno Setup: %ISCC%
pushd "%ROOT%installer"
"%ISCC%" setup.iss
set "ISCC_RC=%errorlevel%"
popd
if not "%ISCC_RC%"=="0" goto :pkg_fail

set "VER="
for /f "usebackq delims=" %%v in ("%ROOT%version.txt") do set "VER=%%v"
echo.
echo [build] Installer ready:
echo         %ROOT%installer\TagStoreSetup_%VER%.exe
echo.
echo [build] Next, publish to the update bucket (PowerShell):
echo         .\update-server\publish.ps1 -Version %VER% -Win installer\TagStoreSetup_%VER%.exe -Notes "..."

:all_done
echo.
endlocal
exit /b 0

REM ===========================================================================
REM  Error / usage labels
REM ===========================================================================
:usage
echo.
echo Usage: build.bat [debug^|release] [clean] [package]
echo     no arg     Debug, incremental build
echo     release    Release build (also copies TagStore.exe into installer\bin)
echo     clean      wipe build\ first, then build
echo     package    Release build + windeployqt + Inno Setup installer
exit /b 1

:bad_arg
echo.
echo [build] ERROR: unknown argument "%~1". Expected debug, release, or clean.
goto :usage

:no_qt
echo.
echo [build] ERROR: no Qt6 kit found.
echo   * Set QT_PREFIX to your kit prefix to force one, e.g.
echo       set QT_PREFIX=C:\Users\you\Tools\Qt\6.11.1\mingw_64
echo   * Or set QTDIR / Qt6_DIR to a Qt kit and re-run.
echo   * Or install a Qt 6 kit under C:\Qt or %USERPROFILE%\Tools\Qt.
exit /b 1

:bad_prefix
echo.
echo [build] ERROR: "%QT_PREFIX%" is not a Qt6 kit.
echo         Expected "%QT_PREFIX%\lib\cmake\Qt6\Qt6Config.cmake" to exist.
exit /b 1

:no_cmake
echo.
echo [build] ERROR: cmake.exe not found on PATH or under "%QT_TOOLS%\CMake_64\bin".
echo   * Install the Qt "CMake" tool component via the Qt Maintenance Tool, or
echo     install CMake from https://cmake.org/download and add it to PATH.
exit /b 1

:no_ninja
echo.
echo [build] ERROR: ninja.exe not found on PATH or under "%QT_TOOLS%\Ninja".
echo   * Install the Qt "Ninja" tool component via the Qt Maintenance Tool, or
echo     add a standalone ninja to PATH.
exit /b 1

:no_compiler
echo.
echo [build] ERROR: no matching MinGW compiler found for kit "%QT_KIT%".
echo   * Expected clang++/g++ under "%QT_TOOLS%\llvm-mingw*" or "%QT_TOOLS%\mingw*",
echo     or clang++/g++ on PATH.
echo   * Install the MinGW toolchain that ships with this kit via the Qt
echo     Maintenance Tool.
exit /b 1

:no_msvc
echo.
echo [build] ERROR: the MSVC compiler cl.exe was not found for kit "%QT_KIT%".
echo   * Install Visual Studio 2019/2022 with "Desktop development with C++",
echo   * run this from a "x64 Native Tools Command Prompt for VS", or
echo   * point QT_PREFIX at a MinGW kit instead, e.g.
echo       set QT_PREFIX=%QT_ROOT%\<version>\mingw_64
exit /b 1

:cfg_fail
popd
echo.
echo [build] CMake configure FAILED. If you switched kit/compiler on an existing
echo         build, retry from scratch with:  build.bat %BUILD_TYPE% clean
exit /b 1

:build_fail
popd
echo.
echo [build] Build FAILED.
exit /b 1

:no_windeploy
echo.
echo [build] ERROR: windeployqt not found in "%QT_PREFIX%\bin".
echo         Expected windeployqt6.exe or windeployqt.exe there. The build
echo         succeeded -- only packaging was skipped.
exit /b 1

:no_iscc
echo.
echo [build] ERROR: ISCC.exe (Inno Setup 6 or 7) not found. The build + windeployqt
echo         succeeded; only the .exe packaging step was skipped.
echo   * Install Inno Setup 6/7, add ISCC.exe to PATH, or set INNO_SETUP to its
echo     folder, then re-run:  build.bat package
exit /b 1

:pkg_fail
echo.
echo [build] Packaging FAILED (build itself succeeded).
exit /b 1

REM ===========================================================================
REM  Subroutines (call-only; never fall through -- guarded by exit /b above)
REM ===========================================================================

REM pick_kit "<Qt version dir>" -- set QT_PREFIX to that version's best kit,
REM preferring llvm-mingw_64 > mingw_64 > msvc2022_64 > msvc2019_64. Called
REM repeatedly by the scan; a later (newer) version overwrites an earlier one.
:pick_kit
set "_vd=%~1"
if exist "%_vd%\llvm-mingw_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_PREFIX=%_vd%\llvm-mingw_64"
if exist "%_vd%\llvm-mingw_64\lib\cmake\Qt6\Qt6Config.cmake" goto :eof
if exist "%_vd%\mingw_64\lib\cmake\Qt6\Qt6Config.cmake"      set "QT_PREFIX=%_vd%\mingw_64"
if exist "%_vd%\mingw_64\lib\cmake\Qt6\Qt6Config.cmake"      goto :eof
if exist "%_vd%\msvc2022_64\lib\cmake\Qt6\Qt6Config.cmake"   set "QT_PREFIX=%_vd%\msvc2022_64"
if exist "%_vd%\msvc2022_64\lib\cmake\Qt6\Qt6Config.cmake"   goto :eof
if exist "%_vd%\msvc2019_64\lib\cmake\Qt6\Qt6Config.cmake"   set "QT_PREFIX=%_vd%\msvc2019_64"
goto :eof

REM setup_msvc -- put cl.exe on PATH via vcvars64.bat if it isn't already.
:setup_msvc
where cl >nul 2>nul && goto :eof
set "VCVARS="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -property installationPath`) do set "VSINSTALL=%%I"
if defined VSINSTALL if exist "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS=%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat"
if not defined VCVARS if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"    set "VCVARS=%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
if not defined VCVARS if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS=%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
if not defined VCVARS if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"   set "VCVARS=%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
if not defined VCVARS if exist "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"   set "VCVARS=%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if not defined VCVARS goto :eof
echo [build] Initializing MSVC env: "%VCVARS%"
call "%VCVARS%" >nul
goto :eof
