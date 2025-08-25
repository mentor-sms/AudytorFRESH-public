@echo off
setlocal disabledelayedexpansion
set "mode=%~1"
set "id=%~2"
set "LOG_DIR=%~3"
set "CURRENT_USER_SID=%~5"
set "log_file=%LOG_DIR%\cmd_%id%.run.lab.log"
setlocal enabledelayedexpansion
(
    echo REV 3.0.0 BAT
    echo(
    echo Rozruch: %cmdcmdline%
    echo Polecenie: "%~f0" %*
    echo(
) >> "%log_file%" 2>&1
set "ARG_INDEX=0"
set "FILE_CNT=0"
for %%A in (%*) do (
    set /a ARG_INDEX+=1
    if !ARG_INDEX! GEQ 6 (
        set /a FILE_CNT+=1
        set "FILE_!FILE_CNT!=%%~A"
    )
)
for /L %%N in (1,1,%FILE_CNT%) do (
    call set "_FP=%%FILE_%%N%%"
    >> "%log_file%" echo.
    >> "%log_file%" echo Plik: "!_FP!"

    setlocal DisableDelayedExpansion
    icacls "%_FP%" /reset >> "%log_file%" 2>&1
    set "rc=%errorlevel%"
    endlocal & set "rc=%rc%"
    if not "!rc!"=="0" exit /b 23
    if /i "%mode%"=="default" (

    ) else if /i "%mode%"=="private" (
        setlocal DisableDelayedExpansion
        icacls "%_FP%" /grant *%CURRENT_USER_SID%:F >> "%log_file%" 2>&1
        set "rc=%errorlevel%"
        endlocal & set "rc=%rc%"
        if not "!rc!"=="0" exit /b 23
        setlocal DisableDelayedExpansion
        icacls "%_FP%" /setowner *%CURRENT_USER_SID% >> "%log_file%" 2>&1
        set "rc=%errorlevel%"
        endlocal & set "rc=%rc%"
        if not "!rc!"=="0" exit /b 23
        setlocal DisableDelayedExpansion
        icacls "%_FP%" /inheritance:r /c /grant:r *%CURRENT_USER_SID%:F >> "%log_file%" 2>&1
        set "rc=%errorlevel%"
        endlocal & set "rc=%rc%"
        if not "!rc!"=="0" exit /b 23
    ) else (
        setlocal DisableDelayedExpansion
        icacls "%_FP%" /grant *S-1-5-32-544:F >> "%log_file%" 2>&1
        set "rc=%errorlevel%"
        endlocal & set "rc=%rc%"
        if not "!rc!"=="0" exit /b 23
        setlocal DisableDelayedExpansion
        icacls "%_FP%" /setowner *S-1-5-32-544 >> "%log_file%" 2>&1
        set "rc=%errorlevel%"
        endlocal & set "rc=%rc%"
        if not "!rc!"=="0" exit /b 23
        if /i "%mode%"=="root_private" (
            setlocal DisableDelayedExpansion
            icacls "%_FP%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F >> "%log_file%" 2>&1
            set "rc=%errorlevel%"
            endlocal & set "rc=%rc%"
            if not "!rc!"=="0" exit /b 23
        ) else if /i "%mode%"=="root_public" (
            setlocal DisableDelayedExpansion
            icacls "%_FP%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX >> "%log_file%" 2>&1
            set "rc=%errorlevel%"
            endlocal & set "rc=%rc%"
            if not "!rc!"=="0" exit /b 23
        )
    )
)
echo OKFIN>> "%log_file%"
exit /b 0