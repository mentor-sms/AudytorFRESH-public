
@echo off
ver >nul 2>&1

REM win_chown.cmd FILE MODE=default [SID] ID=0 LOG_DIR=workdir


REM ARGC:

set "ARGC=0"
set "IS_INT="
if not "%1"=="" set "ARGC=1"
if not "%2"=="" set "ARGC=2"
if not "%3"=="" set "ARGC=3" & set "IS_INT=%~3"
if not "%4"=="" set "ARGC=4" & set "IS_INT=%~4"
if not "%5"=="" set "ARGC=5"
if not "%~6"=="" (
    echo too many arguments>&2
    exit /b 5
)

if %ARGC% LSS 2 (
    echo too few arguments>&2
    exit /b 2
)

if defined IS_INT (
  rem IS_INT
    set "r=%IS_INT%"
    set "IS_INT="
    if "%r:~0,1%"=="-" set "r=%r:~1%"
    if "%r:~0,1%"=="+" set "r=%r:~1%"
    set "nd=x"
    for /f "tokens=1 delims=0123456789" %%A in ("%r%") do set "nd=%%A"
    set "IS_INT="
    if not "%r%"=="" if "%nd%"=="x" set "IS_INT=1"
  rem IS_INT FIN
)


REM ARGS:

set "FILE=%~1"
if "%FILE%"=="" (
  echo missing FILE>&2
  exit /b 1
)

set "MODE=%~2"

if not "%3"=="" (
  if "%4"=="" (
    if defined IS_INT (
      set "ID=%~3"
    ) else (=
      set "SID=%~3"
    )
  ) else if "%5"=="" (
    if defined IS_INT (
      set "ID=%~3"
      set "LOG_DIR=%~4"
    ) else (
      set "SID=%~3"
      set "ID=%~4"
    )
  ) else (
    set "SID=%~3"
    set "ID=%~4"
    set "LOG_DIR=%~5"
  )
)


REM DEFS:

if "%ID%"=="" set "ID=0"
if "%MODE%"=="" set "MODE=default"
if "%LOG_DIR%"=="" set "LOG_DIR=%cd%"

set "log_file=%LOG_DIR%\cmd_%id%.run.lab.log"

setlocal EnableDelayedExpansion

if "!MODE!"=="private" if "!SID!"=="" (
    echo missing SID for private mode>&2
    exit /b 6
)

if !ERRORLEVEL! neq 0 (
    echo internal error>&2
    exit /b 7
)


REM WORK

echo "REV3 CMD"
echo "ID %ID%"
echo COMMAND %~f0 %*
echo CMDLINE %cmdcmdline%
echo "MODE %MODE%"

setlocal DisableDelayedExpansion

echo INBAT
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$a = @('%MODE%','%FILE%','%SID%','%log_file%'); $p = Start-Process -Verb RunAs -FilePath '%~dpn0.bat' -ArgumentList $a -PassThru; $p.WaitForExit(); exit $p.ExitCode"
echo OUTBAT
if ERRORLEVEL 70001 (
    echo wrapper failed>&2
    exit /b 91
)
if ERRORLEVEL 1224 (
    echo elevation failed>&2
    exit /b 92
) else if ERRORLEVEL 1223 (
    echo user canceled>&2
    exit /b 93
) else if ERRORLEVEL 1 (
    setlocal EnableDelayedExpansion
    set "BC=!ERRORLEVEL!"
    echo BAT err !BC!>&2
    set /a RC=BC+100
    exit /b !RC!
)
endlocal

if !ERRORLEVEL! neq 0 (
    echo internal error after elevation handling>&2
    exit /b 13
)

echo OKFIN

timeout /t 30 /nobreak >nul

if !ERRORLEVEL! neq 0 (
    echo timeout failed>&2

    exit /b 19
)

exit /b 0