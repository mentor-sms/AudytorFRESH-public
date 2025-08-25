@echo on
setlocal enabledelayedexpansion

rem ------ OUT ONLY ------

set "LOG_DIR=%~3"
if "!LOG_DIR!"=="" (
    echo 1: Nie podano katalogu dla pliku dziennika >&2
    exit /b 5
)
mkdir "!LOG_DIR!" >nul 2>&1
dir /ad "!LOG_DIR!" >nul 2>&1
if errorlevel 1 (
    echo 1: Nie można utworzyć katalogu dziennika: "!LOG_DIR!" >&2
    exit /b 6
)
set "log_file=!LOG_DIR!\cmd_!id!.run.lab.log"

@echo off

rem ------ ARGS ------

echo REV 2.3 CMD
echo REV 2.3 CMD>> "!log_file!"
echo Dziennik: !LOG_DIR!\cmd_!id![.run].lab.log

set "id=%~2"
if "!id!"=="" (
    echo 2: Brak wymaganego identyfikatora (argument 2: ID). Podaj liczbowy identyfikator procesu.>> "!log_file!"
    echo 2: Brak wymaganego identyfikatora (argument 2: ID). Podaj liczbowy identyfikator procesu >&2
    exit /b 2
)
echo Identyfikator procesu [id]: !id!

set /A num=!id! 2>nul
if not "!num!"=="!id!" (
    echo 2: Nieprawidłowy identyfikator (argument 2: ID nie jest liczbą).>> "!log_file!"
    echo 2: Nieprawidłowy identyfikator (argument 2: ID nie jest liczbą) >&2
    exit /b 2
)

set "mode=%~1"
if "!mode!"=="" (
    echo 4: Brak trybu (argument 1). Dozwolone: default, private, root_private, root_public.>> "!log_file!"
    echo 4: Brak trybu (argument 1). Dozwolone: default, private, root_private, root_public >&2
    exit /b 4
)
if /i not "!mode!"=="default" if /i not "!mode!"=="private" if /i not "!mode!"=="root_private" if /i not "!mode!"=="root_public" (
    echo 4: Nieprawidłowy tryb (argument 1). Dozwolone: default, private, root_private, root_public.>> "!log_file!"
    echo 4: Nieprawidłowy tryb (argument 1). Dozwolone: default, private, root_private, root_public >&2
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
    echo 3: Brak ścieżek plików do przetworzenia (argumenty od 6.). Podaj co najmniej jedną ścieżkę.>> "!log_file!"
    echo 3: Brak ścieżek plików do przetworzenia (argumenty od 6.). Podaj co najmniej jedną ścieżkę >&2
    exit /b 3
)

rem ------ SUDO CHECK ------

ver >nul 2>&1
whoami /groups | findstr /C:"S-1-16-12288" >nul 2>&1
set "IS_ELEVATED="
if %errorlevel% equ 0 set "IS_ELEVATED=1"
ver >nul 2>&1

if defined IS_ELEVATED (
    echo 1: asrun win_chown.bat>> "!log_file!"
    echo 1: asrun win_chown.bat >&2 rem direct runas disabled by policy
    exit /b 1
)

rem ------ PRE-RUN VALIDATION ------

echo Weryfikacja wejścia...>> "!log_file!"
echo Weryfikacja wejścia...
set "arg_index=0"
for /f "usebackq delims=" %%I in (`%ComSpec% /v:on /c for %%G in (^%*^) do @echo(%%~G`) do (
    set /a arg_index+=1
    if !arg_index! geq 6 (
        set "file_path=%%~I"
        if "!file_path!"=="" (
            echo 6: Błąd przed przetwarzaniem pliku (pusta ścieżka).>> "!log_file!"
            echo 6: Błąd przed przetwarzaniem pliku (pusta ścieżka) >&2
            exit /b 6
        )
        if not exist "!file_path!" (
            echo 7: Nie znaleziono pliku: !file_path!>> "!log_file!"
            echo 7: Nie znaleziono pliku: !file_path! >&2
            exit /b 7
        )
        icacls "!file_path!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo 9: Błąd odczytu ACL (icacls) dla: !file_path!>> "!log_file!"
            echo 9: Błąd odczytu ACL (icacls) dla: !file_path! >&2
            exit /b 9
        )
        dir "!file_path!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo 13: Plik istnieje, ale może być problem z dostępem: !file_path!>> "!log_file!"
            echo 13: Plik istnieje, ale może być problem z dostępem: !file_path! >&2
            exit /b 13
        )
    )
)

if defined IS_ELEVATED (
    echo X: delegating to win_chown.bat>> "!log_file!"
    echo X: delegating to win_chown.bat rem disabled by policy
    "%~dpn0.bat" %*
    exit /b %errorlevel%
)

rem ------ SUDO RUN ------

