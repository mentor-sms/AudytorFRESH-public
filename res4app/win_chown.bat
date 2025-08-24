@echo off
setlocal enabledelayedexpansion
if /i "%~1"=="-elevated" (
    set "IS_ELEVATED=1"
    shift
)

::=============================================================================
:: repo_keys.bat - Narzędzie do zarządzania uprawnieniami plików repozytoriów
::=============================================================================
:: Użycie: repo_keys.bat [id] [mode] [ścieżki_do_plików, ...]
:: Tryby: default, private, root_private, root_public
::=============================================================================

:: Sprawdź uprawnienia administratora
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    echo UWAGA: Ten skrypt wymaga uprawnień administratora.
    echo Próba uruchomienia z podwyższonymi uprawnieniami...
    call :run_elevated %*
    exit /b
)

:: Walidacja identyfikatora
set id=%~1
if "%id%"=="" (
    call :end_with_error 2 "Nie podano identyfikatora [id]" usage
)
set /A num=%id% 2>nul
if not "%num%"=="%id%" (
    call :end_with_error 2 "Nieprawidłowy identyfikator [id]: %id%" usage
)

:: Konfiguracja pliku dziennika
set "log_file=%~dp0repo_keys.%id%.lab.log"
echo Zapisywanie dziennika do pliku: %log_file%
shift

:: Walidacja trybu
set mode=%~1
if "%mode%"=="" (
    call :end_with_error 3 "Nie podano trybu [mode]" usage
)
if /i not "%mode%"=="default" if /i not "%mode%"=="private" if /i not "%mode%"=="root_private" if /i not "%mode%"=="root_public" (
    call :end_with_error 3 "Nieprawidłowy tryb [mode]: %mode%" usage
)
shift

:: Sprawdź czy podano ścieżki do plików
if "%~1"=="" (
    call :end_with_error 4 "Nie podano ścieżek do plików" usage
)

:process_files
(
    :: Sprawdź błędy przed przetwarzaniem pliku
    if !errorlevel! neq 0 (
        call :end_with_error 6 "Błąd przed przetwarzaniem pliku"
    )

    :: Pobierz ścieżkę do pliku i sprawdź czy nie jest pusta
    set "file_path=%~1"
    if "!file_path!"=="" goto :happy_end
    echo [repo_keys] Przetwarzanie pliku: !file_path!

    :: Sprawdź czy plik istnieje
    if not exist "!file_path!" (
        call :end_with_error 7 "Nie znaleziono pliku: !file_path!"
    )

    echo Tryb: !mode!

    :: Pokaż aktualne uprawnienia
    call :run_cmd "!file_path!"

    :: Zresetuj uprawnienia
    echo Resetowanie uprawnień...
    call :run_cmd "!file_path!" /reset
    if !errorlevel! neq 0 call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"

    :: Ustaw uprawnienia w zależności od trybu
    if "!mode!"=="default" (
        echo Ustawiono domyślne uprawnienia.
    ) else (
        if "!mode!"=="private" (
            echo Ustawianie prywatnych uprawnień dla bieżącego użytkownika...
            call :ensure_current_user_sid
            call :run_cmd "!file_path!" /grant *!CURRENT_USER_SID!:F
            if !errorlevel! neq 0 call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"
            call :run_cmd "!file_path!" /setowner *!CURRENT_USER_SID!
            if !errorlevel! neq 0 call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"
            call :run_cmd "!file_path!" /inheritance:r /c /grant:r *!CURRENT_USER_SID!:F
            if !errorlevel! neq 0 call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"
        ) else (
            echo Ustawianie uprawnień administratora...
            call :run_cmd "!file_path!" /grant *S-1-5-32-544:F
            if !errorlevel! neq 0 call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"
            call :run_cmd "!file_path!" /setowner *S-1-5-32-544
            if !errorlevel! neq 0 call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"
            if "!mode!"=="root_private" (
                echo Ustawianie prywatnych uprawnień administratora...
                call :run_cmd "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F
                if !errorlevel! neq 0 call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"
            ) else (
                if "!mode!"=="root_public" (
                    echo Ustawianie publicznych uprawnień administratora...
                    call :run_cmd "!file_path!" /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX
                    if !errorlevel! neq 0 call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"
                )
            )
        )
    )

    :: Pokaż wynikowe uprawnienia
    echo Koncowe uprawnienia:
    call :run_cmd "!file_path!"

    :: Sprawdź czy operacja się powiodła
    if !errorlevel! neq 0 (
        call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"
    )

    :: Sprawdź czy plik jest dostępny po zmianie uprawnień
    echo Weryfikacja dostępu do pliku...
    if exist "!file_path!" (
        dir "!file_path!" >nul 2>&1
        if !errorlevel! neq 0 (
            echo OSTRZEZENIE: Plik istnieje, ale moze miec problemy z dostepem.
        ) else (
            echo Dostep do pliku zweryfikowany pomyslnie.
        )
    ) else (
        call :end_with_error 11 "Plik przestal istniec po zmianie uprawnien: !file_path!"
    )
    echo Pomyślnie przetworzono plik: !file_path!
) >> "%log_file%" 2>&1
shift
goto :process_files

