@echo off
ver >nul 2>&1

set "FILE=%~1"
set "MODE=%~2"
set "SID=%~3"
set "LOG_FILE=%~4"

setlocal EnableDelayedExpansion

echo REV3 BAT [%date% %time%]

if !errorlevel! neq 0 exit /b 10

(
  echo win_chown.cmd -> win_chown.bat
  echo(
  if "%MODE%"=="PRIVATE" (
    echo %MODE% (%SID%):
  ) else (
    echo %MODE%:
  )
  echo %FILE%
  echo(
  echo RUN:
  echo %cmdcmdline%
  echo(
)>"%LOG_FILE%"

if !errorlevel! neq 0 exit /b 11

echo(>>"%LOG_FILE%"
echo /RESET: >>"%LOG_FILE%"
icacls "%FILE%" /reset >>"%LOG_FILE%" 2>&1
set "rc=!ERRORLEVEL!"
if not "!rc!"=="0" exit /b 22

if "%MODE%"=="PRIVATE" (
  echo(>>"%LOG_FILE%"
  echo /PREPARE: >>"%LOG_FILE%"
  icacls "%FILE%" /grant *%SID%:F >>"%LOG_FILE%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 23

  echo(>>"%LOG_FILE%"
  echo /YOU (OWN): >>"%LOG_FILE%"
  icacls "%FILE%" /setowner *%SID% >>"%LOG_FILE%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 24

  echo(>>"%LOG_FILE%"
  echo /YOU (RW): >>"%LOG_FILE%"
  icacls "%FILE%" /inheritance:r /c /grant:r *%SID%:F >>"%LOG_FILE%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 25

) else if not "%MODE%"=="DEFAULT" (

  echo(>>"%LOG_FILE%"
  echo /PREPARE: >>"%LOG_FILE%"
  icacls "%FILE%" /grant *S-1-5-32-544:F >>"%LOG_FILE%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 26

  echo(>>"%LOG_FILE%"
  echo /ADMINS (OWN): >>"%LOG_FILE%"
  icacls "%FILE%" /setowner *S-1-5-32-544 >>"%LOG_FILE%" 2>&1
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" exit /b 27

  if "%MODE%"=="ROOT" (

    echo(>>"%LOG_FILE%"
    echo /ADMINS AND SYSTEM (RW): >>"%LOG_FILE%"
    icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F >>"%LOG_FILE%" 2>&1
    set "rc=!ERRORLEVEL!"
    if not "!rc!"=="0" exit /b 28

  ) else if "%MODE%"=="PROTECTED" (

    echo(>>"%LOG_FILE%"
    echo /LOCALS AND AUTHS (RO): >>"%LOG_FILE%"
    icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX >>"%LOG_FILE%" 2>&1
    set "rc=!ERRORLEVEL!"
    if not "!rc!"=="0" exit /b 29
  )
  else (
    exit /b 1
  )
)

echo DONE >>"%LOG_FILE%"

if !errorlevel! neq 0 exit /b 19

echo(>>"%LOG_FILE%"
echo OKFIN >>"%LOG_FILE%"
exit /b 0