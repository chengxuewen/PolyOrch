@echo off
REM pixi-init.bat -- standard pixi bootstrap for PolyOrch-embedding hosts (Windows).
REM Three stages: install pixi (pinned, auditable) -> pixi install --manifest-path
REM (lock-regen retry) -> smoke. No cargo-mirror configuration here -- that is host
REM network policy. Best-effort until verified on a real Windows machine.
REM Usage: scripts\pixi-init.bat [path\to\pixi.toml]   (default: the repo's own)

setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "PIXI_VERSION=0.78.0"
set "PIXI_BIN=%USERPROFILE%\.pixi\bin\pixi.exe"
set "MANIFEST=%~1"
if "%MANIFEST%"=="" set "MANIFEST=%SCRIPT_DIR%..\pixi.toml"

if not exist "%MANIFEST%" (
    echo ERROR: manifest not found: %MANIFEST%
    exit /b 1
)
echo === pixi-init: manifest = %MANIFEST% (pin %PIXI_VERSION%) ===

REM ---- [1/3] locate or install pixi ----
set "PIXI="
where pixi >nul 2>&1 && set "PIXI=pixi"
if not defined PIXI if exist "%PIXI_BIN%" set "PIXI=%PIXI_BIN%"

if defined PIXI (
    for /f "tokens=2" %%v in ('"%PIXI%" --version 2^>nul') do set "HAVE=%%v"
    echo [1/3] pixi !HAVE! ready (!PIXI!)
) else (
    echo [1/3] pixi not found; installing v%PIXI_VERSION% ...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/prefix-dev/pixi/releases/download/v%PIXI_VERSION%/pixi-x86_64-pc-windows-msvc.zip' -OutFile \"$env:TEMP\pixi.zip\""
    if errorlevel 1 ( echo ERROR: pixi installer download failed & exit /b 1 )
    powershell -NoProfile -Command "Expand-Archive -Path \"$env:TEMP\pixi.zip\" -DestinationPath \"$env:USERPROFILE\.pixi\bin\" -Force"
    if errorlevel 1 ( echo ERROR: pixi installer extraction failed & exit /b 1 )
    del "%TEMP%\pixi.zip" 2>nul
    set "PIXI=%PIXI_BIN%"
)

REM ---- [2/3] resolve and install the environment ----
echo [2/3] pixi install (first solve includes downloads; may take minutes)...
"%PIXI%" install --manifest-path "%MANIFEST%"
if errorlevel 1 (
    echo       first solve failed -^> regenerate the lock and retry once
    "%PIXI%" update --manifest-path "%MANIFEST%"
    if errorlevel 1 ( echo ERROR: pixi update failed & exit /b 1 )
    "%PIXI%" install --manifest-path "%MANIFEST%"
    if errorlevel 1 ( echo ERROR: pixi install failed after lock regeneration & exit /b 1 )
)

REM ---- [3/3] smoke ----
echo [3/3] smoke: pixi --version ...
"%PIXI%" --version
if errorlevel 1 ( echo ERROR: pixi smoke failed & exit /b 1 )

echo === pixi-init done ===
echo   daily use: "%PIXI%" run ^<task^> --manifest-path "%MANIFEST%"
endlocal
