@echo on
setlocal enabledelayedexpansion
fltmc >nul 2>&1
set "IS_ELEVATED="
if %errorlevel% equ 0 set "IS_ELEVATED=1"
ver >nul 2>&1
@echo off

set "id=%~2"
if "!id!"=="" (
    echo 2: >&2
    exit /b 2
)
set /A num=!id! 2>nul
if not "!num!"=="!id!" (
    echo 2: >&2
    exit /b 2
)
if "%~4"=="" (
    echo 3: >&2
    exit /b 3
)
set "mode=%~1"
if "!mode!"=="" (
    echo 4: >&2
    exit /b 4
)
if /i not "!mode!"=="default" if /i not "!mode!"=="private" if /i not "!mode!"=="root_private" if /i not "!mode!"=="root_public" (
    echo 4: >&2
    exit /b 4
)

echo REV 2.2 CMD

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

if defined IS_ELEVATED (
    echo X: runas win_chown.cmd
    exit /b 1
)

echo Dziennik: !LOG_DIR!\cmd_!id![.run].lab.log

echo Identyfikator procesu [id]: !id!
echo Podano tryb [mode]: !mode!

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
