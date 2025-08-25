@echo off
setlocal enabledelayedexpansion

echo REV 2.0

fltmc >nul 2>&1
set "IS_ELEVATED="
if %errorlevel% equ 0 set "IS_ELEVATED=1"
ver >nul 2>&1
set "id=%~2"
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
set "mode=%~1"
if "%mode%"=="" (
    echo 3: Nie podano trybu [mode]
    echo 3: Nie podano trybu [mode]>> "%log_file%"
    exit /b 3
)
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
if "%id%"=="" (
    echo 2: Nie podano identyfikatora [id]
    echo 2: Nie podano identyfikatora [id]>> "%log_file%"
    exit /b 2
)
set /A num=%id% 2>nul
if not "%num%"=="%id%" (
    echo 2: Nieprawidłowy identyfikator [id]: %id%
    echo 2: Nieprawidłowy identyfikator [id]: %id%>> "%log_file%"
    exit /b 2
)
if "%~4"=="" (
    echo 4: Nie podano ścieżek do plików
    echo 4: Nie podano ścieżek do plików>> "%log_file%"
    exit /b 4
)
set "CURRENT_USER_SID="
if /i "%base_mode%"=="private" (
    for /f "tokens=2" %%A in ('whoami /user ^| findstr /R "S-1-"') do set "CURRENT_USER_SID=%%A"
    if not defined CURRENT_USER_SID (
        echo 9: Nie udało się uzyskać SID bieżącego użytkownika
        echo 9: Nie udało się uzyskać SID bieżącego użytkownika>> "%log_file%"
        exit /b 9
    )
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
        echo [win_chown] Przetwarzanie pliku: !file_path!
        echo [win_chown] Przetwarzanie pliku: !file_path!>> "%log_file%"
        if not exist "!file_path!" (
            echo 7: Nie znaleziono pliku: !file_path!
            echo 7: Nie znaleziono pliku: !file_path!>> "%log_file%"
            exit /b 7
        )
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
        if /i "%base_mode%"=="default" (
            echo Ustawiono domyślne uprawnienia.
            echo Ustawiono domyślne uprawnienia.>> "%log_file%"
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
                echo Wykonywanie: icacls "!file_path!" /setowner *!CURRENT_USER_SID!
                echo Wykonywanie: icacls "!file_path!" /setowner *!CURRENT_USER_SID!>> "%log_file%"
                icacls "!file_path!" /setowner *!CURRENT_USER_SID! >> "%log_file%" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                    exit /b 8
                )
                echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F
                echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F>> "%log_file%"
                icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F >> "%log_file%" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                    exit /b 8
                )
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
                echo Wykonywanie: icacls "!file_path!" /setowner *S-1-5-32-544
                echo Wykonywanie: icacls "!file_path!" /setowner *S-1-5-32-544>> "%log_file%"
                icacls "!file_path!" /setowner *S-1-5-32-544 >> "%log_file%" 2>&1
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path!
                    echo 8: Nie udało się przetworzyć pliku: !file_path!>> "%log_file%"
                    exit /b 8
                )
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
exit /b 0