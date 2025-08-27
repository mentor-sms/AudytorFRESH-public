
@echo off
ver >nul 2>nul

REM win_chown.cmd FILE MODE=DEFAULT SID ID=0 LOG_DIR=workdir

echo REV3 CMD
echo CMDLINE %cmdcmdline%
echo RUNDIR %cd%


REM ARGC:

set "ARGC=0"
set "IS_INT="
if not "%1"=="" set "ARGC=1"
if not "%2"=="" set "ARGC=2"
if not "%3"=="" set "ARGC=3" & set "IS_INT=%~3"
if not "%4"=="" set "ARGC=4" & set "IS_INT=%~4"
if not "%5"=="" set "ARGC=5"
if not "%~6"=="" (
    echo too many arguments 1>&2
    exit /b 5
)

if %ARGC% LSS 2 (
    echo too few arguments 1>&2
    exit /b 2
)

if defined IS_INT (
  set "r=%IS_INT%"
  set "IS_INT="
  echo(%r%| findstr /r /c:"^[0-9][0-9]*$" >nul 2>nul && set "IS_INT=1"
  if not defined IS_INT echo(%r%| findstr /r /c:"^[+-][0-9][0-9]*$" >nul 2>nul && set "IS_INT=1"
)


REM ARGS:

set "FILE=%~1"
if "%FILE%"=="" (
  echo missing FILE 1>&2
  exit /b 1
)

set "MODE=%~2"

if not "%3"=="" (
  if "%4"=="" (
    if defined IS_INT (
      set "ID=%~3"
    ) else (
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
if "%MODE%"=="" set "MODE=DEFAULT"
if "%LOG_DIR%"=="" set "LOG_DIR=%cd%"

set "log_file=%LOG_DIR%\cmd_%id%.run.lab.log"

if "%SID%"=="" (
  if "%MODE%"=="PRIVATE" (
    echo missing SID for PRIVATE mode 1>&2
    exit /b 6
  )
  set "SID=S-1-5-21-0000000000-0000000000-0000000000-501"
)

setlocal EnableDelayedExpansion

if !ERRORLEVEL! neq 0 (
    echo internal error 1>&2
    exit /b 7
)


REM WORK

echo ID %ID%
echo MODE %MODE%
echo SID %SID%

setlocal DisableDelayedExpansion

echo INBAT
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$a = @('%FILE%','%MODE%', '%SID%','%log_file%'); $p = Start-Process -Verb RunAs -FilePath '%~dpn0.bat' -ArgumentList $a -PassThru; $p.WaitForExit(); exit $p.ExitCode"
echo OUTBAT
set "BC=%ERRORLEVEL%"
if %BC%==ERRORLEVEL 70001 (
    echo wrapper failed 1>&2
    exit /b 91
)
if %BC%==1224 (
    echo elevation failed 1>&2
    exit /b 92
) else if %BC%==ERRORLEVEL 1223 (
    echo user canceled 1>&2
    exit /b 93
) else if %BC%==ERRORLEVEL 1 (
    setlocal EnableDelayedExpansion
    echo BAT err !BC! 1>&2
    set /a RC=BC+100
    exit /b !RC!
)
endlocal

if !ERRORLEVEL! neq 0 (
    echo internal error after elevation handling 1>&2
    exit /b 13
)

echo OKFIN
echo "
timeout /t 5 /nobreak >nul

if !ERRORLEVEL! neq 0 (
    echo timeout failed 1>&2

    echo See this? OK, no error!

    exit /b 19
)

exit /b 0