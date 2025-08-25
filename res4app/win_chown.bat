@echo off
setlocal enabledelayedexpansion

echo REV 2.0

set "id=%~2"
if "%id%"=="" (
    echo 2: Nie podano identyfikatora [id]
    exit /b 2
)
echo Podano identyfikator [id]: %id%
set /A num=%id% 2>nul
if not "%num%"=="%id%" (
    echo 2: Nieprawidłowy identyfikator [id]: %id%
    exit /b 2
)
echo Identyfikator [id] jest liczbą: %id%
if "%~4"=="" (
    echo 4: Nie podano ścieżek do plików
    exit /b 4
)

set "LOG_DIR=%~3"
if "%LOG_DIR%"=="" (
    echo 1: Nie podano katalogu dla pliku dziennika >&2
    exit /b 1
)
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%" >nul 2>&1
    if %errorlevel% neq 0 (
        echo 1: Nie można utworzyć katalogu dziennika: "%LOG_DIR%" >&2
        exit /b 1
    )
)

set "log_file=%LOG_DIR%\cmd_%id%.lab.log"
echo Zapisywanie dziennika do pliku: %log_file%
echo Zapisywanie dziennika do pliku: %log_file%>> "%log_file%"

echo Podano identyfikator [id]: %id%>> "%log_file%"
echo Identyfikator [id] jest liczbą: %id%>> "%log_file%"

fltmc >nul 2>&1
set "IS_ELEVATED="
if %errorlevel% equ 0 set "IS_ELEVATED=1"
ver >nul 2>&1

set "mode=%~1"
if "%mode%"=="" (
    echo 3: Nie podano trybu [mode]
    echo 3: Nie podano trybu [mode]>> "%log_file%"
    exit /b 3
)
echo Podano tryb [mode]: %mode%
echo Podano tryb [mode]: %mode%>> "%log_file%"

set "base_mode=%mode%"
set "SKIP_ELEVATE="
if /i "%mode:~0,9%"=="elevated_" (
    set "SKIP_ELEVATE=1"
    set "base_mode=%mode:~9%"
)
if /i not "%base_mode%"=="default" if /i not "%base_mode%"=="private" if /i not "%base_mode%"=="root_private" if /i not "%base_mode%"=="root_public" (
    echo 3: Nieprawidłowy tryb [mode]: %mode%
    echo 3: Nieprawidłowy tryb [mode]: %mode%>> "%log_file%"
    exit /b 3
)
echo Tryb bazowy [base_mode]: %base_mode% (SKIP_ELEVATE=%SKIP_ELEVATE%)
echo Tryb bazowy [base_mode]: %base_mode% (SKIP_ELEVATE=%SKIP_ELEVATE%)>> "%log_file%"
if not defined IS_ELEVATED (
    if not defined SKIP_ELEVATE (
        echo Próba uruchomienia z podwyższonymi uprawnieniami...
        echo Próba uruchomienia z podwyższonymi uprawnieniami...>> "%log_file%"
        PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList '%*' -PassThru; $p.WaitForExit(); exit $p.ExitCode"
        if %errorlevel% equ 1223 (
            echo 10: Podniesienie uprawnień anulowane przez użytkownika (UAC, kod 1223)
            echo 10: Podniesienie uprawnień anulowane przez użytkownika (UAC, kod 1223)>> "%log_file%"
            exit /b 1223
        )
        if %errorlevel% neq 0 (
            echo 10: Błąd podczas próby uruchomienia z uprawnieniami administratora
            echo 10: Błąd podczas próby uruchomienia z uprawnieniami administratora>> "%log_file%"
            exit /b %errorlevel%
        )
        echo OKFIN
        exit /b 0
    )
)
echo Status uprawnień: IS_ELEVATED=%IS_ELEVATED%, SKIP_ELEVATE=%SKIP_ELEVATE%
echo Status uprawnień: IS_ELEVATED=%IS_ELEVATED%, SKIP_ELEVATE=%SKIP_ELEVATE%>> "%log_file%"

