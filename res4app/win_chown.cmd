
@echo off
ver >nul 2>&1

set "MODE=%~1"
set "ID=%~2"
set "LOG_DIR=%~3"
set "SID=%~5"

set "log_file=%LOG_DIR%\cmd_%id%.run.lab.log"

if errorlevel 1 (
    echo init errorlevel non-zero
    exit /b 10
)

if "%~6"=="" (
    echo missing required argument 6
    exit /b 6
)

setlocal EnableDelayedExpansion

if /i not "!MODE!"=="default" if /i not "!MODE!"=="private" if /i not "!MODE!"=="root_private" if /i not "!MODE!"=="root_public" (
    echo invalid MODE "!MODE!"
    exit /b 1
)
if "!ID!"=="" (
    echo missing ID
    exit /b 2
)
if "!LOG_DIR!"=="" (
    echo missing LOG_DIR
    exit /b 3
)
if /i "!MODE!"=="private" (
    if "!SID!"=="" (
        echo missing SID for private mode
        exit /b 5
    )
)

echo "REV3 CMD"
echo "ID !ID!"
echo "SID !SID!"
echo "%cmdcmdline%"
echo "%~f0" "%*"
echo "MODE !MODE!"

set "ARG_START_IDX=6"
set "arg_idx=0"
set "FILE_CNT=0"
set "PS_ARGS="

if !errorlevel! neq 0 (
    echo internal error before args loop
    exit /b 11
)

for %%A in (%*) do (

    set /a arg_idx+=1

    setlocal DisableDelayedExpansion
    set "curr_arg=%%~A"
    endlocal & set "curr_arg=%curr_arg%"

    echo !arg_idx! FILE "!curr_arg!"

    set "CUR_ESC=!curr_arg:'='''!"

    if defined PS_ARGS (
        set "PS_ARGS=!PS_ARGS!,'!CUR_ESC!'"
    ) else (
        set "PS_ARGS='!CUR_ESC!'"
    )

    if !arg_idx! geq !ARG_START_IDX! (
        set /a FILE_CNT+=1
        set "FILE_!FILE_CNT!=!curr_arg!"

        if "!curr_arg!"=="" (
            echo empty path argument
            exit /b 21
        )
        if not exist "!curr_arg!" (
            echo path does not exist: "!curr_arg!"
            exit /b 22
        )

        icacls "!curr_arg!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo icacls test failed for "!curr_arg!"
            exit /b 23
        )

        dir "!curr_arg!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo dir test failed for "!curr_arg!"
            exit /b 24
        )
    )
)

if !errorlevel! neq 0 (
    echo internal error after args loop
    exit /b 12
)

setlocal DisableDelayedExpansion
echo INBAT
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$a = @(%PS_ARGS%); $p = Start-Process -Verb RunAs -FilePath '%~dpn0.bat' -ArgumentList $a -PassThru; $p.WaitForExit(); exit $p.ExitCode"
echo OUTBAT
if errorlevel 70001 (
    echo wrapper failed
    exit /b 91
)
if errorlevel 1224 (
    echo elevation failed
    exit /b 92
) else if errorlevel 1223 (
    echo user canceled
    exit /b 93
) else if errorlevel 1 (
    setlocal EnableDelayedExpansion
    set "BC=!errorlevel!"
    echo BAT err !BC!
    set /a RC=BC+100
    exit /b !RC!
)
endlocal

if !errorlevel! neq 0 (
    echo internal error after elevation handling
    exit /b 13
)

echo OKFIN

timeout /t 30 /nobreak >nul

if !errorlevel! neq 0 (
    echo timeout failed
    exit /b 19
)

exit /b 0