
:: =============================================================================
:: repo_keys.bat - Narzędzie do zarządzania uprawnieniami plików repozytoriów
:: =============================================================================
:: Użycie: repo_keys.bat [id] [mode] [ścieżki_do_plików, ...]
::
:: Parametry:
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
::   repo_keys.bat 123 private "C:\Repozytorium\tajny.txt"
::   repo_keys.bat 456 root_public "C:\Dane\publiczne\*"
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
    echo UWAGA: Ten skrypt wymaga uprawnień administratora.
    echo Próba uruchomienia z podwyższonymi uprawnieniami...
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList '-elevated %*' -WorkingDirectory '%CD%' -Wait"
    if %errorlevel% neq 0 (
        echo 10: Błąd podczas próby uruchomienia z uprawnieniami administratora >&2
        exit /b 10
    )
    exit /b 0
)
set id=%~1
if "%id%"=="" (
    echo 2: Nie podano identyfikatora [id] >&2
    exit /b 2
)
set /A num=%id% 2>nul
if not "%num%"=="%id%" (
    echo 2: Nieprawidłowy identyfikator [id]: %id% >&2
    exit /b 2
)
set "log_file=%CD%\repo_keys.%id%.lab.log"
echo Zapisywanie dziennika do pliku: %log_file%
set mode=%~2
if "%mode%"=="" (
    echo 3: Nie podano trybu [mode] >&2
    exit /b 3
)
if /i not "%mode%"=="default" if /i not "%mode%"=="private" if /i not "%mode%"=="root_private" if /i not "%mode%"=="root_public" (
    echo 3: Nieprawidłowy tryb [mode]: %mode% >&2
    exit /b 3
)
if "%~3"=="" (
    echo 4: Nie podano ścieżek do plików >&2
    exit /b 4
)
set "CURRENT_USER_SID="
if /i "%mode%"=="private" (
    for /f "tokens=2" %%A in ('whoami /user ^| findstr /R "S-1-"') do set "CURRENT_USER_SID=%%A"
    if not defined CURRENT_USER_SID (
        echo 9: Nie udało się uzyskać SID bieżącego użytkownika >&2
        exit /b 9
    )
)
set /a __arg_idx=0
for %%I in (%*) do (
    set /a __arg_idx+=1
    if !__arg_idx! geq 3 (
        set "file_path=%%~I"
        if "!file_path!"=="" (
            echo 6: Błąd przed przetwarzaniem pliku >&2
            exit /b 6
        )
        echo [repo_keys] Przetwarzanie pliku: !file_path!
        if not exist "!file_path!" (
            echo 7: Nie znaleziono pliku: !file_path! >&2
            exit /b 7
        )
        echo Tryb: %mode%
        echo Wykonywanie: icacls "!file_path!"
        icacls "!file_path!"
        if !errorlevel! neq 0 (
            echo 9: Błąd wykonania polecenia icacls dla !file_path! >&2
            exit /b 9
        )
        echo Resetowanie uprawnień...
        echo Wykonywanie: icacls "!file_path!" /reset
        icacls "!file_path!" /reset
        if !errorlevel! neq 0 (
            echo 8: Nie udało się przetworzyć pliku: !file_path! >&2
            exit /b 8
        )
        if /i "%mode%"=="default" (
            echo Ustawiono domyślne uprawnienia.
        ) else (
            if /i "%mode%"=="private" (
                echo Ustawianie prywatnych uprawnień dla bieżącego użytkownika...
                echo Wykonywanie: icacls "!file_path!" /grant *!CURRENT_USER_SID!:F
                icacls "!file_path!" /grant *!CURRENT_USER_SID!:F
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path! >&2
                    exit /b 8
                )
                echo Wykonywanie: icacls "!file_path!" /setowner *!CURRENT_USER_SID!
                icacls "!file_path!" /setowner *!CURRENT_USER_SID!
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path! >&2
                    exit /b 8
                )
                echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F
                icacls "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path! >&2
                    exit /b 8
                )
            ) else (
                echo Ustawianie uprawnień administratora...
                echo Wykonywanie: icacls "!file_path!" /grant *S-1-5-32-544:F
                icacls "!file_path!" /grant *S-1-5-32-544:F
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path! >&2
                    exit /b 8
                )
                echo Wykonywanie: icacls "!file_path!" /setowner *S-1-5-32-544
                icacls "!file_path!" /setowner *S-1-5-32-544
                if !errorlevel! neq 0 (
                    echo 8: Nie udało się przetworzyć pliku: !file_path! >&2
                    exit /b 8
                )
                if /i "%mode%"=="root_private" (
                    echo Ustawianie prywatnych uprawnień administratora...
                    echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F
                    icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F
                    if !errorlevel! neq 0 (
                        echo 8: Nie udało się przetworzyć pliku: !file_path! >&2
                        exit /b 8
                    )
                ) else (
                    if /i "%mode%"=="root_public" (
                        echo Ustawianie publicznych uprawnień administratora...
                        echo Wykonywanie: icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX
                        icacls "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX
                        if !errorlevel! neq 0 (
                            echo 8: Nie udało się przetworzyć pliku: !file_path! >&2
                            exit /b 8
                        )
                    )
                )
            )
        )
        echo Koncowe uprawnienia:
        echo Wykonywanie: icacls "!file_path!"
        icacls "!file_path!"
        if !errorlevel! neq 0 (
            echo 8: Nie udało się przetworzyć pliku: !file_path! >&2
            exit /b 8
        )
        echo Weryfikacja dostępu do pliku...
        if exist "!file_path!" (
            dir "!file_path!" >nul 2>&1
            if !errorlevel! neq 0 (
                echo OSTRZEZENIE: Plik istnieje, ale moze miec problemy z dostepem.
            ) else (
                echo Dostep do pliku zweryfikowany pomyslnie.
            )
        ) else (
            echo 11: Plik przestal istniec po zmianie uprawnien: !file_path! >&2
            exit /b 11
        )
        echo Pomyślnie przetworzono plik: !file_path!
    )
)

(
    echo ====================================================================
    echo Zakończono przetwarzanie wszystkich plików pomyślnie.
    echo ====================================================================
    echo Podsumowanie operacji:
    echo  - Identyfikator: %id%
    echo  - Tryb uprawnień: %mode%
    echo  - Plik dziennika: %log_file%
) >> "%log_file%"

echo ====================================================================
echo Zakończono przetwarzanie wszystkich plików pomyślnie.
echo ====================================================================
echo Podsumowanie operacji:
echo  - Identyfikator: %id%
echo  - Tryb uprawnień: %mode%
echo  - Plik dziennika: %log_file%

echo OKFIN
exit 0