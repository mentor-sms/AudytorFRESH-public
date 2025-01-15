@echo off
setlocal enabledelayedexpansion

REM Validate the IP address format
set "IP=%~1"
for /f "tokens=1-4 delims=." %%a in ("%IP%") do (
    if "%%d"=="" (
        echo Error: Invalid IP address format.
        exit /b 1
    )
    for %%i in (%%a %%b %%c %%d) do (
        if %%i lss 0 if %%i gtr 255 (
            echo Error: Invalid IP address format.
            exit /b 1
        )
    )
)

set REMOTE_USER=pi
set PRIV_KEY=%USERPROFILE%\.ssh\id_repo_defaults
set REMOTE_HOST=%IP%

REM Define the ssh command
set SSH_CMD=ssh.exe -o StrictHostKeyChecking=no -o ConnectTimeout=7 -i %PRIV_KEY% %REMOTE_USER%@%REMOTE_HOST%
echo %SSH_CMD%

REM Define the base directory
set BASE_DIR=%~dp0home4copy

REM Check if the base directory exists
if not exist "%BASE_DIR%" (
    echo Error: Base directory %BASE_DIR% does not exist.
    exit /b 1
)

REM Iterate over files in the home4copy directory recursively
for /f "delims=" %%f in ('dir /b /s "%BASE_DIR%"') do (
    if exist "%%f" (
        REM Get the relative path
        set "REL_PATH=%%f"
        set "REL_PATH=!REL_PATH:%BASE_DIR%=!"
        set "REL_PATH=!REL_PATH:\=/!"

        REM Define the remote path
        set "REMOTE_PATH=/home/pi/.mentor!REL_PATH!"

        REM Create the remote directory structure
        set "REMOTE_DIR=!REMOTE_PATH:~0,-%%~nxf!"
        echo mkdir -p !REMOTE_DIR!
        %SSH_CMD% mkdir -p !REMOTE_DIR!
        if errorlevel 1 (
            echo Error: Failed to create remote directory !REMOTE_DIR!.
            goto :error
        )

        REM Transfer the file to the remote system
        echo scp -i %PRIV_KEY% "%%f" %REMOTE_USER%@%REMOTE_HOST%:!REMOTE_PATH!
        scp -i %PRIV_KEY% "%%f" %REMOTE_USER%@%REMOTE_HOST%:!REMOTE_PATH!
        if errorlevel 1 (
            echo Error: Failed to transfer file %%f to remote.
            goto :error
        )

        echo scp -i %PRIV_KEY% "%%f" %REMOTE_USER%@%REMOTE_HOST%:!REMOTE_PATH!
        scp -i %PRIV_KEY% "%%f" %REMOTE_USER%@%REMOTE_HOST%:!REMOTE_PATH!
        if errorlevel 1 (
            echo Error: Failed to transfer file %%f to remote.
            goto :error
        )
    )
)

%SSH_CMD% 

REM Report completion
echo Skonczylem.
goto :eof

:error
echo An error occurred during SSH command execution.
exit /b 1

:end
endlocal