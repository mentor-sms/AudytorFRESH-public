
REM win_chown.cmd FILE
REM win_chown.cmd FILE MODE
REM win_chown.cmd FILE MODE ID
REM win_chown.cmd FILE MODE ID LOG_DIR
REM win_chown.cmd FILE MODE SID
REM win_chown.cmd FILE MODE SID ID
REM win_chown.cmd FILE MODE SID ID LOG_DIR

@echo off

rem ------------------------------------------ CONSTS:

set "RUNDIR=%cd%"
set "CCL=%cmdcmdline%"

echo(CHOWN CMD REV3
echo(%date% %time%
echo(%RUNDIR%$ %CCL:"=%
echo(

rem ------------------------------------------ ARGC:
rem ------------------------- ARGC call:
set "MINC=1"
set "MAXC=5"
set "CONSTC=2"
rem ------------------------- ARGC body:
set "ARGC=0"
if not "%~1"=="" ( set /a ARGC+=1 & call set "arg%%ARGC%%=%~1" )
if not "%~2"=="" ( set /a ARGC+=1 & call set "arg%%ARGC%%=%~2" )
if not "%~3"=="" ( set /a ARGC+=1 & call set "arg%%ARGC%%=%~3" )
if not "%~4"=="" ( set /a ARGC+=1 & call set "arg%%ARGC%%=%~4" )
if not "%~5"=="" ( set /a ARGC+=1 & call set "arg%%ARGC%%=%~5" )
if not "%~6"=="" ( set /a ARGC+=1 & call set "arg%%ARGC%%=%~6" )
if not "%~7"=="" ( set /a ARGC+=1 & call set "arg%%ARGC%%=%~7" )
if not "%~8"=="" ( set /a ARGC+=1 & call set "arg%%ARGC%%=%~8" )
if not "%~9"=="" ( set /a ARGC+=1 & call set "arg%%ARGC%%=%~9" )
if %ARGC% GTR %CONSTC% (
  set "TEST_ARG=3"
) else (
  set "TEST_ARG=0"
)
echo(ARGC: %ARGC%
if %MAXC% LSS %ARGC% (
  echo(too many args: got %ARGC%, need %MACX% 1>&2
  exit /b %MAXC%
)
if %ARGC% LSS %MINC% (
    echo(too few args: got %ARGC%", need %MINC% 1>&2
    exit /b %MINC"
)
if 0 LSS %ARGC% echo(arg1: %arg1%
if 1 LSS %ARGC% echo(arg2: %arg2%
if 2 LSS %ARGC% echo(arg3: %arg3%
if 3 LSS %ARGC% echo(arg4: %arg4%
if 4 LSS %ARGC% echo(arg5: %arg5%
if 5 LSS %ARGC% echo(arg6: %arg6%
if 6 LSS %ARGC% echo(arg7: %arg7%
if 7 LSS %ARGC% echo(arg8: %arg8%
if 8 LSS %ARGC% echo(arg9: %arg9%
echo(
rem ------------------------- ARGC swap:
if TEST_ARG GTR 0 call set "testarg=%%arg%TEST_ARG%%%"
echo(testing %testarg%
if TEST_ARG GTR 0 if %ARGC% GTR %CONSTC% echo(%testarg%| findstr /r "^[+-]*[0-9][0-9]*$" >nul
if TEST_ARG GTR 0 set "SWAP=%errorlevel%"
set "narg1=%arg1%"
if defined SWAP if %TEST_ARG% LSS 2 if %ARGC% NEQ 1 set "narg1=%arg2%"
if defined SWAP if %TEST_ARG% LSS 3 if %ARGC% NEQ 2 set "narg2=%arg3%"
if defined SWAP if %TEST_ARG% LSS 4 if %ARGC% NEQ 3 set "narg3=%arg4%"
if defined SWAP if %TEST_ARG% LSS 5 if %ARGC% NEQ 4 set "narg4=%arg5%"
if defined SWAP if %TEST_ARG% LSS 6 if %ARGC% NEQ 5 set "narg5=%arg6%"
if defined SWAP if %TEST_ARG% LSS 7 if %ARGC% NEQ 6 set "narg6=%arg7%"
if defined SWAP if %TEST_ARG% LSS 8 if %ARGC% NEQ 7 set "narg7=%arg8%"
if defined SWAP if %TEST_ARG% LSS 9 if %ARGC% NEQ 8 set "narg8=%arg9%"
if defined SWAP set "narg9=%testarg%"
if not defined narg1 if %ARGC% NEQ 1 set "narg1=%arg1%"
if not defined narg2 if %ARGC% NEQ 2 set "narg2=%arg2%"
if not defined narg3 if %ARGC% NEQ 3 set "narg3=%arg3%"
if not defined narg4 if %ARGC% NEQ 4 set "narg4=%arg4%"
if not defined narg5 if %ARGC% NEQ 5 set "narg5=%arg5%"
if not defined narg6 if %ARGC% NEQ 6 set "narg6=%arg6%"
if not defined narg7 if %ARGC% NEQ 7 set "narg7=%arg7%"
if not defined narg8 if %ARGC% NEQ 8 set "narg8=%arg8%"
if not defined narg9 if %ARGC% NEQ 9 set "narg9=%arg9%"
echo(narg1: %narg1%
echo(narg2: %narg2%
echo(narg3: %narg3%
echo(narg4: %narg4%
echo(narg5: %narg5%
echo(narg6: %narg6%
echo(narg7: %narg7%
echo(narg8: %narg8%
echo(narg9: %narg9%
rem ------------------------------------------ ARGC end.

rem ------------------------------------------ VARS:
set "FILE=%narg1%"
set "MODE=%narg2%"
set "ID=%narg3%"
set "LOG_DIR=%narg4%"
set "SID=%narg9%"

if "%MODE%"=="" (
  set "MODE=DEFAULT"
  echo(default mode: %MODE%
) else (
  echo(mode:%!MODE%
)

if "%SID%"=="" (
  if "%MODE%"=="PRIVATE" (
    echo(missing SID for PRIVATE mode 1>&2
    exit /b 6
  )
  set "SID=S-1-5-21-0000000000-0000000000-0000000000-501"
  echo(sid: useless
) else (
  echo(sid: %SID%
)

if "%ID%"=="" set "ID=0"
if "%LOG_DIR%"=="" set "LOG_DIR=%RUNDIR%"

echo(%FILE% %MODE% %SID% %ID% %LOG_DIR%

set "log_file=%LOG_DIR%\cmd_%ID%.run.lab.log"

echo(log file: %log_file%

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