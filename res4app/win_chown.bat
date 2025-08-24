
:: =============================================================================
:: win_chown.bat - Narzędzie do zarządzania uprawnieniami plików repozytoriów
:: =============================================================================
:: Użycie: win_chown.bat [log_dir] [id] [mode] [ścieżki_do_plików, ...]
::
:: Parametry:
::   [log_dir]    - Katalog, w którym zostanie utworzony plik dziennika (win_chown.[id].lab.log)
::   [id]         - Identyfikator numeryczny operacji (używany w nazwie pliku dziennika)
::   [mode]       - Tryb uprawnień do zastosowania
::   [ścieżki]    - Jedna lub więcej ścieżek do plików do przetworzenia
::
:: Dostępne tryby:
::   default      - Przywraca domyślne uprawnienia systemowe
::   private      - Nadaje pełne uprawnienia tylko bieżącemu użytkownikowi
::   root_private - Nadaje uprawnienia tylko administratorowi i systemowi
::   root_public  - Nadaje uprawnienia administratorowi oraz odczyt dla innych
::
:: Przykłady:
::   win_chown.bat 123 private "C:\Repozytorium\tajny.txt"
::   win_chown.bat 456 root_public "C:\Dane\publiczne\*"
::
:: Kody błędów:
::   1  - Błąd inicjalizacji
::   2  - Nieprawidłowy identyfikator
::   3  - Nieprawidłowy tryb
::   4  - Brak ścieżek do plików
::   5-8 - Błędy przetwarzania
::   9  - Błąd wykonania polecenia icacls
::   10 - Błąd podwyższenia uprawnień
::   11 - Błąd weryfikacji dostępu

@echo off
setlocal enabledelayedexpansion
if /i "%~1"=="-elevated" (
    set "IS_ELEVATED=1"
    shift
)
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    if defined IS_ELEVATED (echo UWAGA: Ten skrypt wymaga uprawnień administratora. >> "%log_file%") else (echo UWAGA: Ten skrypt wymaga uprawnień administratora.)
    if defined IS_ELEVATED (echo Próba uruchomienia z podwyższonymi uprawnieniami... >> "%log_file%") else (echo Próba uruchomienia z podwyższonymi uprawnieniami...)
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList '-elevated %*' -Wait"
    if %errorlevel% neq 0 (
        if defined IS_ELEVATED (echo 10: Błąd podczas próby uruchomienia z uprawnieniami administratora >> "%log_file%") else (echo 10: Błąd podczas próby uruchomienia z uprawnieniami administratora >&2)
        exit /b 10
    )
    echo OKFIN
    exit /b 0
)

set "LOG_DIR=%~1"
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
set id=%~2
if "%id%"=="" (
    if defined IS_ELEVATED (echo 2: Nie podano identyfikatora [id] >> "%log_file%") else (echo 2: Nie podano identyfikatora [id] >&2)
    exit /b 2
)

set /A num=%id% 2>nul
if not "%num%"=="%id%" (
    if defined IS_ELEVATED (echo 2: Nieprawidłowy identyfikator [id]: %id% >> "%log_file%") else (echo 2: Nieprawidłowy identyfikator [id]: %id% >&2)
    exit /b 2
)
set "log_file=%LOG_DIR%\win_chown.%id%.lab.log"
if defined IS_ELEVATED (echo Zapisywanie dziennika do pliku: %log_file% >> "%log_file%") else (echo Zapisywanie dziennika do pliku: %log_file%)
set mode=%~3
if "%mode%"=="" (
    if defined IS_ELEVATED (echo 3: Nie podano trybu [mode] >> "%log_file%") else (echo 3: Nie podano trybu [mode] >&2)
    exit /b 3
)

