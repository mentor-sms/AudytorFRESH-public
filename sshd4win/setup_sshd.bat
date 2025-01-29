@echo off
setlocal enabledelayedexpansion

set "log_file=%~dp0setup_sshd.log"
echo Logging to %log_file%
> "%log_file%" 2>&1 (
    REM Check if the username argument is provided
    if "%1"=="" (
        echo Usage: %0 username
        exit /b 101
    )

    REM Set the username and home_dir based on the provided argument
    set "home_dir=%1"

    REM Define source and destination directories
    set "source_dir=%~dp0"
    set "root_dir=C:\ProgramData\ssh"

    REM Ensure the script is running with administrator privileges
    >nul 2>&1 "%SystemRoot%\system32\cacls.exe" "%SystemRoot%\system32\config\system"
    if %errorlevel% neq 0 (
        echo This script requires elevated privileges. Please run as administrator.
        exit /b 102
    )

    REM Define the list of files to process
    set files_root_only=sshd_config.txt
    set files_non_txt=id_ed25519.pub id_rsa.pub
    set files_private=id_ed25519 id_rsa

    REM Process non-txt files to be copied to root_dir with modified names
    for %%f in (%files_non_txt%) do (
        set "dest_file=%%~nf"

        if "%%f"=="dev_ed25519.pub" set "dest_file=dev_ed25519.pub"
        if "%%f"=="id_ed25519.pub" set "dest_file=ssh_host_ed25519_key.pub"
        if "%%f"=="id_rsa.pub" set "dest_file=ssh_host_rsa_key.pub"

        REM Use delayed expansion for dest_file
        set "current_dest_file=!dest_file!"

        REM Copy file to root_dir with modified name
        copy /y "%source_dir%\%%f" "%root_dir%\!current_dest_file!"
        if !errorlevel! neq 0 (
            echo Error encountered during copying %%f to %root_dir%\!current_dest_file!. Error code: !errorlevel!
            exit /b 103
        )
    )

    REM Process private files to be copied to root_dir with modified names
    for %%f in (%files_private%) do (
        set "dest_file=%%~nf"

        if "%%f"=="id_ed25519" set "dest_file=ssh_host_ed25519_key"
        if "%%f"=="id_rsa" set "dest_file=ssh_host_rsa_key"

        REM Use delayed expansion for dest_file
        set "current_dest_file=!dest_file!"

        REM Copy file to root_dir with modified name
        copy /y "%source_dir%\%%f" "%root_dir%\!current_dest_file!"
        if !errorlevel! neq 0 (
            echo Error encountered during copying %%f to %root_dir%\!current_dest_file!. Error code: !errorlevel!
            exit /b 104
        )
    )

    REM Process files to be copied only to root_dir with new names
    for %%f in (%files_root_only%) do (
        set "dest_file=%%~nf"

        if "%%f"=="sshd_config.txt" set "dest_file=sshd_config"

        REM Use delayed expansion for dest_file
        set "current_dest_file=!dest_file!"

        REM Copy file to root_dir with modified name
        copy /y "%source_dir%\%%f" "%root_dir%\!current_dest_file!"
        if %errorlevel% neq 0 (
            echo Error encountered during copying %%f to %root_dir%\!current_dest_file!. Error code: %errorlevel%
            exit /b 105
        )
    )

    echo Files copied successfully.
)
exit /b 0