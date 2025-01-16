@echo off
setlocal enabledelayedexpansion

REM Check if the username argument is provided
if "%1"=="" (
    echo Usage: %0 username
    exit /b 101
)

REM Set the username and home_dir based on the provided argument
set "home_dir=%1\.ssh"

REM Define source and destination directories
set "source_dir=%~dp0"
set "root_dir=C:\ProgramData\ssh"

echo SSH directory: %root_dir%
echo Source directory: %source_dir%
echo Home directory: %home_dir%

REM Ensure the script is running with administrator privileges
>nul 2>&1 "%SystemRoot%\system32\cacls.exe" "%SystemRoot%\system32\config\system"
if errorlevel 1 (
    echo This script requires elevated privileges. Please run as administrator.
    exit /b 102
)

REM Define the list of files to process
set files_home=known_hosts.txt config.txt
set files_non_txt=id_ed25519.pub id_rsa.pub
set files_private=id_ed25519 id_rsa
set files_root_only=ssh_config.txt

REM Process files to be copied to both home_dir and root_dir with new names
for %%f in (%files_home%) do (
    set "dest_file=%%~nf"

    if "%%f"=="known_hosts.txt" set "dest_file=known_hosts"

    REM Use delayed expansion for dest_file
    set "current_dest_file=!dest_file!"

    REM Copy file to home_dir
    xcopy /y "%source_dir%\%%f" "%home_dir%\!current_dest_file!" >nul
)

REM Process non-txt files to be copied to home_dir with original names
for %%f in (%files_non_txt%) do (
    REM Copy file to home_dir with original name
    xcopy /y "%source_dir%\%%f" "%home_dir%\%%f" >nul
)

REM Process private files to be copied to home_dir with original names
for %%f in (%files_private%) do (
    REM Copy file to home_dir with original name
    xcopy /y "%source_dir%\%%f" "%home_dir%\%%f" >nul
)

REM Process files to be copied only to root_dir with new names
for %%f in (%files_root_only%) do (
    set "dest_file=%%~nf"

    if "%%f"=="ssh_config.txt" set "dest_file=ssh_config"

    REM Use delayed expansion for dest_file
    set "current_dest_file=!dest_file!"

    REM Copy file to root_dir with modified name
    xcopy /y "%source_dir%\%%f" "%root_dir%\!current_dest_file!" >nul

    REM Remove inheritance and set permissions using icacls
    echo Removing inheritance from %root_dir%\!current_dest_file!...
    icacls "%root_dir%\!current_dest_file!" /inheritance:r

    REM Set permissions for all files
    icacls "%root_dir%\!current_dest_file!" /grant SYSTEM:F Administrators:F
    icacls "%root_dir%\!current_dest_file!" /grant:r "Authenticated Users":RX
)

echo Files copied and permissions set successfully.
exit /b 0