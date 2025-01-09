@echo off
setlocal enabledelayedexpansion

REM Define source and destination directories
set "source_dir=%~dp0"
set "home_dir=C:\Users\capta\.ssh"
set "root_dir=C:\ProgramData\ssh"

REM Ensure the script is running with administrator privileges
>nul 2>&1 "%SystemRoot%\system32\cacls.exe" "%SystemRoot%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo This script requires elevated privileges. Please run as administrator.
    exit /b 1
)

REM Define the list of files to process
set files_home_only=config.txt
set files_home_and_root=authorized_keys.txt known_hosts.txt
set files_non_txt=dev_ed25519.pub id_ed25519.pub id_ecdsa.pub id_rsa.pub
set files_private=dev_ed25519 id_ed25519 id_ecdsa id_rsa
set files_root_only=ssh_config.txt sshd_config.txt

REM Process files to be copied only to home_dir
for %%f in (%files_home_only%) do (
    set "dest_file=%%~nf"

    if "%%f"=="config.txt" set "dest_file=config"

    REM Use delayed expansion for dest_file
    set "current_dest_file=!dest_file!"

    REM Copy file to home_dir
    copy /y "%source_dir%\%%f" "%home_dir%\!current_dest_file!"
    if !errorlevel! neq 0 (
        echo Error encountered during copying %%f to %home_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )
)

REM Process files to be copied to both home_dir and root_dir with new names
for %%f in (%files_home_and_root%) do (
    set "dest_file=%%~nf"

    if "%%f"=="authorized_keys.txt" set "dest_file=authorized_keys"
    if "%%f"=="known_hosts.txt" set "dest_file=known_hosts"

    REM Use delayed expansion for dest_file
    set "current_dest_file=!dest_file!"

    REM Copy file to home_dir
    copy /y "%source_dir%\%%f" "%home_dir%\!current_dest_file!"
    if !errorlevel! neq 0 (
        echo Error encountered during copying %%f to %home_dir%\%%f. Error code: !errorlevel!
        exit /b !errorlevel!
    )
)

REM Process files to be copied to both home_dir and root_dir with new names
for %%f in (%files_home_and_root%) do (
    set "dest_file=%%~nf"

    if "%%f"=="authorized_keys.txt" set "dest_file=administrators_authorized_keys"
    if "%%f"=="known_hosts.txt" set "dest_file=ssh_known_hosts"

    REM Use delayed expansion for dest_file
    set "current_dest_file=!dest_file!"

    REM Copy file to root_dir with modified name
    copy /y "%source_dir%\%%f" "%root_dir%\!current_dest_file!"
    if !errorlevel! neq 0 (
        echo Error encountered during copying %%f to %root_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )
)

REM Process non-txt files to be copied to home_dir with original names and root_dir with modified names
for %%f in (%files_non_txt%) do (
    set "dest_file=%%~nf"

    if "%%f"=="dev_ed25519.pub" set "dest_file=dev_ed25519.pub"
    if "%%f"=="id_ed25519.pub" set "dest_file=ssh_host_ed25519_key.pub"
    if "%%f"=="id_ecdsa.pub" set "dest_file=ssh_host_ecdsa_key.pub"
    if "%%f"=="id_rsa.pub" set "dest_file=ssh_host_rsa_key.pub"

    REM Use delayed expansion for dest_file
    set "current_dest_file=!dest_file!"

    REM Copy file to home_dir with original name
    copy /y "%source_dir%\%%f" "%home_dir%\%%f"
    if !errorlevel! neq 0 (
        echo Error encountered during copying %%f to %home_dir%\%%f. Error code: !errorlevel!
        exit /b !errorlevel!
    )

    REM Copy file to root_dir with modified name
    copy /y "%source_dir%\%%f" "%root_dir%\!current_dest_file!"
    if !errorlevel! neq 0 (
        echo Error encountered during copying %%f to %root_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )
)

REM Process private files to be copied to root_dir with modified names
for %%f in (%files_private%) do (
    set "dest_file=%%~nf"

    if "%%f"=="dev_ed25519" set "dest_file=dev_ed25519"
    if "%%f"=="id_ed25519" set "dest_file=ssh_host_ed25519_key"
    if "%%f"=="id_ecdsa" set "dest_file=ssh_host_ecdsa_key"
    if "%%f"=="id_rsa" set "dest_file=ssh_host_rsa_key"

    REM Use delayed expansion for dest_file
    set "current_dest_file=!dest_file!"

    REM Copy file to root_dir with modified name
    copy /y "%home_dir%\%%f" "%root_dir%\!current_dest_file!"
    if !errorlevel! neq 0 (
        echo Error encountered during copying %%f to %root_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )

    REM Remove inheritance and set permissions using icacls
    echo Removing inheritance from %root_dir%\!current_dest_file!...
    icacls "%root_dir%\!current_dest_file!" /inheritance:r
    if !errorlevel! neq 0 (
        echo Error encountered during removing inheritance for %root_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )

    REM Set permissions for private key files
    icacls "%root_dir%\!current_dest_file!" /grant SYSTEM:F Administrators:F
    if !errorlevel! neq 0 (
        echo Error encountered during setting permissions for %root_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )

    REM Remove Authenticated Users group from private key files
    icacls "%root_dir%\!current_dest_file!" /remove:g "Authenticated Users"
    if !errorlevel! neq 0 (
        echo Error encountered during removing Authenticated Users for %root_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )
)

REM Process files to be copied only to root_dir with new names
for %%f in (%files_root_only%) do (
    set "dest_file=%%~nf"

    if "%%f"=="ssh_config.txt" set "dest_file=ssh_config"
    if "%%f"=="sshd_config.txt" set "dest_file=sshd_config"

    REM Use delayed expansion for dest_file
    set "current_dest_file=!dest_file!"

    REM Copy file to root_dir with modified name
    copy /y "%source_dir%\%%f" "%root_dir%\!current_dest_file!"
    if !errorlevel! neq 0 (
        echo Error encountered during copying %%f to %root_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )

    REM Remove inheritance and set permissions using icacls
    echo Removing inheritance from %root_dir%\!current_dest_file!...
    icacls "%root_dir%\!current_dest_file!" /inheritance:r
    if !errorlevel! neq 0 (
        echo Error encountered during removing inheritance for %root_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )

    REM Set permissions for all files
    icacls "%root_dir%\!current_dest_file!" /grant SYSTEM:F Administrators:F
    if !errorlevel! neq 0 (
        echo Error encountered during setting permissions for %root_dir%\!current_dest_file!. Error code: !errorlevel!
        exit /b !errorlevel!
    )
    icacls "%root_dir%\!current_dest_file!" /grant:r "Authenticated Users":RX
    if !errorlevel! neq 0 (
        echo Error encountered during adding read and execute permissions for Authenticated Users on %%f. Error code: !errorlevel!
        exit /b !errorlevel!
    )
)

echo Files copied and permissions set successfully.
exit /b 0