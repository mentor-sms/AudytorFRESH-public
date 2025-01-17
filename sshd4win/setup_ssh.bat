@echo off
setlocal enabledelayedexpansion

if "%1"=="" (
    echo Usage: %0 username
    exit /b 101
)

set "home_dir=%1\.ssh"

set "source_dir=%~dp0"
set "root_dir=C:\ProgramData\ssh"

echo SSH directory: %root_dir%
echo Source directory: %source_dir%
echo Home directory: %home_dir%

>nul 2>&1 "%SystemRoot%\system32\cacls.exe" "%SystemRoot%\system32\config\system"
if errorlevel 1 (
    echo This script requires elevated privileges. Please run as administrator.
    exit /b 102
)

echo Elevated privileges verified.

set files_home=known_hosts.txt config.txt
set files_non_txt=id_ed25519.pub id_rsa.pub
set files_private=id_ed25519 id_rsa
set files_root_only=ssh_config.txt

echo Processing txt files...

for %%f in (%files_home%) do (
    @echo on
    echo copy from %source_dir%\%%f to %home_dir%\%%~nf
    xcopy /y "%source_dir%\%%f" "%home_dir%\%%~nf"
    @echo off
)

echo Processing non-txt files...

for %%f in (%files_non_txt%) do (
    @echo on
    echo copy from %source_dir%\%%f to %home_dir%\%%f
    xcopy /y "%source_dir%\%%f" "%home_dir%\%%f"
    @echo off
)

echo Processing private files...

for %%f in (%files_private%) do (
    @echo on
    xcopy /y "%source_dir%\%%f" "%home_dir%\%%f"
    @echo off
)

echo Processing root files...

for %%f in (%files_root_only%) do (
    set "dest_file=%%~nf"

    if "%%f"=="ssh_config.txt" set "dest_file=ssh_config"

    set "current_dest_file=!dest_file!"

    @echo on
    xcopy /y "%source_dir%\%%f" "%root_dir%\!current_dest_file!"
    @echo off

    echo Removing inheritance from %root_dir%\!current_dest_file!...
    icacls "%root_dir%\!current_dest_file!" /inheritance:r

    icacls "%root_dir%\!current_dest_file!" /grant SYSTEM:F Administrators:F
    icacls "%root_dir%\!current_dest_file!" /grant:r "Authenticated Users":RX
)

echo Files copied and permissions set successfully.
exit /b 0