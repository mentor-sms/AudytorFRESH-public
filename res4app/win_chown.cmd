
@echo off
setlocal disabledelayedexpansion
if "%~1"=="" (
    echo 11 Brak trybu (argument 1) Dozwolone default, private, root_private, root_public >&2
    exit /b 11
)
set "mode=%~1"
set /A __num=0+%~2 2>nul
if not "%__num%"=="%~2" (
    echo 13 Brak lub nieliczbowy identyfikator (argument 2 ID) >&2
    exit /b 13
)
set "id=%~2"
if "%~3"=="" (
    echo 14 Brak katalogu logow (argument 3) >&2
    exit /b 14
)
set "LOG_DIR=%~3"
if "%~6"=="" (
    echo 15 Brak sciezek plikow do przetworzenia (od argumentu 6) >&2
    exit /b 15
)
setlocal enabledelayedexpansion
if /i "!mode!"=="private" (
    if "%~5"=="" (
        echo 16 Brak SID (argument 5) wymagany dla trybu private >&2
        exit /b 16
    )
    set "SID_ARG=%~5"
)
set "log_file=!LOG_DIR!\cmd_!id!.run.lab.log"
echo "REV 3.0.0 CMD"
echo(
rem echo Polecenie "%~f0" %*
rem echo Rozruch %cmdcmdline%
echo(
echo Docelowe uprawnienia [tryb] !mode!
rem echo Dziennik "!LOG_DIR!\cmd_!id!.run.lab.log"
ver >nul 2>&1
echo(
echo Testy argumentow dla BAT
if /i not "!mode!"=="default" if /i not "!mode!"=="private" if /i not "!mode!"=="root_private" if /i not "!mode!"=="root_public" (
    echo 12 Nieprawidlowy tryb (argument 1) Dozwolone default, private, root_private, root_public >&2
    exit /b 12
)
echo Tryb !mode!
set "ARG_START_IDX=6"
set "ARG_INDEX=0"
set "FILE_CNT=0"
set "PS_ARGS="
for %%A in (%*) do (
    set /a ARG_INDEX+=1
    set "CUR_ARG=%%~A"
    set "CUR_ESC=!CUR_ARG:'='''!"
    if defined PS_ARGS (
        set "PS_ARGS=!PS_ARGS!,'!CUR_ESC!'"
    ) else (
        set "PS_ARGS='!CUR_ESC!'"
    )
    if !ARG_INDEX! geq !ARG_START_IDX! (
        set /a FILE_CNT+=1
        set "FILE_!FILE_CNT!=!CUR_ARG!"
        if "!CUR_ARG!"=="" (
            echo 21 Blad przed przetwarzaniem pliku (pusta sciezka) >&2
            exit /b 21
        )
        if not exist "!CUR_ARG!" (
            echo 22 Nie znaleziono pliku !CUR_ARG! >&2
            exit /b 22
        )
        icacls "!CUR_ARG!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo 23 Blad odczytu ACL (icacls) dla !CUR_ARG! >&2
            exit /b 23
        )
        dir "!CUR_ARG!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo 24 Plik istnieje, ale moze byc problem z dostepem !CUR_ARG! >&2
            exit /b 24
        )
        echo Plik !CUR_ARG!
    )
)
echo(
echo Uruchamianie BAT
setlocal DisableDelayedExpansion
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$a = @(%PS_ARGS%); $p = Start-Process -Verb RunAs -FilePath '%~dpn0.bat' -ArgumentList $a -PassThru; $p.WaitForExit(); exit $p.ExitCode"
if errorlevel 1224 (
    echo(
    echo [/BAT]
    echo 31 Nie udalo sie uruchomic procesu z uprawnieniami administratora >&2
    exit /b 31
) else if errorlevel 1223 (
    echo 32 Podniesienie uprawnien anulowane przez uzytkownika (UAC) >&2
    exit /b 32
) else if errorlevel 1 (
    set "RC=%errorlevel%"
    echo(
    echo [/BAT]
    echo %RC% Proces BAT zakonczyl sie kodem bledu %RC% >&2
    exit /b %RC%
)
endlocal
echo [/BAT]
echo(
echo Podsumowanie operacji
echo     Identyfikator !id!
echo     Tryb uprawnien !mode!
echo     Plik dziennika !log_file!
echo     OKFIN
echo(
echo 30 sekund do samobojstwa
timeout /t 30 /nobreak >nul
exit /b 0