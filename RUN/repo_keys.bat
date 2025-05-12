@echo off
setlocal enabledelayedexpansion

set "log_file=%~dp0repo_keys.log"
echo [repo_keys] Logging to %log_file%

> "%log_file%" 2>&1 (
    if "%~2"=="" (
        echo [repo_keys] Usage: %0 [mode] [filepaths, ...]
        echo [repo_keys] Modes: default, private, root_private, root_public
        exit /b 101
    )

    set mode=%~1
    shift
    
    net session >nul 2>&1
    if %errorlevel% equ 0 (
        echo Elevated privileges verified.
    ) else (
        echo Requesting elevated privileges...
        PowerShell -Command "Start-Process cmd -ArgumentList '/c %~dpnx0' -Verb RunAs"
        exit /b
    )

    echo [repo_keys] Mode: !mode!
    
    if %errorlevel% neq 0 (
        echo [repo_keys] Startup error
        exit /b 9
    )

    :process_files
    set "file_path=%~2"

    echo "[repo_keys] Processing: !file_path!"
    if "!file_path!"=="" goto :done
    
    if %errorlevel% neq 0 (
        echo [repo_keys] Init error for !file_path!
        exit /b 10
    )

    echo [repo_keys] Original permissions:
    icacls !file_path!
    
    if %errorlevel% neq 0 (
        echo [repo_keys] Failed to check permissions, is the file path correct?
        exit /b 11
    )
    
    echo [repo_keys] Resetting permissions
    icacls !file_path! /reset
    if %errorlevel% neq 0 (
        echo [repo_keys] Failed to reset permissions for !file_path!
        exit /b 12
    )
    
    if "!mode!"=="default" (
        echo [repo_keys] Default permissions set.
    ) else (        
        echo [repo_keys] Removing inheritance for !file_path!
        icacls !file_path! /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F
        if %errorlevel% neq 0 (
            echo [repo_keys] Failed to remove inheritance for !file_path!
            exit /b 13
        )
        
        if "!mode!"=="private" (
            echo [repo_keys] Owner set to %USERNAME%:
            icacls !file_path! /setowner %USERNAME%
            if %errorlevel% neq 0 (
                echo [repo_keys] Failed to set user ownership for !file_path!
                exit /b 15
            )            
            icacls !file_path! /grant %USERNAME%:F
            if %errorlevel% neq 0 (
                echo [repo_keys] Failed to set owner permissions for !file_path!
                exit /b 15
            )

            echo [repo_keys] Block read permissions:
            icacls !file_path! /remove *S-1-5-11 *S-1-5-32-545
            if %errorlevel% neq 0 (
                echo [repo_keys] Failed to block read permissions for !file_path!
                exit /b 16
            )
        ) else (
            echo [repo_keys] Taking admin ownership of !file_path!
            takeown /f !file_path! /a /d y
            if %errorlevel% neq 0 (
                echo [repo_keys] Failed to take admin ownership of !file_path!
                exit /b 11
            )
            echo [repo_keys] Admin-owned:
            if "!mode!"=="root_private" (
                icacls !file_path! /setowner SYSTEM
                if %errorlevel% neq 0 (
                    echo [repo_keys] Failed to set owner for !file_path!
                    exit /b 18
                )
                echo [repo_keys] Owner set to SYSTEM
            ) else if "!mode!"=="root_public" (
                icacls !file_path! /grant SYSTEM:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX
                if %errorlevel% neq 0 (
                    echo [repo_keys] Failed to grant permissions for !file_path!
                    exit /b 19
                )
                echo [repo_keys] Permissions set
            )
        )
    )

    echo [repo_keys] Final permissions:
    icacls !file_path!

    echo [repo_keys] Processed !file_path!

    shift
    set "file_path=%~1"
    goto :process_files

    :done
    echo [repo_keys] Files' permissions set successfully.
)
exit /b 0