echo(>> "!log_file!"
echo(
echo Running [BAT]:>> "!log_file!"
echo Running BAT...
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process -Verb RunAs -FilePath '%~dpn0.bat' -ArgumentList '%*' -PassThru; $p.WaitForExit(); exit $p.ExitCode"
if %errorlevel% equ 1223 (
    echo(
    echo [/BAT]
    echo 10: Podniesienie uprawnień anulowane przez użytkownika (UAC, kod 1223)>> "!log_file!"
    echo 10: Podniesienie uprawnień anulowane przez użytkownika (UAC, kod 1223) >&2
    exit /b 1223
)
if %errorlevel% neq 0 (
    echo(
    echo [/BAT]
    echo 10: Błąd podczas próby uruchomienia z uprawnieniami administratora>> "!log_file!"
    echo 10: Błąd podczas próby uruchomienia z uprawnieniami administratora >&2
    exit /b %errorlevel%
)
rem Wait until the log file can be exclusively opened (inner BAT fully released it)
powershell -NoProfile -Command "$p = [IO.Path]::GetFullPath('%log_file%'); $deadline = [DateTime]::UtcNow.AddSeconds(10); while ($true) { try { $s = [IO.File]::Open($p, 'Append', 'Write', 'None'); $s.Close(); exit 0 } catch { Start-Sleep -Milliseconds 100; if ([DateTime]::UtcNow -gt $deadline) { exit 1 } } }" >nul 2>&1
if errorlevel 1 (
    echo(
    echo [/BAT]
    echo 15: Nie udało się uzyskać wyłącznego dostępu do pliku dziennika po wykonaniu BAT>> "!log_file!"
    echo 15: Nie udało się uzyskać wyłącznego dostępu do pliku dziennika po wykonaniu BAT >&2
    exit /b 15
)

echo(>> "!log_file!"
echo(
echo [/BAT]>> "!log_file!"
echo [/BAT]

rem ------ POST-RUN VALIDATION ------

set "SID_ARG=%~5"
set "arg_index=0"
for /f "usebackq delims=" %%I in (`%ComSpec% /v:on /c for %%G in (^%*^) do @echo(%%~G`) do (
    set /a arg_index+=1
    if !arg_index! geq 6 (
        if /i "!mode!"=="private" (
            powershell -NoProfile -Command "$p=Get-Acl -LiteralPath '%%~I'; $acct=(New-Object System.Security.Principal.SecurityIdentifier('%~5')).Translate([System.Security.Principal.NTAccount]).Value; $owner=$p.Owner; $prot=$p.AreAccessRulesProtected; $has=$p.Access | Where-Object { $_.IdentityReference.Value -eq $acct -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; if ($owner -eq $acct -and $prot -and $has) { exit 0 } else { exit 1 }" >nul 2>&1
            if errorlevel 1 (
                echo 14: Weryfikacja uprawnień nie powiodła się dla: %%~I>> "!log_file!"
                echo 14: Weryfikacja uprawnień nie powiodła się dla: %%~I >&2
                exit /b 14
            )
        ) else if /i "!mode!"=="root_private" (
            powershell -NoProfile -Command "$p=Get-Acl -LiteralPath '%%~I'; $adm=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')).Translate([System.Security.Principal.NTAccount]).Value; $sys=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')).Translate([System.Security.Principal.NTAccount]).Value; $okOwner=($p.Owner -eq $adm); $prot=$p.AreAccessRulesProtected; $hasAdm=$p.Access | Where-Object { $_.IdentityReference.Value -eq $adm -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; $hasSys=$p.Access | Where-Object { $_.IdentityReference.Value -eq $sys -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; if ($okOwner -and $prot -and $hasAdm -and $hasSys) { exit 0 } else { exit 1 }" >nul 2>&1
            if errorlevel 1 (
                echo 14: Weryfikacja uprawnień (root_private) nie powiodła się dla: %%~I>> "!log_file!"
                echo 14: Weryfikacja uprawnień (root_private) nie powiodła się dla: %%~I >&2
                exit /b 14
            )
        ) else if /i "!mode!"=="root_public" (
            powershell -NoProfile -Command "$p=Get-Acl -LiteralPath '%%~I'; $adm=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')).Translate([System.Security.Principal.NTAccount]).Value; $sys=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')).Translate([System.Security.Principal.NTAccount]).Value; $usr=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')).Translate([System.Security.Principal.NTAccount]).Value; $auth=(New-Object System.Security.Principal.SecurityIdentifier('S-1-5-11')).Translate([System.Security.Principal.NTAccount]).Value; $okOwner=($p.Owner -eq $adm); $prot=$p.AreAccessRulesProtected; $hasAdm=$p.Access | Where-Object { $_.IdentityReference.Value -eq $adm -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; $hasSys=$p.Access | Where-Object { $_.IdentityReference.Value -eq $sys -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and $_.AccessControlType -eq 'Allow' }; $rx=[System.Security.AccessControl.FileSystemRights]::ReadAndExecute; $hasUsr=$p.Access | Where-Object { $_.IdentityReference.Value -eq $usr -and (($_.FileSystemRights -band $rx) -ne 0) -and $_.AccessControlType -eq 'Allow' }; $hasAuth=$p.Access | Where-Object { $_.IdentityReference.Value -eq $auth -and (($_.FileSystemRights -band $rx) -ne 0) -and $_.AccessControlType -eq 'Allow' }; if ($okOwner -and $prot -and $hasAdm -and $hasSys -and $hasUsr -and $hasAuth) { exit 0 } else { exit 1 }" >nul 2>&1
            if errorlevel 1 (
                echo 14: Weryfikacja uprawnień (root_public) nie powiodła się dla: %%~I>> "!log_file!"
                echo 14: Weryfikacja uprawnień (root_public) nie powiodła się dla: %%~I >&2
                exit /b 14
            )
        ) else (
            rem default: no strict ownership/grant expectations beyond earlier access checks
            rem no-op
        )
    )
)

rem ------ HAPPY END ------

echo Podsumowanie operacji:
echo   - Identyfikator: !id!
echo   - Tryb uprawnień: !mode!
echo   - Plik dziennika: !log_file!
echo   - OKFIN
timeout /t 30 /nobreak >nul
exit 0 rem wait to be killed