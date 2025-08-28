
@echo on

rem win_chown.bat FILE MODE LOG_FILE SID

ver >nul 2>nul

set "RUNDIR=%cd%"
set "CCL=%cmdcmdline%"

set "FILE=%1"
set "MODE=%2"
set "LOG_FILE=%3"

if "%FILE%"=="" exit /b 1

if "%MODE%"=="" exit /b 2

if "%LOG_FILE%"=="" exit /b 3

set "ARGC=3"
if not "%~4"=="" ( set "ARGC=4" & set "GOT=%~4" )
if not "%5"=="" set "ARGC=5"

if 4 LSS %ARGC% (
  echo(too many arguments 1>&2
  exit /b 5
)

if %ARGC% LSS 3 (
    echo(too few arguments 1>&2
    exit /b 2
)

echo(ARGC: %ARGC%

rem --------------------------------------------------- EXPANSION!

echo(RESET:>>"%LOGF%"
icacls "%FILE%" /reset
set "rc=%ERRORLEVEL%"
setlocal EnableDelayedExpansion
if not "!rc!"=="0" exit /b 22
endlocal

if "%MODE%"=="PRIVATE" (

  echo(PREPARE: >>"%LOGF%"
  icacls "%FILE%" /grant *%SID%:F

  set "rc=%ERRORLEVEL%"
  setlocal EnableDelayedExpansion
  if not "!rc!"=="0" exit /b 22
  endlocal


  echo(YOU (OWN): >>"%LOGF%"
  icacls "%FILE%" /setowner *%SID%

  set "rc=%ERRORLEVEL%"
  setlocal EnableDelayedExpansion
  if not "!rc!"=="0" exit /b 22
  endlocal


  echo(YOU (RW): >>"%LOGF%"
  icacls "%FILE%" /inheritance:r /c /grant:r *%SID%:F

  set "rc=%ERRORLEVEL%"
  setlocal EnableDelayedExpansion
  if not "!rc!"=="0" exit /b 22
  endlocal

) else if not "%MODE%"=="DEFAULT" (

  echo(PREPARE: >>"%LOGF%"
  icacls "%FILE%" /grant *S-1-5-32-544:F

  set "rc=%ERRORLEVEL%"
  setlocal EnableDelayedExpansion
  if not "!rc!"=="0" exit /b 22
  endlocal


  echo(ADMINS (OWN): >>"%LOGF%"
  icacls "%FILE%" /setowner *S-1-5-32-544

  set "rc=%ERRORLEVEL%"
  setlocal EnableDelayedExpansion
  if not "!rc!"=="0" exit /b 22
  endlocal


  if "%MODE%"=="ROOT" (

    echo(ADMINS AND SYSTEM (RW):>>"%LOGF%"
    icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F

    set "rc=%ERRORLEVEL%"
    setlocal EnableDelayedExpansion
    if not "!rc!"=="0" exit /b 22
  endlocal
  ) else if "%MODE%"=="PROTECTED" (

    echo(LOCALS AND AUTHS (RO):>>"%LOGF%"
    icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX

    set "rc=%ERRORLEVEL%"
    setlocal EnableDelayedExpansion
    if not "!rc!"=="0" exit /b 22
    endlocal

  )
  else (
    exit /b 10
  )
)

echo(DONE>>"%LOGF%"
echo(>>"%LOGF%"
echo(OKFIN>>"%LOGF%"
exit /b 0