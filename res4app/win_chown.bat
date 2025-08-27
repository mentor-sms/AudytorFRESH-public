
@echo off

REM win_chown.bat FILE MODE LOG_FILE SID

ver >nul 2>nul

set "FILE=%~1"
set "MODE=%~2"
set "LOGF=%~3"
set "SID=%~4"

if not "%~1"=="" ( set "ARGC=1" )
if not "%~2"=="" ( set "ARGC=2" )
if not "%~3"=="" ( set "ARGC=3" )
if not "%~4"=="" ( set "ARGC=4" )
if not "%5"=="" set "ARGC=5"

if 4 LSS %ARGC% (
  echo too many arguments 1>&2
  exit /b 5
)

if %ARGC% LSS 3 (
    echo too few arguments 1>&2
    exit /b 2
)

(
echo(%date% %time%
echo(CHOWN BAT REV3
echo(%cd% %cmdcmdline%
echo(
  echo win_chown.bat <- win_chown.cmd
  echo(
  if "%MODE%"=="PRIVATE" (
    echo %MODE% (%SID%)
  ) else (
    echo %MODE%
  )
  echo %FILE%
  echo(
  echo RUN:
  echo %cmdcmdline%
  echo(
)>"%LOGF%"

echo(>>"%LOGF%"
echo /RESET: >>"%LOGF%"
icacls "%FILE%" /reset >>"%LOGF%" 2>&1
set "rc=!ERRORLEVEL!"
if not "!rc!"=="0" exit /b 22

if "%MODE%"=="PRIVATE" (
  echo(>>"%LOGF%"
  echo /PREPARE: >>"%LOGF%"
  icacls "%FILE%" /grant *%SID%:F >>"%LOGF%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 23

  echo(>>"%LOGF%"
  echo /YOU (OWN): >>"%LOGF%"
  icacls "%FILE%" /setowner *%SID% >>"%LOGF%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 24

  echo(>>"%LOGF%"
  echo /YOU (RW): >>"%LOGF%"
  icacls "%FILE%" /inheritance:r /c /grant:r *%SID%:F >>"%LOGF%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 25

) else if not "%MODE%"=="DEFAULT" (

  echo(>>"%LOGF%"
  echo /PREPARE: >>"%LOGF%"
  icacls "%FILE%" /grant *S-1-5-32-544:F >>"%LOGF%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 26

  echo(>>"%LOGF%"
  echo /ADMINS (OWN): >>"%LOGF%"
  icacls "%FILE%" /setowner *S-1-5-32-544 >>"%LOGF%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 27

  if "%MODE%"=="ROOT" (

    echo(>>"%LOGF%"
    echo /ADMINS AND SYSTEM (RW): >>"%LOGF%"
    icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F >>"%LOGF%" 2>&1
    set "rc=!ERRORLEVEL!"
    if not "!rc!"=="0" exit /b 28

  ) else if "%MODE%"=="PROTECTED" (

    echo(>>"%LOGF%"
    echo /LOCALS AND AUTHS (RO): >>"%LOGF%"
    icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX >>"%LOGF%" 2>&1
    set "rc=!ERRORLEVEL!"
    if not "!rc!"=="0" exit /b 29
  )
  else (
    exit /b 1
  )
)

echo DONE >>"%LOGF%"

if !errorlevel! neq 0 exit /b 19

echo(>>"%LOGF%"
echo OKFIN >>"%LOGF%"
exit /b 0