if /i not "%mode%"=="default" if /i not "%mode%"=="private" if /i not "%mode%"=="root_private" if /i not "%mode%"=="root_public" (
    if defined IS_ELEVATED (echo 3: Nieprawidłowy tryb [mode]: %mode% >> "%log_file%") else (echo 3: Nieprawidłowy tryb [mode]: %mode% >&2)
    exit /b 3
)
if "%~4"=="" (
    if defined IS_ELEVATED (echo 4: Nie podano ścieżek do plików >> "%log_file%") else (echo 4: Nie podano ścieżek do plików >&2)
    exit /b 4
)
set "CURRENT_USER_SID="
if /i "%mode%"=="private" (
    for /f "tokens=2" %%A in ('whoami /user ^| findstr /R "S-1-"') do set "CURRENT_USER_SID=%%A"
    if not defined CURRENT_USER_SID (
        if defined IS_ELEVATED (echo 9: Nie udało się uzyskać SID bieżącego użytkownika >> "%log_file%") else (echo 9: Nie udało się uzyskać SID bieżącego użytkownika >&2)
        exit /b 9
    )
)
set /a __arg_idx=0
for %%I in (%*) do (
    set /a __arg_idx+=1
    if !__arg_idx! geq 4 (
        set "file_path=%%~I"
        if "!file_path!"=="" (
            if defined IS_ELEVATED (echo 6: Błąd przed przetwarzaniem pliku >> "%log_file%") else (echo 6: Błąd przed przetwarzaniem pliku >&2)
            exit /b 6
        )
        if defined IS_ELEVATED (echo [win_chown] Przetwarzanie pliku: !file_path! >> "%log_file%") else (echo [win_chown] Przetwarzanie pliku: !file_path!)
        if not exist "!file_path!" (
            if defined IS_ELEVATED (echo 7: Nie znaleziono pliku: !file_path! >> "%log_file%") else (echo 7: Nie znaleziono pliku: !file_path! >&2)
            exit /b 7
        )
        if defined IS_ELEVATED (echo Tryb: %mode% >> "%log_file%") else (echo Tryb: %mode%)
        if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!")
        icacls "!file_path!"
        if !errorlevel! neq 0 (
            if defined IS_ELEVATED (echo 9: Błąd wykonania polecenia icacls dla !file_path! >> "%log_file%") else (echo 9: Błąd wykonania polecenia icacls dla !file_path! >&2)
            exit /b 9
        )
        if defined IS_ELEVATED (echo Resetowanie uprawnień... >> "%log_file%") else (echo Resetowanie uprawnień...)
        if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" /reset >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!" /reset)
        icacls "!file_path!" /reset
        if !errorlevel! neq 0 (
            if defined IS_ELEVATED (echo 8: Nie udało się przetworzyć pliku: !file_path! >> "%log_file%") else (echo 8: Nie udało się przetworzyć pliku: !file_path! >&2)
            exit /b 8
        )
        if /i "%mode%"=="default" (
            if defined IS_ELEVATED (echo Ustawiono domyślne uprawnienia. >> "%log_file%") else (echo Ustawiono domyślne uprawnienia.)
        ) else (
            if /i "%mode%"=="private" (
                if defined IS_ELEVATED (echo Ustawianie prywatnych uprawnień dla bieżącego użytkownika... >> "%log_file%") else (echo Ustawianie prywatnych uprawnień dla bieżącego użytkownika...)
                if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" /grant *!CURRENT_USER_SID!:F >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!" /grant *!CURRENT_USER_SID!:F)
                icacls "!file_path!" /grant *!CURRENT_USER_SID!:F
                if !errorlevel! neq 0 (
                    if defined IS_ELEVATED (echo 8: Nie udało się przetworzyć pliku: !file_path! >> "%log_file%") else (echo 8: Nie udało się przetworzyć pliku: !file_path! >&2)
                    exit /b 8
                )
                if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" /setowner *!CURRENT_USER_SID! >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!" /setowner *!CURRENT_USER_SID!)
                icacls "!file_path!" /setowner *!CURRENT_USER_SID!
                if !errorlevel! neq 0 (
                    if defined IS_ELEVATED (echo 8: Nie udało się przetworzyć pliku: !file_path! >> "%log_file%") else (echo 8: Nie udało się przetworzyć pliku: !file_path! >&2)
                    exit /b 8
                )
                if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F)
                icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F
                if !errorlevel! neq 0 (
                    if defined IS_ELEVATED (echo 8: Nie udało się przetworzyć pliku: !file_path! >> "%log_file%") else (echo 8: Nie udało się przetworzyć pliku: !file_path! >&2)
                    exit /b 8
                )
            ) else (
                if defined IS_ELEVATED (echo Ustawianie uprawnień administratora... >> "%log_file%") else (echo Ustawianie uprawnień administratora...)
                if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" /grant *S-1-5-32-544:F >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!" /grant *S-1-5-32-544:F)
                icacls "!file_path!" /grant *S-1-5-32-544:F
                if !errorlevel! neq 0 (
                    if defined IS_ELEVATED (echo 8: Nie udało się przetworzyć pliku: !file_path! >> "%log_file%") else (echo 8: Nie udało się przetworzyć pliku: !file_path! >&2)
                    exit /b 8
                )
                if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" /setowner *S-1-5-32-544 >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!" /setowner *S-1-5-32-544)
                icacls "!file_path!" /setowner *S-1-5-32-544
                if !errorlevel! neq 0 (
                    if defined IS_ELEVATED (echo 8: Nie udało się przetworzyć pliku: !file_path! >> "%log_file%") else (echo 8: Nie udało się przetworzyć pliku: !file_path! >&2)
                    exit /b 8
                )
                if /i "%mode%"=="root_private" (
                    if defined IS_ELEVATED (echo Ustawianie prywatnych uprawnień administratora... >> "%log_file%") else (echo Ustawianie prywatnych uprawnień administratora...)
                    if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F)
                    icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F
                    if !errorlevel! neq 0 (
                        if defined IS_ELEVATED (echo 8: Nie udało się przetworzyć pliku: !file_path! >> "%log_file%") else (echo 8: Nie udało się przetworzyć pliku: !file_path! >&2)
                        exit /b 8
                    )
                ) else (
                    if /i "%mode%"=="root_public" (
                        if defined IS_ELEVATED (echo Ustawianie publicznych uprawnień administratora... >> "%log_file%") else (echo Ustawianie publicznych uprawnień administratora...)
                        if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX)
                        icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX
                        if !errorlevel! neq 0 (
                            if defined IS_ELEVATED (echo 8: Nie udało się przetworzyć pliku: !file_path! >> "%log_file%") else (echo 8: Nie udało się przetworzyć pliku: !file_path! >&2)
                            exit /b 8
                        )
                    )
                )
            )
        )
        if defined IS_ELEVATED (echo Koncowe uprawnienia: >> "%log_file%") else (echo Koncowe uprawnienia:)
        if defined IS_ELEVATED (echo Wykonywanie: icacls "!file_path!" >> "%log_file%") else (echo Wykonywanie: icacls "!file_path!")
        icacls "!file_path!"
        if !errorlevel! neq 0 (
            if defined IS_ELEVATED (echo 8: Nie udało się przetworzyć pliku: !file_path! >> "%log_file%") else (echo 8: Nie udało się przetworzyć pliku: !file_path! >&2)
            exit /b 8
        )
        if defined IS_ELEVATED (echo Weryfikacja dostępu do pliku... >> "%log_file%") else (echo Weryfikacja dostępu do pliku...)
        if exist "!file_path!" (
            dir "!file_path!" >nul 2>&1
            if !errorlevel! neq 0 (
                if defined IS_ELEVATED (echo OSTRZEZENIE: Plik istnieje, ale moze miec problemy z dostepem. >> "%log_file%") else (echo OSTRZEZENIE: Plik istnieje, ale moze miec problemy z dostepem.)
            ) else (
                if defined IS_ELEVATED (echo Dostep do pliku zweryfikowany pomyslnie. >> "%log_file%") else (echo Dostep do pliku zweryfikowany pomyslnie.)
            )
        ) else (
            if defined IS_ELEVATED (echo 11: Plik przestal istniec po zmianie uprawnien: !file_path! >> "%log_file%") else (echo 11: Plik przestal istniec po zmianie uprawnien: !file_path! >&2)
            exit /b 11
        )
        if defined IS_ELEVATED (echo Pomyślnie przetworzono plik: !file_path! >> "%log_file%") else (echo Pomyślnie przetworzono plik: !file_path!)
    )
)

if defined IS_ELEVATED (echo ==================================================================== >> "%log_file%") else (echo ====================================================================)
if defined IS_ELEVATED (echo Zakończono przetwarzanie wszystkich plików pomyślnie. >> "%log_file%") else (echo Zakończono przetwarzanie wszystkich plików pomyślnie.)
if defined IS_ELEVATED (echo ==================================================================== >> "%log_file%") else (echo ====================================================================)
if defined IS_ELEVATED (echo Podsumowanie operacji: >> "%log_file%") else (echo Podsumowanie operacji:)
if defined IS_ELEVATED (echo   - Identyfikator: %id% >> "%log_file%") else (echo   - Identyfikator: %id%)
if defined IS_ELEVATED (echo   - Tryb uprawnień: %mode% >> "%log_file%") else (echo   - Tryb uprawnień: %mode%)
if defined IS_ELEVATED (echo   - Plik dziennika: %log_file% >> "%log_file%") else (echo   - Plik dziennika: %log_file%)

echo OKFIN >> "%log_file%"
exit 0