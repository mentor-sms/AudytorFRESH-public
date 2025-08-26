@echo on
ver >nul 2>&1

set "MODE=%~1"
set "ID=%~2"
set "LOG_DIR=%~3"
set "SID=%~5"

set "log_file=%LOG_DIR%\cmd_%id%.run.lab.log"

setlocal EnableDelayedExpansion

if !errorlevel! neq 0 echo init errorlevel non-zero>> "!log_file!" & exit /b 10

(
  echo "REV3 BAT"
  echo "ID !ID!"
  echo "SID !SID!"
  echo "%cmdcmdline%"
  echo "%~f0" "%*"
  echo "MODE !MODE!"
)>> "!log_file!" 2>&1

if !errorlevel! neq 0 echo failed to write header to log>> "!log_file!" & exit /b 11

set "arg_index=0"
set "file_cnt=0"
for %%A in (%*) do (
  set /a arg_index+=1
  if !arg_index! GEQ 6 (
    set /a file_cnt+=1
    set "FILE_!file_cnt!=%%~A"
  )
  echo !file_cnt! FILE "!_FP!">> "!log_file!"
)

if !errorlevel! neq 0 echo args enumeration failed>> "!log_file!" & exit /b 12

for /L %%N in (1,1,!file_cnt!) do (
  setlocal DisableDelayedExpansion
  call set "_FP=%%FILE_%%N%%"
  endlocal & set "_FP=%_FP%"

  if !errorlevel! neq 0 echo failed to resolve file path index %%N>> "!log_file!" & exit /b 21

  echo WORK file "!_FP!">> "!log_file!"

  setlocal DisableDelayedExpansion
  icacls "%_FP%" /reset
  call set "rc=%%ERRORLEVEL%%"
  endlocal & set "rc=%rc%"

  if not "!rc!"=="0" echo icaclserr !rc!>> "!log_file!" & exit /b 22

  if /i "%MODE%"=="private" (

    setlocal DisableDelayedExpansion
    icacls "%_FP%" /grant *%SID%:F
    call set "rc=%%ERRORLEVEL%%"
    endlocal & set "rc=%rc%"
    if not "!rc!"=="0" echo icaclserr !rc!>> "!log_file!" & exit /b 23

    setlocal DisableDelayedExpansion
    icacls "%_FP%" /setowner *%SID%
    call set "rc=%%ERRORLEVEL%%"
    endlocal & set "rc=%rc%"
    if not "!rc!"=="0" echo icaclserr !rc!>> "!log_file!" & exit /b 24

    setlocal DisableDelayedExpansion
    icacls "%_FP%" /inheritance:r /c /grant:r *%SID%:F
    call set "rc=%%ERRORLEVEL%%"
    endlocal & set "rc=%rc%"
    if not "!rc!"=="0" echo icaclserr !rc!>> "!log_file!" & exit /b 25

  ) else if not /i "%MODE%"=="default" (

    setlocal DisableDelayedExpansion
    icacls "%_FP%" /grant *S-1-5-32-544:F
    call set "rc=%%ERRORLEVEL%%"
    endlocal & set "rc=%rc%"
    if not "!rc!"=="0" echo icaclserr !rc!>> "!log_file!" & exit /b 26

    setlocal DisableDelayedExpansion
    icacls "%_FP%" /setowner *S-1-5-32-544
    call set "rc=%%ERRORLEVEL%%"
    endlocal & set "rc=%rc%"
    if not "!rc!"=="0" echo icaclserr !rc!>> "!log_file!" & exit /b 27

    if /i "%MODE%"=="root_private" (

      setlocal DisableDelayedExpansion
      icacls "%_FP%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F
      call set "rc=%%ERRORLEVEL%%"
      endlocal & set "rc=%rc%"
      if not "!rc!"=="0" echo icaclserr !rc!>> "!log_file!" & exit /b 28

    ) else if /i "%MODE%"=="root_public" (

      setlocal DisableDelayedExpansion
      icacls "%_FP%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX
      call set "rc=%%ERRORLEVEL%%"
      endlocal & set "rc=%rc%"
      if not "!rc!"=="0" echo icaclserr !rc!>> "!log_file!" & exit /b 29
    )
  )

  if !errorlevel! neq 0 echo post-file processing error for "%_FP%">> "!log_file!" & exit /b 15

  echo OK file "!_FP!">> "!log_file!"
)

if !errorlevel! neq 0 (
  echo loop termination error>> "!log_file!"
  exit /b 19
)

echo OKFIN>> "!log_file!"
exit /b 0