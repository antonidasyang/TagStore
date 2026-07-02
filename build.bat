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
REM
REM  Args are order-independent: "release"/"debug" pick the config, "clean"
REM  forces a from-scratch reconfigure. TagStore uses qt_add_qml_module (Qt6),
REM  which tracks QML + qmlcache correctly, so incremental builds are safe --
REM  "clean" is only needed after a toolchain / CMake-option change.
REM
REM  Set BUILD_DIR to use a directory other than build\.
REM
REM  Toolchain auto-setup (each: PATH first, then the Qt install's bundled copy):
REM    * Qt kit (QT_PREFIX): an explicit QT_PREFIX / QTDIR / QT_DIR /
REM      QT_ROOT_DIR / Qt6_DIR wins (a Qt6_DIR \lib\cmake\Qt6 suffix is
REM      stripped); else the newest C:\Qt\6.*\llvm-mingw_64 (then mingw_64,
REM      then the same under %USERPROFILE%\Qt) is used.
REM    * compiler: the LLVM-MinGW clang/clang++ (or MinGW g++) from
REM      <QtRoot>\Tools\llvm-mingw*\bin (or mingw*\bin) is prepended to PATH and
REM      passed explicitly, so a stray MSVC cl.exe is never picked.
REM    * cmake / ninja: PATH, then <QtRoot>\Tools\CMake_64\bin and
REM      <QtRoot>\Tools\Ninja.
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
if "%ARGOK%"=="0" goto :bad_arg
shift
goto :parseargs
:args_done

REM --- Resolve the Qt kit (QT_PREFIX) ----------------------------------------
REM Priority: explicit env wins, in this order. Then normalise a Qt6_DIR that
REM points at the CMake package dir back to the kit prefix.
if not defined QT_PREFIX if defined QTDIR      set "QT_PREFIX=%QTDIR%"
if not defined QT_PREFIX if defined QT_DIR      set "QT_PREFIX=%QT_DIR%"
if not defined QT_PREFIX if defined QT_ROOT_DIR set "QT_PREFIX=%QT_ROOT_DIR%"
if not defined QT_PREFIX if defined Qt6_DIR     set "QT_PREFIX=%Qt6_DIR%"
if defined QT_PREFIX set "QT_PREFIX=%QT_PREFIX:/=\%"
if defined QT_PREFIX set "QT_PREFIX=%QT_PREFIX:\lib\cmake\Qt6=%"
if defined QT_PREFIX goto :have_prefix

REM No env override -- scan the standard install roots. Prefer LLVM-MinGW over
REM MinGW-GCC, and the newest version (for /d yields ascending, so last wins).
echo [build] QT_PREFIX not set; scanning C:\Qt and %USERPROFILE%\Qt ...
for /d %%d in ("C:\Qt\6.*") do if exist "%%d\llvm-mingw_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_PREFIX=%%d\llvm-mingw_64"
for /d %%d in ("%USERPROFILE%\Qt\6.*") do if exist "%%d\llvm-mingw_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_PREFIX=%%d\llvm-mingw_64"
if defined QT_PREFIX goto :have_prefix
for /d %%d in ("C:\Qt\6.*") do if exist "%%d\mingw_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_PREFIX=%%d\mingw_64"
for /d %%d in ("%USERPROFILE%\Qt\6.*") do if exist "%%d\mingw_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_PREFIX=%%d\mingw_64"
if defined QT_PREFIX goto :have_prefix
goto :no_qt

:have_prefix
if not exist "%QT_PREFIX%\lib\cmake\Qt6\Qt6Config.cmake" goto :bad_prefix
REM QT_PREFIX = ...\Qt\6.x.y\<kit>  ->  Qt root = ...\Qt  ->  ...\Qt\Tools
for %%I in ("%QT_PREFIX%\..\..") do set "QT_ROOT=%%~fI"
set "QT_TOOLS=%QT_ROOT%\Tools"
echo [build] Qt kit: %QT_PREFIX%

REM --- cmake -----------------------------------------------------------------
where cmake >nul 2>nul && goto :have_cmake
if exist "%QT_TOOLS%\CMake_64\bin\cmake.exe" set "PATH=%QT_TOOLS%\CMake_64\bin;%PATH%"
where cmake >nul 2>nul && goto :have_cmake
goto :no_cmake
:have_cmake

REM --- ninja -----------------------------------------------------------------
where ninja >nul 2>nul && goto :have_ninja
if exist "%QT_TOOLS%\Ninja\ninja.exe" set "PATH=%QT_TOOLS%\Ninja;%PATH%"
where ninja >nul 2>nul && goto :have_ninja
goto :no_ninja
:have_ninja

REM --- compiler (LLVM-MinGW clang, else MinGW gcc, else whatever is on PATH) --
set "CC_NAME="
set "CXX_NAME="
set "MINGW_BIN="
for /d %%d in ("%QT_TOOLS%\llvm-mingw*") do if exist "%%d\bin\clang++.exe" set "MINGW_BIN=%%d\bin"
if defined MINGW_BIN set "CC_NAME=clang"
if defined MINGW_BIN set "CXX_NAME=clang++"
if not defined MINGW_BIN for /d %%d in ("%QT_TOOLS%\mingw*") do if exist "%%d\bin\g++.exe" set "MINGW_BIN=%%d\bin"
if not defined CXX_NAME if defined MINGW_BIN set "CC_NAME=gcc"
if not defined CXX_NAME if defined MINGW_BIN set "CXX_NAME=g++"
if defined MINGW_BIN set "PATH=%MINGW_BIN%;%PATH%"
if defined CXX_NAME goto :have_cc
where clang++ >nul 2>nul && set "CC_NAME=clang"
where clang++ >nul 2>nul && set "CXX_NAME=clang++"
if defined CXX_NAME goto :have_cc
where g++ >nul 2>nul && set "CC_NAME=gcc"
where g++ >nul 2>nul && set "CXX_NAME=g++"
if defined CXX_NAME goto :have_cc
goto :no_compiler
:have_cc
echo [build] Compiler: %CXX_NAME%

REM Put the kit's bin on PATH so AUTOMOC/rcc/qmltyperegistrar and the Qt DLLs
REM they load resolve during the build.
set "PATH=%QT_PREFIX%\bin;%PATH%"

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
cmake -B "%BUILD_DIR%" -S . -G Ninja -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DCMAKE_PREFIX_PATH="%QT_PREFIX%" -DCMAKE_C_COMPILER=%CC_NAME% -DCMAKE_CXX_COMPILER=%CXX_NAME%
if errorlevel 1 goto :cfg_fail

echo [build] Compiling target TagStore ...
cmake --build "%BUILD_DIR%" --target TagStore
if errorlevel 1 goto :build_fail

popd
echo.
echo [build] SUCCESS -- %BUILD_TYPE%. Output:
echo         %ROOT%%BUILD_DIR%\TagStore.exe
if /I "%BUILD_TYPE%"=="Release" echo         %ROOT%installer\bin\TagStore.exe   [release copy]
echo.
endlocal
exit /b 0

REM ===========================================================================
REM  Error / usage labels
REM ===========================================================================
:usage
echo.
echo Usage: build.bat [debug^|release] [clean]
echo     no arg     Debug, incremental build
echo     release    Release build (also copies TagStore.exe into installer\bin)
echo     clean      wipe build\ first, then build
exit /b 1

:bad_arg
echo.
echo [build] ERROR: unknown argument "%~1". Expected debug, release, or clean.
goto :usage

:no_qt
echo.
echo [build] ERROR: no Qt6 kit found.
echo   * Set one of QT_PREFIX / QTDIR / QT_DIR / QT_ROOT_DIR to your kit prefix,
echo     e.g.  setx QTDIR C:\Qt\6.10.0\llvm-mingw_64
echo   * Or install Qt 6 (LLVM-MinGW 64-bit kit) under C:\Qt so it can be found
echo     at C:\Qt\6.x.y\llvm-mingw_64.
exit /b 1

:bad_prefix
echo.
echo [build] ERROR: "%QT_PREFIX%" is not a Qt6 kit.
echo         Expected "%QT_PREFIX%\lib\cmake\Qt6\Qt6Config.cmake" to exist.
echo         Point QT_PREFIX/QTDIR at a kit prefix like C:\Qt\6.10.0\llvm-mingw_64.
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
echo [build] ERROR: no C++ compiler found.
echo   * Expected LLVM-MinGW (clang++) or MinGW (g++) under "%QT_TOOLS%",
echo     or clang++/g++ on PATH.
echo   * Install the matching MinGW toolchain via the Qt Maintenance Tool
echo     (it ships with the llvm-mingw_64 / mingw_64 kit).
exit /b 1

:cfg_fail
popd
echo.
echo [build] CMake configure FAILED. If you switched compiler/config on an
echo         existing build, retry with:  build.bat %BUILD_TYPE% clean
exit /b 1

:build_fail
popd
echo.
echo [build] Build FAILED.
exit /b 1