:run_cmd
set "ic_path=%~1"
shift
set "args=%*"
echo Wykonywanie: icacls "%ic_path%" %args%
icacls "%ic_path%" %args%
if %errorlevel% neq 0 (
    call :end_with_error 9 "Błąd wykonania polecenia icacls dla %ic_path% %args%"
)
exit /b 0

:end_with_error
if defined log_file (
    echo ------------------------------------------------------------->> "%log_file%"
    echo BŁĄD %1: %2 [%date% %time%]>> "%log_file%"
    echo Polecenie: %~3>> "%log_file%"
    echo ------------------------------------------------------------->> "%log_file%"
)
echo %1: %2 >&2
echo.
echo ====================================================================
echo BŁĄD %1: %2
echo ====================================================================
echo.
if "%~3"=="usage" (
    echo Nieprawidłowe parametry: %*
    echo.
    echo Użycie: %~nx0 [id] [mode] [ścieżki_do_plików, ...]
    echo Dostępne tryby: default, private, root_private, root_public
    echo.
    echo Opis trybów:
    echo   default      - domyślne uprawnienia systemowe
    echo   private      - uprawnienia tylko dla bieżącego użytkownika
    echo   root_private - uprawnienia tylko dla administratora i systemu
    echo   root_public  - uprawnienia dla administratora z dostępem do odczytu dla innych
    echo.
    echo Przykład:
    echo   %~nx0 123 private C:\sciezka\do\pliku.txt
    echo   %~nx0 456 root_public "C:\sciezka ze spacjami\*"
    echo.
)
exit /b %1

:happy_end
echo.
echo ====================================================================
echo Zakończono przetwarzanie wszystkich plików pomyślnie.
echo ====================================================================
echo.
if defined log_file (
    echo Podsumowanie operacji:
    echo  - Identyfikator: %id%
    echo  - Tryb uprawnień: %mode%
    echo  - Plik dziennika: %log_file%
    echo.
    echo Aby zobaczyć szczegółowy dziennik, otwórz plik:
    echo %log_file%
)
exit /b 0

:help
echo.
echo ====================================================================
echo repo_keys.bat - Narzędzie do zarządzania uprawnieniami plików
echo ====================================================================
echo.
echo Użycie: %~nx0 [id] [mode] [ścieżki_do_plików, ...]
echo.
echo Parametry:
echo   [id]         - Identyfikator numeryczny operacji (używany w nazwie pliku dziennika)
echo   [mode]       - Tryb uprawnień do zastosowania
echo   [ścieżki]    - Jedna lub więcej ścieżek do plików do przetworzenia
echo.
echo Dostępne tryby:
echo   default      - Przywraca domyślne uprawnienia systemowe
echo   private      - Nadaje pełne uprawnienia tylko bieżącemu użytkownikowi
echo   root_private - Nadaje uprawnienia tylko administratorowi i systemowi
echo   root_public  - Nadaje uprawnienia administratorowi oraz odczyt dla innych
echo.
echo Przykłady:
echo   %~nx0 123 private "C:\Repozytorium\tajny.txt"
echo   %~nx0 456 root_public "C:\Dane\publiczne\*"
echo.
echo Kody błędów:
echo   1 - Błąd inicjalizacji
echo   2 - Nieprawidłowy identyfikator
echo   3 - Nieprawidłowy tryb
echo   4 - Brak ścieżek do plików
echo   5-8 - Błędy przetwarzania
echo   9 - Błąd wykonania polecenia icacls
echo   10 - Błąd podwyższenia uprawnień
echo   11 - Błąd weryfikacji dostępu
echo.
echo OKFIN
exit /b 0

:run_elevated
@echo on
echo Uruchamianie z uprawnieniami administratora...
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList '-elevated %*' -Wait"
@echo off
if %errorlevel% neq 0 (
    call :end_with_error 10 "Błąd podczas próby uruchomienia z uprawnieniami administratora"
)
echo OKFIN
exit /b 0

:ensure_current_user_sid
if defined CURRENT_USER_SID exit /b 0
for /f "tokens=2" %%A in ('whoami /user ^| findstr /R "S-1-"') do set "CURRENT_USER_SID=%%A"
if not defined CURRENT_USER_SID (
    call :end_with_error 9 "Nie udało się uzyskać SID bieżącego użytkownika"
)
exit /b 0