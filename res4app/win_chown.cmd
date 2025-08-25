@echo off
setlocal enabledelayedexpansion

set "id=%~2"
if "!id!"=="" (
    echo 2: Brak wymaganego identyfikatora (argument 2: ID). Podaj liczbowy identyfikator procesu. >&2
    exit /b 2
)
set /A num=!id! 2>nul
if not "!num!"=="!id!" (
    echo 2: Nieprawidłowy identyfikator (argument 2: ID nie jest liczbą). >&2
    exit /b 2
)
set "mode=%~1"
if "!mode!"=="" (
    echo 4: Brak trybu (argument 1). Dozwolone: default, private, root_private, root_public. >&2
    exit /b 4
)
if /i not "!mode!"=="default" if /i not "!mode!"=="private" if /i not "!mode!"=="root_private" if /i not "!mode!"=="root_public" (
    echo 4: Nieprawidłowy tryb (argument 1). Dozwolone: default, private, root_private, root_public. >&2
    exit /b 4
)

echo REV 2.3 CMD

set "LOG_DIR=%~3"
if "!LOG_DIR!"=="" (
    echo 1: Nie podano katalogu dla pliku dziennika >&2
    exit /b 5
)
if not exist "!LOG_DIR!\NUL" (
    mkdir "!LOG_DIR!" >nul 2>&1
    if %errorlevel% neq 0 (
        echo 1: Nie można utworzyć katalogu dziennika: "!LOG_DIR!" >&2
        exit /b 6
    )
)

set "SID_ARG=%~5"
if /i "!mode!"=="private" (
    if "!SID_ARG!"=="" (
        echo 12: Brak SID (argument 5) wymagany dla trybu private. >&2
        exit /b 12
    )
)

if "%~6"=="" (
    echo 3: Brak ścieżek plików do przetworzenia (argumenty od 6.). Podaj co najmniej jedną ścieżkę. >&2
    exit /b 3
)

set "log_file=!LOG_DIR!\cmd_!id!.run.lab.log"

ver >nul 2>&1
whoami /groups | findstr /C:"S-1-16-12288" >nul 2>&1
set "IS_ELEVATED="
if %errorlevel% equ 0 set "IS_ELEVATED=1"
ver >nul 2>&1

echo Dziennik: !LOG_DIR!\cmd_!id![.run].lab.log
echo Identyfikator procesu [id]: !id!
echo Podano tryb [mode]: !mode!
if defined IS_ELEVATED (
    echo Uprawnienia: uruchomiono z podwyzszonymi uprawnieniami (High Mandatory Level).
) else (
    echo Uprawnienia: brak podwyzszonych uprawnien (nie High Mandatory Level).
)

echo Weryfikacja wejścia (bez modyfikacji)...
set "arg_index=0"
for /f "usebackq delims=" %%I in (`%ComSpec% /v:on /c for %%G in (^%*^) do @echo(%%~G`) do (
    set /a arg_index+=1
    if !arg_index! geq 6 (
        set "file_path=%%~I"
        if "!file_path!"=="" (
            echo 6: Błąd przed przetwarzaniem pliku (pusta ścieżka). >&2
            exit /b 6
        )
        if not exist "!file_path!" (
            echo 7: Nie znaleziono pliku: !file_path! >&2
            exit /b 7
        )
        icacls "!file_path!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo 9: Błąd odczytu ACL (icacls) dla: !file_path! >&2
            exit /b 9
        )
        dir "!file_path!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo 13: Plik istnieje, ale może być problem z dostępem: !file_path! >&2
            exit /b 13
        )
    )
)

if defined IS_ELEVATED (
    echo X: delegating to win_chown.bat
    "%~dpn0.bat" %*
    exit /b %errorlevel%
)

echo Running as...
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process -Verb RunAs -FilePath '%~dpn0.bat' -ArgumentList '%*' -PassThru; $p.WaitForExit(); exit $p.ExitCode"
if %errorlevel% equ 1223 (
    echo 10: Podniesienie uprawnień anulowane przez użytkownika (UAC, kod 1223)
    exit /b 1223
)
if %errorlevel% neq 0 (
    echo 10: Błąd podczas próby uruchomienia z uprawnieniami administratora
    exit /b %errorlevel%
)

echo ====================================================================>>
echo Zakończono przetwarzanie wszystkich plików pomyślnie.
echo ====================================================================>>
echo Podsumowanie operacji:
echo   - Identyfikator: !id!
echo   - Tryb uprawnień: !mode!
echo   - Plik dziennika: !log_file!
echo   - OKFIN
exit /b 0