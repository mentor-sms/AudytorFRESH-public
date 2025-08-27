
REM win_chown.cmd FILE MODE=DEFAULT SID ID=0 LOG_DIR=workdir

@echo off

ver >nul 2>nul

rem ------------------------------------------ CONSTS:

set "RUNDIR=%cd%"
set "arg1=%1"
set "arg2=%2"
set "arg3=%3"
set "arg4=%4"
set "arg5=%5"
set "argx=%6"

echo(
echo(%date% %time%
echo(
echo(CHOWN CMD REV3
echo(%RUNDIR%$ %cmdcmdline%
echo(

rem ------------------------------------------ ARGC:

set "ARGC=0"
set "IS_INT="
if not "%~1"=="" ( set "ARGC=1" & echo(arg1: "%~1" )
if not "%~2"=="" ( set "ARGC=2" & echo(arg2: "%~2" )
if not "%~3"=="" ( set "ARGC=3" & set "IS_INT=%~3" & echo(arg3: "%~3" )
if not "%~4"=="" ( set "ARGC=4" & set "IS_INT=%~4" & echo(arg4: "%~4" )
if not "%~5"=="" ( set "ARGC=5" & echo(arg5: "%~5" )
if not "%6"=="" set "ARGC=6"

if 5 LSS %ARGC% (
  echo too many arguments 1>&2
  exit /b 5
)

if %ARGC% LSS 1 (
    echo too few arguments 1>&2
    exit /b 2
)

rem ------------------------------------------ ARGS:

set "r=%IS_INT%"
if defined IS_INT (
  set "IS_INT="
  echo(%r%| findstr /r /c:"^[0-9][0-9]*$" >nul 2>nul && set "IS_INT=1"
  if not defined IS_INT echo(%r%| findstr /r /c:"^[+-][0-9][0-9]*$" >nul 2>nul && set "IS_INT=1"
)

setlocal EnableDelayedExpansion
REM win_chown.cmd FILE MODE=DEFAULT SID ID=0 LOG_DIR=workdir

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
      set "LOGD=%~4"
    ) else (
      set "SID=%~3"
      set "ID=%~4"
    )
  ) else (
    set "SID=%~3"
    set "ID=%~4"
    set "LOGD=%~5"
  )
)

rem ------------------------------------------ SET:


set "FILE=%~1"
set "MODE=%~2"

if "%FILE%"=="" (
  echo missing FILE 1>&2
  exit /b 1
)

rem ------------------------------------------ FIX:

echo(
echo(CMD ARGS:

if "!MODE!"=="" (
  set "MODE=DEFAULT"
  echo(~mode: !MODE!
) else (
  echo(mode: !MODE!
)

if "!SID!"=="" (
  if "!MODE!"=="PRIVATE" (
    echo missing SID for PRIVATE mode 1>&2
    exit /b 6
  )
  set "SID=S-1-5-21-0000000000-0000000000-0000000000-501"
) else (
  echo(sid: !SID! & if not "!MODE!"=="PRIVATE" echo((useless^)
)

rem ------------------------------------------ TEST:

if "!ID!"=="" set "ID=0"
if "!LOGD!"=="" set "LOGD=!RUNDIR!"
set "log_file=!LOGD!\cmd_!ID!.run.lab.log"

setlocal DisableDelayedExpansion


echo(
echo(log: %log_file%

(
  echo(%date% %time%
  echo(CHOWN CMD REV3
  echo(%RUNDIR%$ %cmdcmdline%
  echo(
  echo(CMD ARGS:
  echo(file: %FILE%
  echo(mode: %MODE%
  echo(sid: %SID%
  echo(
)>"%log_file%"

set "RUNLINE=PowerShell -NoProfile -ExecutionPolicy Bypass -Command"
set "BARGS=$a = @('%FILE%','%MODE%', '%SID%','%log_file%')"
set "PROC=$p = Start-Process -Verb RunAs -FilePath '%~dpn0.bat' -ArgumentList $a -PassThru"
set "GO=$p.WaitForExit()"
set "EXT=exit $p.ExitCode"

(
  echo(
  echo(RUN:
  echo(%RUNLINE%
  echo(%BARGS%
  echo(%PROC%
  echo(%GO%
  echo(%EXT%
) | powershell -NoProfile -Command "$input | Tee-Object -FilePath '%log_file%' -Append"

set "RUN=%RUNLINE% %BARGS%; %PROC%; %GO%; %EXT%"

(
  echo(
  echo(ACTUAL:
  echo(%RUN%
  echo(
)>>"%log_file%"

if "%MODE%"=="DBG" exit /b 0

echo(INBAT>>"%log_file%"

call %RUN%

set "EXIT_CODE=%ERRORLEVEL%"

setlocal EnableDelayedExpansion
echo OUTBAT>>"%log_file%"

if "!EXIT_CODE!"=="70001" (
    echo wrapper failed 1>&2
    exit /b 91
if "!EXIT_CODE!"=="1224" (
    echo elevation failed 1>&2
    exit /b 92
if "!EXIT_CODE!"=="1223" (
    echo user canceled 1>&2
    exit /b 93
)
if !EXIT_CODE! neq 0 (
    echo BATERR!EXIT_CODE! 1>&2
    set /a RC=!EXIT_CODE!+100
    exit /b !RC!
)
echo(EXIT: !EXIT_CODE!>>"%log_file%"
endlocal

echo(
echo OKFIN

timeout /t 2 /nobreak >nul
echo(Waiting to be killed...
timeout /t 5 /nobreak >nul
echo Suicide
exit /b %EXIT_CODE%