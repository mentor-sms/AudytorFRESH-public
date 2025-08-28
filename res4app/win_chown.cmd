
REM win_chown.cmd FILE
REM win_chown.cmd FILE MODE
REM win_chown.cmd FILE MODE ID
REM win_chown.cmd FILE MODE ID LOG_DIR
REM win_chown.cmd FILE MODE SID
REM win_chown.cmd FILE MODE SID ID
REM win_chown.cmd FILE MODE SID ID LOG_DIR

@echo off

ver >nul 2>nul

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
if not "%~1"=="" set /a ARGC+=1
if not "%~2"=="" set /a ARGC+=1
if not "%~3"=="" set /a ARGC+=1
if not "%~4"=="" set /a ARGC+=1
if not "%~5"=="" set /a ARGC+=1
if not "%~6"=="" set /a ARGC+=1
if not "%~7"=="" set /a ARGC+=1
if not "%~8"=="" set /a ARGC+=1
if not "%~9"=="" set /a ARGC+=1
if %ARGC% GTR %CONSTC% (
  set "TEST_ARG=3"
) else (
  set "TEST_ARG=0"
)
echo(ARGC: %ARGC%
if %MAXC% LSS %ARGC% (
  echo(too many args: got %ARGC%, need %MACX% 1>&2
  exit /b 1
)
if %ARGC% LSS %MINC% (
  echo(too few args: got %ARGC%", need %MINC% 1>&2
  exit /b 1
)
if 0 LSS %ARGC% echo(arg1: %~1
if 1 LSS %ARGC% echo(arg2: %~2
if 2 LSS %ARGC% echo(arg3: %~3
if 3 LSS %ARGC% echo(arg4: %~4
if 4 LSS %ARGC% echo(arg5: %~5
if 5 LSS %ARGC% echo(arg6: %~6
if 6 LSS %ARGC% echo(arg7: %~7
if 7 LSS %ARGC% echo(arg8: %~8
if 8 LSS %ARGC% echo(arg9: %~9
echo(
rem ------------------------- ARGC swap:
if %TEST_ARG% GTR 0 call set "testarg=%%~%TEST_ARG%"
echo(testing %testarg%
if TEST_ARG GTR 0 if %ARGC% GTR %CONSTC% echo(%testarg%| findstr /r "^[+-]*[0-9][0-9]*$" >nul
if TEST_ARG GTR 0 set "SWAP=%errorlevel%"
set "arg1=%~1"
if defined SWAP if %TEST_ARG% LSS 2 if %ARGC% NEQ 1 set "arg1=%~2"
if defined SWAP if %TEST_ARG% LSS 3 if %ARGC% NEQ 2 set "arg2=%~3"
if defined SWAP if %TEST_ARG% LSS 4 if %ARGC% NEQ 3 set "arg3=%~4"
if defined SWAP if %TEST_ARG% LSS 5 if %ARGC% NEQ 4 set "arg4=%~5"
if defined SWAP if %TEST_ARG% LSS 6 if %ARGC% NEQ 5 set "arg5=%~6"
if defined SWAP if %TEST_ARG% LSS 7 if %ARGC% NEQ 6 set "arg6=%~7"
if defined SWAP if %TEST_ARG% LSS 8 if %ARGC% NEQ 7 set "arg7=%~8"
if defined SWAP if %TEST_ARG% LSS 9 if %ARGC% NEQ 8 set "arg8=%~9"
if defined SWAP set "arg9=%testarg%"
if not defined arg1 if %ARGC% NEQ 1 set "arg1=%~1"
if not defined arg2 if %ARGC% NEQ 2 set "arg2=%~2"
if not defined arg3 if %ARGC% NEQ 3 set "arg3=%~3"
if not defined arg4 if %ARGC% NEQ 4 set "arg4=%~4"
if not defined arg5 if %ARGC% NEQ 5 set "arg5=%~5"
if not defined arg6 if %ARGC% NEQ 6 set "arg6=%~6"
if not defined arg7 if %ARGC% NEQ 7 set "arg7=%~7"
if not defined arg8 if %ARGC% NEQ 8 set "arg8=%~8"
if not defined arg9 if %ARGC% NEQ 9 set "arg9=%~9"
echo(arg1: %arg1%
echo(arg2: %arg2%
echo(arg3: %arg3%
echo(arg4: %arg4%
echo(arg5: %arg5%
echo(arg6: %arg6%
echo(arg7: %arg7%
echo(arg8: %arg8%
echo(arg9: %arg9%
rem ------------------------------------------ ARGC end.

rem ------------------------------------------ VARS:
set "FILE=%arg1%"
echo(file: %FILE%
if "%FILE%"=="" (
  echo(missing FILE arg 1>&2
  exit /b 1
)
if not exist "%FILE%" (
  echo(file not found on disk: %FILE% 1>&2
  exit /b 1
)
if exist "%FILE%\NUL" (
  echo(path is a directory, not a file: %FILE% 1>&2
  exit /b 1
)

set "MODE=%arg2%"
if "%MODE%"=="" (
  set "MODE=DEFAULT"
  echo(default mode: %MODE%
) else (
  echo(mode:%MODE%
)
if /I not "%MODE%"=="PRIVATE" if /I not "%MODE%"=="PROTECTED" if /I not "%MODE%"=="ROOT" if /I not "%MODE%"=="DEFAULT" (echo(unknown mode %MODE% & exit /b 1)

set "SID=%arg9%"
if "%SID%"=="" (
  if "%MODE%"=="PRIVATE" (
    echo(missing SID for PRIVATE mode 1>&2
    exit /b 1
  )
  set "SID=S-1-5-21-0000000000-0000000000-0000000000-501"
  echo(sid: useless
) else (
  echo(sid: %SID%
)

set "ID=%arg3%"
if "%ID%"=="" set "ID=0"
echo(%testarg%| findstr /r "^[+-]*[0-9][0-9]*$" >nul
if errorlevel 1 (
  echo ID is invalid 1>&2
  exit /b 1
)

set "LOG_DIR=%arg4%"
if "%LOG_DIR%"=="" set "LOG_DIR=%RUNDIR%"
set "log_file=%LOG_DIR%\cmd_%ID%.run.lab.log"
echo(log file: %log_file%

(echo(INIT %date% %time% > "%LOG_FILE%") || (echo(failed to write to log file: %LOG_FILE% 1>&2 & exit /b 1)

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

if "%MODE%"=="DBG" exit /b 0

call %RUN%

set "EXIT_CODE=%errorlevel%"

rem ------------------------------------------ OUTPUT:

echo(OUTBAT
echo(EXIT: %EXIT_CODE%

if "%EXIT_CODE%"=="70001" (
    echo(wrapper failed 1>&2
    exit /b 91
) else if "%EXIT_CODE%"=="1224" (
    echo(elevation failed 1>&2
    exit /b 92
) else if "%EXIT_CODE%"=="1223" (
    echo(user canceled 1>&2
    exit /b 93
) else if %EXIT_CODE% neq 0 (
    echo(BATERR%EXIT_CODE% 1>&2
    set /a RC=%EXIT_CODE%+100
    exit /b %RC%
)


rem ------------------------------------------ FIN:

echo(
echo(
echo(LOG:
type %log_file%

timeout /t 2 /nobreak >nul
echo(Waiting to be killed...
timeout /t 5 /nobreak >nul

echo(Suicide
exit /b 0