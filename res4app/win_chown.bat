@echo on
setlocal enabledelayedexpansion

rem ------ SETUP ------

set "mode=%~1"
set "id=%~2"
set "LOG_DIR=%~3"
set "log_file=!LOG_DIR!\cmd_!id!.run.lab.log"

ver >nul 2>&1
fltmc >nul 2>&1
set "IS_ELEVATED="
if %errorlevel% equ 0 set "IS_ELEVATED=1"
if not defined IS_ELEVATED (
    echo 1: BAT tylko z SUDO, niebezpieczne>> "!log_file!"
    exit /b 1
)
ver >nul 2>&1
echo Dziennik: !LOG_DIR!\cmd_!id!.run.lab.log
@echo off

echo REV 3.0.0 BAT>> "!log_file!"
echo   - Identyfikator: !id!>> "!log_file!"
echo   - Tryb uprawnien: !mode!>> "!log_file!"

set "CURRENT_USER_SID=%~5"
set "ARG_START_IDX=6"
if /i "!mode!"=="private" (
    if not defined CURRENT_USER_SID (
        echo 12: Brak SID (argument 5) wymagany dla trybu private>> "!log_file!"
        exit /b 12
    )
    echo SID biezacego uzytkownika: !CURRENT_USER_SID!>> "!log_file!"
)
set "arg_index=0"

rem ------ SET ------

for /f "usebackq delims=" %%I in (`%ComSpec% /v:on /c for %%G in (^%*^) do @echo(%%~G`) do (
    set /a arg_index+=1
    if !arg_index! geq !ARG_START_IDX! (
        set "file_path=%%~I"
        if "!file_path!"=="" (
            echo 6: Blad przed przetwarzaniem pliku (pusta sciezka)>> "!log_file!"
            exit /b 6
        )
        echo Sciezka wejsciowa niepusta: !file_path!>> "!log_file!"
        echo [win_chown] Przetwarzanie pliku: !file_path!>> "!log_file!"
        if not exist "!file_path!" (
            echo 7: Nie znaleziono pliku: !file_path!>> "!log_file!"
            exit /b 7
        )
        echo Plik istnieje: !file_path!>> "!log_file!"
        echo Tryb: !mode!>> "!log_file!"
        echo Wykonywanie: icacls "!file_path!">> "!log_file!"
        icacls "!file_path!" >> "!log_file!" 2>&1
        if !errorlevel! neq 0 (
            echo 9: Blad odczytu ACL (icacls) dla: !file_path!>> "!log_file!"
            exit /b 9
        )
        echo Odczyt ACL udany dla: !file_path!>> "!log_file!"
        echo Resetowanie uprawnien..>> "!log_file!"
        echo Wykonywanie: icacls "!file_path!" /reset>> "!log_file!"
        icacls "!file_path!" /reset >> "!log_file!" 2>&1
        if !errorlevel! neq 0 (
            echo 8: Nie udalo sie przetworzyc pliku: !file_path!>> "!log_file!"
            exit /b 8
        )
        echo Reset ACL zakonczony powodzeniem: !file_path!>> "!log_file!"
        if /i "!mode!"=="default" (
            echo Ustawiono domyslne uprawnienia>> "!log_file!"
            echo Zastosowano tryb default dla: !file_path!>> "!log_file!"
        ) else (
            if /i "!mode!"=="private" (
                echo Ustawianie prywatnych uprawnien dla biezacego uzytkownika..>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /grant *!CURRENT_USER_SID!:F>> "!log_file!"
                icacls "!file_path!" /grant *!CURRENT_USER_SID!:F >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udalo sie przetworzyc pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Nadano uprawnienia F dla SID !CURRENT_USER_SID!: !file_path!>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /setowner *!CURRENT_USER_SID!>> "!log_file!"
                icacls "!file_path!" /setowner *!CURRENT_USER_SID! >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udalo sie przetworzyc pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Zmieniono wlasciciela na !CURRENT_USER_SID!: !file_path!>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F>> "!log_file!"
                icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udalo sie przetworzyc pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Wylaczono dziedziczenie i ustawiono F dla !CURRENT_USER_SID!: !file_path!>> "!log_file!"
            ) else (
                echo Ustawianie uprawnien administratora..>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /grant *S-1-5-32-544:F>> "!log_file!"
                icacls "!file_path!" /grant *S-1-5-32-544:F >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udalo sie przetworzyc pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Nadano F dla Administratorzy (S-1-5-32-544): !file_path!>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /setowner *S-1-5-32-544>> "!log_file!"
                icacls "!file_path!" /setowner *S-1-5-32-544 >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udalo sie przetworzyc pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Zmieniono wlasciciela na Administratorzy (S-1-5-32-544): !file_path!>> "!log_file!"
                if /i "!mode!"=="root_private" (
                    echo Ustawianie prywatnych uprawnien administratora..>> "!log_file!"
                    echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F>> "!log_file!"
                    icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F >> "!log_file!" 2>&1
                    if !errorlevel! neq 0 (
                        echo 8: Nie udalo sie przetworzyc pliku: !file_path!>> "!log_file!"
                        exit /b 8
                    )
                    echo Wylaczono dziedziczenie i ustawiono F dla SYSTEM i Administratorzy: !file_path!>> "!log_file!"
                ) else (
                    if /i "!mode!"=="root_public" (
                        echo Ustawianie publicznych uprawnien administratora..>> "!log_file!"
                        echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX>> "!log_file!"
                        icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX >> "!log_file!" 2>&1
                        if !errorlevel! neq 0 (
                            echo 8: Nie udalo sie przetworzyc pliku: !file_path!>> "!log_file!"
                            exit /b 8
                        )
                        echo Wylaczono dziedziczenie i ustawiono F dla SYSTEM/Administratorzy oraz RX dla Uzytkownicy/Auth. uzytkownicy: !file_path!>> "!log_file!"
                    )
                )
            )
        )
        echo Koncowe uprawnienia:>> "!log_file!"
        echo Wykonywanie: icacls "!file_path!">> "!log_file!"
        icacls "!file_path!" >> "!log_file!" 2>&1
        if !errorlevel! neq 0 (
            echo 8: Nie udalo sie przetworzyc pliku: !file_path!>> "!log_file!"
            exit /b 8
        )
        echo Pobrano koncowe ACL bez bledow: !file_path!>> "!log_file!"
        echo Weryfikacja dostepu do pliku..>> "!log_file!"
        if exist "!file_path!" (
            dir "!file_path!" >nul 2>&1
            if !errorlevel! neq 0 (
                echo OSTRZEZENIE: Plik istnieje, ale moze miec problemy z dostepem>> "!log_file!"
            ) else (
                echo Dostep do pliku zweryfikowany pomyslnie>> "!log_file!"
            )
        ) else (
            echo 11: Plik przestal istniec po zmianie uprawnien: !file_path!>> "!log_file!"
            exit /b 11
        )
        echo Pomyslnie przetworzono plik: !file_path!>> "!log_file!"
    )
)

rem ------ FIN ------

echo(
echo Podsumowanie operacji:>> "!log_file!"
echo   - Identyfikator: !id!>> "!log_file!"
echo   - Tryb uprawnien: !mode!>> "!log_file!"
echo   - OKFIN>> "!log_file!"
exit /b 0 rem return to CMD