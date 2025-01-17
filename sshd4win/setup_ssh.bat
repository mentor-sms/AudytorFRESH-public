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

set txt_home=known_hosts.txt config.txt
set ntxt_home=id_ed25519.pub id_rsa.pub id_ed25519 id_rsa
set txt_root=ssh_config.txt

echo Processing txt files...

for %%f in (%txt_home%) do (
    echo from %source_dir%%%f to %home_dir%\%%~nf
    @echo on
    copy /y "%source_dir%%%f" "%home_dir%\%%~nf"
    @echo off
)

echo Processing non-txt files...

for %%f in (%ntxt_home%) do (
    echo from %source_dir%%%f to %home_dir%\%%f
    @echo on
    copy /y %source_dir%%%f %home_dir%\%%f
    @echo off
)

echo Processing root files...

for %%f in (%txt_root%) do (    
    echo from %source_dir%%%f to %home_dir%\%%~nf
    @echo on
    copy /y %source_dir%%%f %root_dir%\%%~nf
    @echo off
    
    REM set current_dest_file = %root_dir%\%%~nf

    REM icacls !current_dest_file! /inheritance:r

    REM icacls !current_dest_file! /grant SYSTEM:F Administrators:F
    REM icacls !current_dest_file! /grant:r "Authenticated Users":RX
)

echo Files copied and permissions set successfully.
exit /b 0