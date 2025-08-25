
@echo off

rem -----------------------------------------------------------------------------
rem Usage and argument parsing guide (read before editing or calling this script)
rem -----------------------------------------------------------------------------
rem Call syntax:
rem   win_chown.cmd <mode> <id> <log_dir> <reserved> <current_user_sid> <file1> [file2 ...]
rem
rem Parsed arguments (positions are 1-based, as passed on the command line):
rem   %~1 -> mode                : Permission mode. Supported (case-insensitive):
rem                                - default
rem                                - private        (requires %~5 CURRENT_USER_SID)
rem                                - root_private
rem                                - root_public
rem   %~2 -> id                  : Numeric identifier used for logging (validated).
rem   %~3 -> LOG_DIR             : Directory where logs are written (required).
rem                                Log file path: <LOG_DIR>\cmd_<id>.run.lab.log
rem   %~4 -> reserved/unused     : Accepted but ignored by this script.
rem   %~5 -> CURRENT_USER_SID    : Required only when mode=private (error 12 if missing).
rem   %~6+ -> file paths         : One or more file paths to process. Each path may be quoted.
rem
rem Exit codes summary:
rem   0    OK (success)
rem   1    Unexpected administrative privileges detected on entry
rem   2    Missing or non-numeric id (argument 2)
rem   3    No file paths provided (arguments from position 6)
rem   4    Missing or invalid mode (argument 1)
rem   5    Missing log directory (argument 3)
rem   6    Empty file path encountered
rem   7    File not found
rem   9    ACL read error (icacls)
rem   10   Failed to start elevated process
rem   12   Missing SID for private mode (argument 5)
rem   13   File exists but access may be restricted
rem   14   Post-run permission verification failed
rem   15   Could not exclusively open the log file after run
rem   1223 Elevation canceled by user (UAC)
rem -----------------------------------------------------------------------------

