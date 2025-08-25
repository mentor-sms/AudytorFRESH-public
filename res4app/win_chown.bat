@echo on
setlocal enabledelayedexpansion
fltmc >nul 2>&1
set "IS_ELEVATED="
if %errorlevel% equ 0 set "IS_ELEVATED=1"
ver >nul 2>&1
set "id=%~2"
if "!id!"=="" (
    exit /b 2
)
set /A num=!id! 2>nul
if not "!num!"=="!id!" (
    exit /b 2
)
if "%~4"=="" (
    exit /b 3
)
set "mode=%~1"
if "!mode!"=="" (
    exit /b 4
)
if /i not "!mode!"=="default" if /i not "!mode!"=="private" if /i not "!mode!"=="root_private" if /i not "!mode!"=="root_public" (
    exit /b 4
)
set "LOG_DIR=%~3"
if "!LOG_DIR!"=="" (
    exit /b 5
)

set "log_file=!LOG_DIR!\cmd_!id!.run.lab.log"
@echo off

echo REV 2.2 BAT>> "!log_file!"

if not defined IS_ELEVATED (
    echo 1: run win_chown.bat>> "!log_file!"
    exit /b 1
)

echo Tryb [mode]: !mode!>> "!log_file!"

set "CURRENT_USER_SID="
if /i "!mode!"=="private" (
    for /f "tokens=2" %%A in ('whoami /user ^| findstr /R "S-1-"') do set "CURRENT_USER_SID=%%A"
    if not defined CURRENT_USER_SID (
        echo 9: Nie udało się uzyskać SID bieżącego użytkownika>> "!log_file!"
        exit /b 9
    )
    echo SID bieżącego użytkownika: !CURRENT_USER_SID!>> "!log_file!"
)
set "arg_index=0"
for /f "usebackq delims=" %%I in (`%ComSpec% /v:on /c for %%G in (^%*^) do @echo(%%~G`) do (
    set /a arg_index+=1
    if !arg_index! geq 4 (
        set "file_path=%%~I"
        if "!file_path!"=="" (
            echo 6: Błąd przed przetwarzaniem pliku>> "!log_file!"
            exit /b 6
        )
        echo Ścieżka wejściowa niepusta: !file_path!>> "!log_file!"
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
            echo 9: Błąd wykonania polecenia icacls dla !file_path!>> "!log_file!"
            exit /b 9
        )
        echo Odczyt ACL udany dla: !file_path!>> "!log_file!"
        echo Resetowanie uprawnień...>> "!log_file!"
        echo Wykonywanie: icacls "!file_path!" /reset>> "!log_file!"
        icacls "!file_path!" /reset >> "!log_file!" 2>&1
        if !errorlevel! neq 0 (
            echo 8: Nie udało się przetworzyć pliku: !file_path!>> "!log_file!"
            exit /b 8
        )
        echo Reset ACL zakończony powodzeniem: !file_path!>> "!log_file!"
        if /i "!mode!"=="default" (
            echo Ustawiono domyślne uprawnienia.
            echo Ustawiono domyślne uprawnienia.>> "!log_file!"
            echo Zastosowano tryb default dla: !file_path!>> "!log_file!"
        ) else (
            if /i "!mode!"=="private" (
                echo Ustawianie prywatnych uprawnień dla bieżącego użytkownika...>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /grant *!CURRENT_USER_SID!:F>> "!log_file!"
                icacls "!file_path!" /grant *!CURRENT_USER_SID!:F >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Nadano uprawnienia F dla SID !CURRENT_USER_SID!: !file_path!>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /setowner *!CURRENT_USER_SID!>> "!log_file!"
                icacls "!file_path!" /setowner *!CURRENT_USER_SID! >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Zmieniono właściciela na !CURRENT_USER_SID!: !file_path!>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F>> "!log_file!"
                icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Wyłączono dziedziczenie i ustawiono F dla !CURRENT_USER_SID!: !file_path!>> "!log_file!"
            ) else (
                echo Ustawianie uprawnień administratora...>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /grant *S-1-5-32-544:F>> "!log_file!"
                icacls "!file_path!" /grant *S-1-5-32-544:F >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Nadano F dla Administratorzy (S-1-5-32-544): !file_path!>> "!log_file!"
                echo Wykonywanie: icacls "!file_path!" /setowner *S-1-5-32-544>> "!log_file!"
                icacls "!file_path!" /setowner *S-1-5-32-544 >> "!log_file!" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "!log_file!"
                    exit /b 8
                )
                echo Zmieniono właściciela na Administratorzy (S-1-5-32-544): !file_path!>> "!log_file!"
                if /i "!mode!"=="root_private" (
                    echo Ustawianie prywatnych uprawnień administratora...>> "!log_file!"
                    echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F>> "!log_file!"
                    icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F >> "!log_file!" 2>&1
                    if !errorlevel! neq 0 (
                        echo 8: Nie udało się przetworzyć pliku: !file_path!>> "!log_file!"
                        exit /b 8
                    )
                    echo Wyłączono dziedziczenie i ustawiono F dla SYSTEM i Administratorzy: !file_path!>> "!log_file!"
                ) else (
                    if /i "!mode!"=="root_public" (
                        echo Ustawianie publicznych uprawnień administratora...>> "!log_file!"
                        echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX>> "!log_file!"
                        icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX >> "!log_file!" 2>&1
                        if !errorlevel! neq 0 (
                            echo 8: Nie udało się przetworzyć pliku: !file_path!>> "!log_file!"
                            exit /b 8
                        )
                        echo Wyłączono dziedziczenie i ustawiono F dla SYSTEM/Administratorzy oraz RX dla Użytkownicy/Auth. użytkownicy: !file_path!>> "!log_file!"
                    )
                )
            )
        )
        echo Koncowe uprawnienia:>> "!log_file!"
        echo Wykonywanie: icacls "!file_path!">> "!log_file!"
        icacls "!file_path!" >> "!log_file!" 2>&1
        if !errorlevel! neq 0 (
            echo 8: Nie udało się przetworzyć pliku: !file_path!>> "!log_file!"
            exit /b 8
        )
        echo Pobrano końcowe ACL bez błędów: !file_path!>> "!log_file!"
        echo Weryfikacja dostępu do pliku...>> "!log_file!"
        if exist "!file_path!" (
            dir "!file_path!" >nul 2>&1
            if !errorlevel! neq 0 (
                echo OSTRZEZENIE: Plik istnieje, ale moze miec problemy z dostepem.>> "!log_file!"
            ) else (
                echo Dostep do pliku zweryfikowany pomyslnie.>> "!log_file!"
            )
        ) else (
            echo 11: Plik przestal istniec po zmianie uprawnien: !file_path!>> "!log_file!"
            exit /b 11
        )
        echo Pomyślnie przetworzono plik: !file_path!>> "!log_file!"
    )
)
echo ====================================================================>> "!log_file!"
echo Zakończono przetwarzanie wszystkich plików pomyślnie.>> "!log_file!"
echo ====================================================================>> "!log_file!"
echo Podsumowanie operacji:>> "!log_file!"
echo   - Identyfikator: !id!>> "!log_file!"
echo   - Tryb uprawnień: !mode!>> "!log_file!"
echo   - OKFIN >> "!log_file!"
exit /b 0