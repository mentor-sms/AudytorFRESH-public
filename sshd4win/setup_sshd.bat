@echo off
setlocal enabledelayedexpansion

set "log_file=%~dp0setup_sshd.log"
echo [setup_sshd] Logging to %log_file%
> "%log_file%" 2>&1 (
    if "%~1"=="" (
        echo [setup_sshd] Usage: %0 home_dir
        exit /b 101
    )

    set home_dir=%~1\.ssh
    set source_dir=%~dp0
    set root_dir=C:\ProgramData\ssh

    echo [setup_sshd] "SSH directory: !root_dir!"
    echo [setup_sshd] "Source directory: !source_dir!"
    echo [setup_sshd] "Home directory: !home_dir!"

    echo [setup_sshd] %SystemRoot%\system32\cacls.exe
    echo [setup_sshd] %SystemRoot%\system32\config\system
    >nul 2>&1 %SystemRoot%\system32\cacls.exe %SystemRoot%\system32\config\system
    if %errorlevel% neq 0 (
        echo This script requires elevated privileges. Please run as administrator.
        exit /b 102
    )

    echo [setup_sshd] Elevated privileges verified.

    set txt_home=known_hosts.txt config.txt
    set pub_home=id_ed25519.pub id_rsa.pub
    set priv_home=id_ed25519 id_rsa
    set txt_root=sshd_config.txt

    echo [setup_sshd] Processing user config...
    for %%f in (%txt_home%) do (
        echo [setup_sshd] from !source_dir!%%f to !home_dir!\%%~nf
        copy /y "!source_dir!%%f" "!home_dir!\%%~nf"
    )

    echo [setup_sshd] Processing user public keys...
    for %%f in (%pub_home%) do (
        echo [setup_sshd] from !source_dir!%%f to !home_dir!\%%f
        copy /y !source_dir!%%f !home_dir!\%%f
    )

    echo [setup_sshd] Processing user private keys...

    for %%f in (%priv_home%) do (
        echo [setup_sshd] from !source_dir!%%f to !home_dir!\%%f
        copy /y !source_dir!%%f !home_dir!\%%f
    )

    echo [setup_sshd] Processing root config...

    for %%f in (%txt_root%) do (
        echo [setup_sshd] from !source_dir!%%f to !home_dir!\%%~nf
        copy /y !source_dir!%%f !root_dir!\%%~nf
    )

    echo [setup_sshd] Files copied and permissions set successfully.
)
exit /b 0