echo(
echo RUN:
echo %cmdcmdline%
echo PARSED:
echo Command: "%~f0" %*
echo(

@echo on
setlocal enabledelayedexpansion

rem ------ OUT ONLY ------

set "LOG_DIR=%~3"
if "!LOG_DIR!"=="" (
    echo 1: Nie podano katalogu dla pliku dziennika >&2
    exit /b 5
)
set "log_file=!LOG_DIR!\cmd_!id!.run.lab.log"

@echo off

echo REV 3.0.0 CMD
echo REV 3.0.0 CMD>> "!log_file!"
echo Dziennik: !LOG_DIR!\cmd_!id!.run.lab.log

echo(>> "!log_file!"
echo RUN:>> "!log_file!"
echo %cmdcmdline%>> "!log_file!"
echo PARSED:>> "!log_file!"
echo Command: "%~f0" %*>> "!log_file!"
echo(>> "!log_file!"

echo(
rem ------ ARGS ------
echo Test argumentow...>> "!log_file!"
echo Test argumentow...

set "id=%~2"
if "!id!"=="" (
    echo 2: Brak wymaganego identyfikatora (argument 2: ID). Podaj liczbowy identyfikator procesu.>> "!log_file!"
    echo 2: Brak wymaganego identyfikatora (argument 2: ID). Podaj liczbowy identyfikator procesu >&2
    exit /b 2
)
echo Identyfikator procesu [id]: !id!

set /A num=!id! 2>nul
if not "!num!"=="!id!" (
    echo 2: Nieprawidlowy identyfikator (argument 2: ID nie jest liczba).>> "!log_file!"
    echo 2: Nieprawidlowy identyfikator (argument 2: ID nie jest liczba) >&2
    exit /b 2
)

set "mode=%~1"
if "!mode!"=="" (
    echo 4: Brak trybu (argument 1). Dozwolone: default, private, root_private, root_public.>> "!log_file!"
    echo 4: Brak trybu (argument 1). Dozwolone: default, private, root_private, root_public >&2
    exit /b 4
)
if /i not "!mode!"=="default" if /i not "!mode!"=="private" if /i not "!mode!"=="root_private" if /i not "!mode!"=="root_public" (
    echo 4: Nieprawidlowy tryb (argument 1). Dozwolone: default, private, root_private, root_public.>> "!log_file!"
    echo 4: Nieprawidlowy tryb (argument 1). Dozwolone: default, private, root_private, root_public >&2
    exit /b 4
)
echo Docelowe uprawnienia [mode]: !mode!

set "SID_ARG=%~5"
if /i "!mode!"=="private" (
    if "!SID_ARG!"=="" (
        echo 12: Brak SID (argument 5) wymagany dla trybu private.>> "!log_file!"
        echo 12: Brak SID (argument 5) wymagany dla trybu private >&2
        exit /b 12
    )
)

if "%~6"=="" (
    echo 3: Brak sciezek plikow do przetworzenia (argumenty od 6.). Podaj co najmniej jedna sciezke.>> "!log_file!"
    echo 3: Brak sciezek plikow do przetworzenia (argumenty od 6.). Podaj co najmniej jedna sciezke >&2
    exit /b 3
)

echo(
rem ------ SUDO CHECK ------
echo Test SUDO...>> "!log_file!"
echo Test SUDO...

ver >nul 2>&1
whoami /groups | findstr /C:"S-1-16-12288" >nul 2>&1
set "IS_ELEVATED="
if %errorlevel% equ 0 set "IS_ELEVATED=1"
ver >nul 2>&1

if defined IS_ELEVATED (
    echo 1: Nieoczekiwane uprawnienia administratora>> "!log_file!"
    echo 1: Nieoczekiwane uprawnienia administratora >&2
    exit /b 1
)

echo(
rem ------ PRE-RUN VALIDATION ------
echo Weryfikacja wejsciowa...>> "!log_file!"
echo Weryfikacja wejsciowa...

set "arg_index=0"
for /f "usebackq delims=" %%I in (`%ComSpec% /v:on /c for %%G in (^%*^) do @echo(%%~G`) do (
    set /a arg_index+=1
    if !arg_index! geq 6 (
        set "file_path=%%~I"
        if "!file_path!"=="" (
            echo 6: Blad przed przetwarzaniem pliku (pusta sciezka).>> "!log_file!"
            echo 6: Blad przed przetwarzaniem pliku (pusta sciezka) >&2
            exit /b 6
        )
        if not exist "!file_path!" (
            echo 7: Nie znaleziono pliku: !file_path!>> "!log_file!"
            echo 7: Nie znaleziono pliku: !file_path! >&2
            exit /b 7
        )
        icacls "!file_path!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo 9: Blad odczytu ACL (icacls) dla: !file_path!>> "!log_file!"
            echo 9: Blad odczytu ACL (icacls) dla: !file_path! >&2
            exit /b 9
        )
        dir "!file_path!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo 13: Plik istnieje, ale moze byc problem z dostepem: !file_path!>> "!log_file!"
            echo 13: Plik istnieje, ale moze byc problem z dostepem: !file_path! >&2
            exit /b 13
        )
    )
)

if defined IS_ELEVATED ( rem na przyszlosc
    echo X: delegating to win_chown.bat>> "!log_file!"
    echo X: delegating to win_chown.bat
    "%~dpn0.bat" %*
    exit /b %errorlevel%
)


echo(
rem ------ SUDO RUN ------
echo Running BAT...:>> "!log_file!"
echo Running BAT...
echo(>> "!log_file!"
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process -Verb RunAs -FilePath '%~dpn0.bat' -ArgumentList '%*' -PassThru; $p.WaitForExit(); exit $p.ExitCode"
if %errorlevel% equ 1223 (
    echo(
    echo [/BAT]
    echo 10: Podniesienie uprawnien anulowane przez uzytkownika (UAC, kod 1223)>> "!log_file!"
    echo 10: Podniesienie uprawnien anulowane przez uzytkownika (UAC, kod 1223) >&2
    exit /b 1223
)
if %errorlevel% neq 0 (
    echo(
    echo [/BAT]
    echo 10: Blad podczas proby uruchomienia z uprawnieniami administratora>> "!log_file!"
    echo 10: Blad podczas proby uruchomienia z uprawnieniami administratora >&2
    exit /b %errorlevel%
)

powershell -NoProfile -Command "$p = [IO.Path]::GetFullPath('%log_file%'); $deadline = [DateTime]::UtcNow.AddSeconds(10); while ($true) { try { $s = [IO.File]::Open($p, 'Append', 'Write', 'None'); $s.Close(); exit 0 } catch { Start-Sleep -Milliseconds 100; if ([DateTime]::UtcNow -gt $deadline) { exit 1 } } }" >nul 2>&1
if errorlevel 1 (
    echo(
    echo [/BAT]
    echo 15: Nie udalo sie uzyskac wylacznego dostepu do pliku dziennika po wykonaniu BAT>> "!log_file!"
    echo 15: Nie udalo sie uzyskac wylacznego dostepu do pliku dziennika po wykonaniu BAT >&2
    exit /b 15
)
echo(>> "!log_file!"
echo [/BAT]>> "!log_file!"
echo [/BAT]

echo(
rem ------ POST-RUN VALIDATION ------
echo Test wynikow...:>> "!log_file!"
echo Test wynikow...

set "SID_ARG=%~5"
set "arg_index=0"
for /f "usebackq delims=" %%I in (`%ComSpec% /v:on /c for %%G in (^%*^) do @echo(%%~G`) do (
    set /a arg_index+=1
    if !arg_index! geq 6 (
        if /i "!mode!"=="private" (
            powershell -NoProfile -Command "$p=Get-Acl -LiteralPath '%%~I'; $acct=(New-Object System.Security.Principal.SecurityIdentifier('%~5')).Translate([System.Security.Principal.NTAccount]).Value; $owner=$p.Owner; $prot=$p.AreAccessRulesProtected; $has=$p.Access | Where-Object { $_.IdentityReference.Value -eq $acct -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; if ($owner -eq $acct -and $prot -and $has) { exit 0 } else { exit 1 }" >nul 2>&1
            if errorlevel 1 (
                echo 14: Weryfikacja uprawnien nie powiodla sie dla: %%~I>> "!log_file!"
                echo 14: Weryfikacja uprawnien nie powiodla sie dla: %%~I >&2
                exit /b 14
            )
        ) else if /i "!mode!"=="root_private" (
            powershell -NoProfile -Command "$p=Get-Acl -LiteralPath '%%~I'; $adm=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')).Translate([System.Security.Principal.NTAccount]).Value; $sys=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')).Translate([System.Security.Principal.NTAccount]).Value; $okOwner=($p.Owner -eq $adm); $prot=$p.AreAccessRulesProtected; $hasAdm=$p.Access | Where-Object { $_.IdentityReference.Value -eq $adm -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; $hasSys=$p.Access | Where-Object { $_.IdentityReference.Value -eq $sys -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; if ($okOwner -and $prot -and $hasAdm -and $hasSys) { exit 0 } else { exit 1 }" >nul 2>&1
            if errorlevel 1 (
                echo 14: Weryfikacja uprawnien (root_private) nie powiodla sie dla: %%~I>> "!log_file!"
                echo 14: Weryfikacja uprawnien (root_private) nie powiodla sie dla: %%~I >&2
                exit /b 14
            )
        ) else if /i "!mode!"=="root_public" (
            powershell -NoProfile -Command "$p=Get-Acl -LiteralPath '%%~I'; $adm=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')).Translate([System.Security.Principal.NTAccount]).Value; $sys=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')).Translate([System.Security.Principal.NTAccount]).Value; $usr=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')).Translate([System.Security.Principal.NTAccount]).Value; $auth=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-11')).Translate([System.Security.Principal.NTAccount]).Value; $okOwner=($p.Owner -eq $adm); $prot=$p.AreAccessRulesProtected; $rx=[System.Security.AccessControl.FileSystemRights]::ReadAndExecute; $hasAdm=$p.Access | Where-Object { $_.IdentityReference.Value -eq $adm -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; $hasSys=$p.Access | Where-Object { $_.IdentityReference.Value -eq $sys -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; $hasUsr=$p.Access | Where-Object { $_.IdentityReference.Value -eq $usr -and (($_.FileSystemRights -band $rx) -ne 0) -and $_.AccessControlType -eq 'Allow' }; $hasAuth=$p.Access | Where-Object { $_.IdentityReference.Value -eq $auth -and (($_.FileSystemRights -band $rx) -ne 0) -and $_.AccessControlType -eq 'Allow' }; if ($okOwner -and $prot -and $hasAdm -and $hasSys -and $hasUsr -and $hasAuth) { exit 0 } else { exit 1 }" >nul 2>&1
            if errorlevel 1 (
                echo 14: Weryfikacja uprawnien (root_public) nie powiodla sie dla: %%~I>> "!log_file!"
                echo 14: Weryfikacja uprawnien (root_public) nie powiodla sie dla: %%~I >&2
                exit /b 14
            )
        )
    )
)

echo(
rem ------ HAPPY END ------
echo Podsumowanie operacji:
echo   - Identyfikator: !id!
echo   - Tryb uprawnien: !mode!
echo   - Plik dziennika: !log_file!
echo   - OKFIN
timeout /t 30 /nobreak >nul
exit 0 rem wait to be killed