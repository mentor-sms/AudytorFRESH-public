@echo on
setlocal enabledelayedexpansion

set "log_file=%~dp0setup_ssh.log"
echo Logging to %log_file%
> "%log_file%" 2>&1 (
    if "%1"=="" (
        echo Usage: %0 home_dir
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
    set pub_home=id_ed25519.pub id_rsa.pub
    set priv_home=id_ed25519 id_rsa
    set txt_root=ssh_config.txt

    echo Processing user config...

    for %%f in (%txt_home%) do (
        echo from %source_dir%%%f to %home_dir%\%%~nf
        @echo on
        copy /y "%source_dir%%%f" "%home_dir%\%%~nf"
        @echo off
    )

    echo Processing user public keys...

    for %%f in (%pub_home%) do (
        echo from %source_dir%%%f to %home_dir%\%%f
        @echo on
        copy /y %source_dir%%%f %home_dir%\%%f
        @echo off
    )
    
    echo Processing user private keys...
    
        for %%f in (%priv_home%) do (
            echo from %source_dir%%%f to %home_dir%\%%f
            @echo on
            copy /y %source_dir%%%f %home_dir%\%%f
            @echo off
            
            icacls %home_dir%\%%~nf /inheritance:r
            icacls %home_dir%\%%~nf /setowner %USERNAME%
    
            icacls %home_dir%\%%~nf /grant SYSTEM:R Administrators:R %USERNAME%:F
            icacls %home_dir%\%%~nf /grant:r "Authenticated Users":RX Users:RX
        )

    echo Processing root config...

    for %%f in (%txt_root%) do (
        echo from %source_dir%%%f to %home_dir%\%%~nf
        @echo on
        copy /y %source_dir%%%f %root_dir%\%%~nf
        @echo off

        icacls %root_dir%\%%~nf /inheritance:r

        icacls %root_dir%\%%~nf /grant SYSTEM:F Administrators:F
    )

    echo Files copied and permissions set successfully.
)
exit /b 0