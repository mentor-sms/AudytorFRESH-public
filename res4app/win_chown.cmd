
REM win_chown.cmd FILE MODE=DEFAULT SID ID=0 LOG_DIR=workdir

@echo off

ver >nul 2>nul

rem ------------------------------------------ CONSTS:

set "RUNDIR=%cd%"
set "CCL=%cmdcmdline%"

set "FILE=%~1"

echo(CHOWN CMD REV3
echo(%date% %time%
echo(%RUNDIR%$ %CCL:"=%
echo(

if "%FILE%"=="" (
  echo(missing FILE 1>&2
  exit /b 1
)

rem ------------------------------------------ ARGC:

set "ARGC=1"
set "IS_INT="
if not "%~2"=="" ( set "ARGC=2" & echo(arg2: "%~2" )
if not "%~3"=="" ( set "ARGC=3" & set "IS_INT=%~3" & echo(arg3: "%~3" )
if not "%~4"=="" ( set "ARGC=4" & set "IS_INT=%~4" & echo(arg4: "%~4" )
if not "%~5"=="" ( set "ARGC=5" & echo(arg5: "%~5" )
if not "%6"=="" set "ARGC=6"

if 5 LSS %ARGC% (
  echo(too many arguments 1>&2
  exit /b 5
)

if %ARGC% LSS 1 (
    echo(too few arguments 1>&2
    exit /b 2
)

echo(ARGC: %ARGC%

rem ------------------------------------------ ARGS:

set "r=%IS_INT%"
if defined IS_INT (
  set "IS_INT="
  echo(%r%| findstr /r /c:"^[0-9][0-9]*$" >nul 2>nul && set "IS_INT=1"
  if not defined IS_INT echo(%r%| findstr /r /c:"^[+-][0-9][0-9]*$" >nul 2>nul && set "IS_INT=1"
)

rem ------------------------------------------ SET:

set "arg2=%2"
set "arg3=%3"
set "arg4=%4"
set "arg5=%5"

rem --------------------------------------------------- EXPANSION!
setlocal EnableDelayedExpansion

set "MODE=!arg2!"

if not !arg3!=="" (
  if !arg4!=="" (
    if defined IS_INT (
      set "ID=!arg3!"
    ) else (
      set "SID=!arg3!"
    )
  ) else if !arg5!=="" (
    if defined IS_INT (
      set "ID=!arg3!"
      set "LOG_DIR=!arg4!"
    ) else (
      set "SID=!arg3!"
      set "ID=!arg4!"
    )
  ) else (
    set "SID=!arg3!"
    set "ID=!arg4!"
    set "LOG_DIR=!arg5!"
  )
)

rem ------------------------------------------ FIX:

if "!MODE!"=="" (
  set "MODE=DEFAULT"
  echo(default mode: !MODE!
) else (
  echo(mode: !MODE!
)

if "!SID!"=="" (
  if "!MODE!"=="PRIVATE" (
    echo(missing SID for PRIVATE mode 1>&2
    exit /b 6
  )
  set "SID=S-1-5-21-0000000000-0000000000-0000000000-501"
  echo(sid: useless
) else (
  echo(sid: !SID!
)

rem ------------------------------------------ LOG:

if "!ID!"=="" set "ID=0"
if "!LOG_DIR!"=="" set "LOG_DIR=!RUNDIR!"
set "log_file=!LOG_DIR!\cmd_!ID!.run.lab.log"

rem --------------------------------------------------- /EXPANSION OFF:
setlocal DisableDelayedExpansion

rem ------------------------------------------ SETUP:

set "RUNLINE=PowerShell -NoProfile -ExecutionPolicy Bypass -Command"
set "BARGS=$a = @('%FILE%', '%MODE%', '%log_file%', '%SID%')"
set "PROC=$p = Start-Process -Verb RunAs -FilePath '%~dpn0.bat' -ArgumentList $a -PassThru"
set "GO=$p.WaitForExit()"
set "EXT=exit $p.ExitCode"

echo(RUN:
echo(%RUNLINE%
echo(%BARGS%
echo(%PROC%
echo(%GO%
echo(%EXT%

set "RUN=%RUNLINE% %BARGS%; %PROC%; %GO%; %EXT%"

echo(ACTUAL:
echo(%RUN%

echo(INBAT

rem ------------------------------------------ RUN:

if errorlevel 1 exit /b 666

if "%MODE%"=="DBG" exit /b 0

call %RUN%

set "EXIT_CODE=%errorlevel%"

rem --------------------------------------------------- EXPANSION!
setlocal EnableDelayedExpansion

rem ------------------------------------------ OUTPUT:

echo(OUTBAT
echo(EXIT: !EXIT_CODE!

if "!EXIT_CODE!"=="70001" (
    echo(wrapper failed 1>&2
    exit /b 91
) else if "!EXIT_CODE!"=="1224" (
    echo(elevation failed 1>&2
    exit /b 92
) else if "!EXIT_CODE!"=="1223" (
    echo(user canceled 1>&2
    exit /b 93
) else if !EXIT_CODE! neq 0 (
    echo(BATERR!EXIT_CODE! 1>&2
    set /a RC=!EXIT_CODE!+100
    exit /b !RC!
)

rem --------------------------------------------------- /EXPANSION OFF:
setlocal DisableDelayedExpansion

rem ------------------------------------------ FIN:

echo(
echo(
echo(LOG:
type !log_file!

timeout /t 2 /nobreak >nul
echo(Waiting to be killed...
timeout /t 5 /nobreak >nul

echo(Suicide: %EXIT_CODE%
exit /b %EXIT_CODE%