echo Podano ścieżki do plików (co najmniej jedną).
echo Podano ścieżki do plików (co najmniej jedną).>> "%log_file%"
set "CURRENT_USER_SID="
if /i "%base_mode%"=="private" (
    for /f "tokens=2" %%A in ('whoami /user ^| findstr /R "S-1-"') do set "CURRENT_USER_SID=%%A"
    if not defined CURRENT_USER_SID (
        echo 9: Nie udało się uzyskać SID bieżącego użytkownika
        echo 9: Nie udało się uzyskać SID bieżącego użytkownika>> "%log_file%"
        exit /b 9
    )
    echo SID bieżącego użytkownika: !CURRENT_USER_SID!
    echo SID bieżącego użytkownika: !CURRENT_USER_SID!>> "%log_file%"
)
set "arg_index=0"
for /f "usebackq delims=" %%I in (`%ComSpec% /v:on /c for %%G in (^%*^) do @echo(%%~G`) do (
    set /a arg_index+=1
    if !arg_index! geq 4 (
        set "file_path=%%~I"
        if "!file_path!"=="" (
            echo 6: Błąd przed przetwarzaniem pliku
            echo 6: Błąd przed przetwarzaniem pliku>> "%log_file%"
            exit /b 6
        )
        echo Ścieżka wejściowa niepusta: !file_path!
        echo Ścieżka wejściowa niepusta: !file_path!>> "%log_file%"
        echo [win_chown] Przetwarzanie pliku: !file_path!
        echo [win_chown] Przetwarzanie pliku: !file_path!>> "%log_file%"
        if not exist "!file_path!" (
            echo 7: Nie znaleziono pliku: !file_path!
            echo 7: Nie znaleziono pliku: !file_path!>> "%log_file%"
            exit /b 7
        )
        echo Plik istnieje: !file_path!
        echo Plik istnieje: !file_path!>> "%log_file%"
        echo Tryb: %base_mode%
        echo Tryb: %base_mode%>> "%log_file%"
        echo Wykonywanie: icacls "!file_path!"
        echo Wykonywanie: icacls "!file_path!">> "%log_file%"
        icacls "!file_path!" >> "%log_file%" 2>&1
        if !errorlevel! neq 0 (
            echo 9: Błąd wykonania polecenia icacls dla !file_path!
            echo 9: Błąd wykonania polecenia icacls dla !file_path!>> "%log_file%"
            exit /b 9
        )
        echo Odczyt ACL udany dla: !file_path!
        echo Odczyt ACL udany dla: !file_path!>> "%log_file%"
        echo Resetowanie uprawnień...
        echo Resetowanie uprawnień...>> "%log_file%"
        echo Wykonywanie: icacls "!file_path!" /reset
        echo Wykonywanie: icacls "!file_path!" /reset>> "%log_file%"
        icacls "!file_path!" /reset >> "%log_file%" 2>&1
        if !errorlevel! neq 0 (
            echo 8: Nie udało się przetworzyć pliku: !file_path!
            echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
            exit /b 8
        )
        echo Reset ACL zakończony powodzeniem: !file_path!
        echo Reset ACL zakończony powodzeniem: !file_path!>> "%log_file%"
        if /i "%base_mode%"=="default" (
            echo Ustawiono domyślne uprawnienia.
            echo Ustawiono domyślne uprawnienia.>> "%log_file%"
            echo Zastosowano tryb default dla: !file_path!
            echo Zastosowano tryb default dla: !file_path!>> "%log_file%"
        ) else (
            if /i "%base_mode%"=="private" (
                echo Ustawianie prywatnych uprawnień dla bieżącego użytkownika...
                echo Ustawianie prywatnych uprawnień dla bieżącego użytkownika...>> "%log_file%"
                echo Wykonywanie: icacls "!file_path!" /grant *!CURRENT_USER_SID!:F
                echo Wykonywanie: icacls "!file_path!" /grant *!CURRENT_USER_SID!:F>> "%log_file%"
                icacls "!file_path!" /grant *!CURRENT_USER_SID!:F >> "%log_file%" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                    exit /b 8
                )
                echo Nadano uprawnienia F dla SID !CURRENT_USER_SID!: !file_path!
                echo Nadano uprawnienia F dla SID !CURRENT_USER_SID!: !file_path!>> "%log_file%"
                echo Wykonywanie: icacls "!file_path!" /setowner *!CURRENT_USER_SID!
                echo Wykonywanie: icacls "!file_path!" /setowner *!CURRENT_USER_SID!>> "%log_file%"
                icacls "!file_path!" /setowner *!CURRENT_USER_SID! >> "%log_file%" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                    exit /b 8
                )
                echo Zmieniono właściciela na !CURRENT_USER_SID!: !file_path!
                echo Zmieniono właściciela na !CURRENT_USER_SID!: !file_path!>> "%log_file%"
                echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F
                echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F>> "%log_file%"
                icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F >> "%log_file%" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                    exit /b 8
                )
                echo Wyłączono dziedziczenie i ustawiono F dla !CURRENT_USER_SID!: !file_path!
                echo Wyłączono dziedziczenie i ustawiono F dla !CURRENT_USER_SID!: !file_path!>> "%log_file%"
            ) else (
                echo Ustawianie uprawnień administratora...
                echo Ustawianie uprawnień administratora...>> "%log_file%"
                echo Wykonywanie: icacls "!file_path!" /grant *S-1-5-32-544:F
                echo Wykonywanie: icacls "!file_path!" /grant *S-1-5-32-544:F>> "%log_file%"
                icacls "!file_path!" /grant *S-1-5-32-544:F >> "%log_file%" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                    exit /b 8
                )
                echo Nadano F dla Administratorzy (S-1-5-32-544): !file_path!
                echo Nadano F dla Administratorzy (S-1-5-32-544): !file_path!>> "%log_file%"
                echo Wykonywanie: icacls "!file_path!" /setowner *S-1-5-32-544
                echo Wykonywanie: icacls "!file_path!" /setowner *S-1-5-32-544>> "%log_file%"
                icacls "!file_path!" /setowner *S-1-5-32-544 >> "%log_file%" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                    exit /b 8
                )
                echo Zmieniono właściciela na Administratorzy (S-1-5-32-544): !file_path!
                echo Zmieniono właściciela na Administratorzy (S-1-5-32-544): !file_path!>> "%log_file%"
                if /i "%base_mode%"=="root_private" (
                    echo Ustawianie prywatnych uprawnień administratora...
                    echo Ustawianie prywatnych uprawnień administratora...>> "%log_file%"
                    echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F
                    echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F>> "%log_file%"
                    icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F >> "%log_file%" 2>&1
                    if !errorlevel! neq 0 (
                        echo 8: Nie udało się przetworzyć pliku: !file_path!
                        echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                        exit /b 8
                    )
                    echo Wyłączono dziedziczenie i ustawiono F dla SYSTEM i Administratorzy: !file_path!
                    echo Wyłączono dziedziczenie i ustawiono F dla SYSTEM i Administratorzy: !file_path!>> "%log_file%"
                ) else (
                    if /i "%base_mode%"=="root_public" (
                        echo Ustawianie publicznych uprawnień administratora...
                        echo Ustawianie publicznych uprawnień administratora...>> "%log_file%"
                        echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX
                        echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX>> "%log_file%"
                        icacls "!file_path!" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX >> "%log_file%" 2>&1
                        if !errorlevel! neq 0 (
                            echo 8: Nie udało się przetworzyć pliku: !file_path!
                            echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                            exit /b 8
                        )
                        echo Wyłączono dziedziczenie i ustawiono F dla SYSTEM/Administratorzy oraz RX dla Użytkownicy/Auth. użytkownicy: !file_path!
                        echo Wyłączono dziedziczenie i ustawiono F dla SYSTEM/Administratorzy oraz RX dla Użytkownicy/Auth. użytkownicy: !file_path!>> "%log_file%"
                    )
                )
            )
        )
        echo Koncowe uprawnienia:
        echo Koncowe uprawnienia:>> "%log_file%"
        echo Wykonywanie: icacls "!file_path!"
        echo Wykonywanie: icacls "!file_path!">> "%log_file%"
        icacls "!file_path!" >> "%log_file%" 2>&1
        if !errorlevel! neq 0 (
            echo 8: Nie udało się przetworzyć pliku: !file_path!
            echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
            exit /b 8
        )
        echo Pobrano końcowe ACL bez błędów: !file_path!
        echo Pobrano końcowe ACL bez błędów: !file_path!>> "%log_file%"
        echo Weryfikacja dostępu do pliku...
        echo Weryfikacja dostępu do pliku...>> "%log_file%"
        if exist "!file_path!" (
            dir "!file_path!" >nul 2>&1
            if !errorlevel! neq 0 (
                echo OSTRZEZENIE: Plik istnieje, ale moze miec problemy z dostepem.
                echo OSTRZEZENIE: Plik istnieje, ale moze miec problemy z dostepem.>> "%log_file%"
            ) else (
                echo Dostep do pliku zweryfikowany pomyslnie.
                echo Dostep do pliku zweryfikowany pomyslnie.>> "%log_file%"
            )
        ) else (
            echo 11: Plik przestal istniec po zmianie uprawnien: !file_path!
            echo 11: Plik przestal istniec po zmianie uprawnien: !file_path!>> "%log_file%"
            exit /b 11
        )
        echo Pomyślnie przetworzono plik: !file_path!
        echo Pomyślnie przetworzono plik: !file_path!>> "%log_file%"
    )
)
echo ====================================================================
echo Zakończono przetwarzanie wszystkich plików pomyślnie.
echo ====================================================================
echo Podsumowanie operacji:
echo   - Identyfikator: %id%
echo   - Tryb uprawnień: %mode%
echo   - Plik dziennika: %log_file%
echo ====================================================================>> "%log_file%"
echo Zakończono przetwarzanie wszystkich plików pomyślnie.>> "%log_file%"
echo ====================================================================>> "%log_file%"
echo Podsumowanie operacji:>> "%log_file%"
echo   - Identyfikator: %id%>> "%log_file%"
echo   - Tryb uprawnień: %mode%>> "%log_file%"
echo   - Plik dziennika: %log_file%>> "%log_file%"
echo   - OKFIN >> "%log_file%"
echo OKFIN
exit /b 0