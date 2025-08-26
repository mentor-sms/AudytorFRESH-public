@echo on
ver >nul 2>&1

set "FILE=%~1"
set "MODE=%~2"
set "SID=%~3"
set "LOG_FILE=%~4"

setlocal EnableDelayedExpansion

if !errorlevel! neq 0 echo init errorlevel non-zero>> "%LOG_FILE%" & exit /b 10

(
  echo "REV3 BAT"
  echo "ID %ID%"
  echo "SID %SID%"
  echo "%cmdcmdline%"
  echo "%~f0" "%*"
  echo "MODE %MODE%"
)>> "%LOG_FILE%" 2>&1

if !errorlevel! neq 0 echo failed to write header to log>> "%LOG_FILE%" & exit /b 11

echo WORK file "%FILE%">> "%LOG_FILE%"

icacls "%FILE%" /reset
set "rc=!ERRORLEVEL!"
if not "!rc!"=="0" echo icaclserr !rc!>> "%LOG_FILE%" & exit /b 22

if /i "%MODE%"=="private" (

  icacls "%FILE%" /grant *%SID%:F
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" echo icaclserr !rc!>> "%LOG_FILE%" & exit /b 23

  icacls "%FILE%" /setowner *%SID%
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" echo icaclserr !rc!>> "%LOG_FILE%" & exit /b 24

  icacls "%FILE%" /inheritance:r /c /grant:r *%SID%:F
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" echo icaclserr !rc!>> "%LOG_FILE%" & exit /b 25

) else if not /i "%MODE%"=="default" (

  icacls "%FILE%" /grant *S-1-5-32-544:F
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" echo icaclserr !rc!>> "%LOG_FILE%" & exit /b 26

  icacls "%FILE%" /setowner *S-1-5-32-544
  set "rc=!ERRORLEVEL!"
  if not "!rc!"=="0" echo icaclserr !rc!>> "%LOG_FILE%" & exit /b 27

  if /i "%MODE%"=="root_private" (

    icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F
    set "rc=!ERRORLEVEL!"
    if not "!rc!"=="0" echo icaclserr !rc!>> "%LOG_FILE%" & exit /b 28

  ) else if /i "%MODE%"=="root_public" (

    icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX
    set "rc=!ERRORLEVEL!"
    if not "!rc!"=="0" echo icaclserr !rc!>> "%LOG_FILE%" & exit /b 29
  )
)

if !errorlevel! neq 0 echo post-file processing error for "%FILE%">> "%LOG_FILE%" & exit /b 15

echo OK file "%FILE%">> "%LOG_FILE%"
echo OKFIN>> "%LOG_FILE%"
exit /b 0