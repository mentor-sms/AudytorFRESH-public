@echo off
setlocal
setlocal enabledelayedexpansion

::=============================================================================
:: repo_keys.bat - Narzędzie do zarządzania uprawnieniami plików repozytoriów
::=============================================================================
:: Użycie: repo_keys.bat [id] [mode] [ścieżki_do_plików, ...]
:: Tryby: default, private, root_private, root_public
::=============================================================================

:: Sprawdź uprawnienia administratora
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo UWAGA: Ten skrypt wymaga uprawnień administratora.
    echo Próba uruchomienia z podwyższonymi uprawnieniami...
    call :run_elevated
    exit /b
)

:: Sprawdź początkowy kod błędu
if %errorlevel% neq 0 (
    call :end_with_error 1 "Błąd inicjalizacji"
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

:: Sprawdź czy wszystko jest w porządku przed rozpoczęciem
if %errorlevel% neq 0 (
    call :end_with_error 5 "Błąd przed rozpoczęciem przetwarzania"
)

:process_files
(
    :: Sprawdź błędy przed przetwarzaniem pliku
    if %errorlevel% neq 0 (
        call :end_with_error 6 "Błąd przed przetwarzaniem pliku"
    )

    :: Pobierz ścieżkę do pliku i sprawdź czy nie jest pusta
    set "file_path=%~1"
    if "!file_path!"=="" goto :happy_end
    echo "[repo_keys] Przetwarzanie pliku: !file_path!"

    :: Sprawdź czy plik istnieje
    if not exist "!file_path!" (
        call :end_with_error 7 "Nie znaleziono pliku: !file_path!"
    )

    echo Tryb: !mode!

    :: Pokaż aktualne uprawnienia
    call :run_cmd "!file_path!" silent

    :: Zresetuj uprawnienia
    echo "Resetowanie uprawnień..."
    call :run_cmd "!file_path! /reset"

    :: Ustaw uprawnienia w zależności od trybu
    if "!mode!"=="default" (
        echo Ustawiono domyślne uprawnienia.
    ) else (
        if "!mode!"=="private" (
            echo "Ustawianie prywatnych uprawnień dla użytkownika %USERNAME%..."
            call :run_cmd "!file_path! /grant %USERNAME%:F"
            call :run_cmd "!file_path! /setowner %USERNAME%"
            call :run_cmd "!file_path! /inheritance:r /c /grant:r %USERNAME%:F"
        ) else (
            echo "Ustawianie uprawnień administratora..."
            call :run_cmd "!file_path! /grant *S-1-5-32-544:F"
            call :run_cmd "!file_path! /setowner *S-1-5-32-544"
            if "!mode!"=="root_private" (
                echo "Ustawianie prywatnych uprawnień administratora..."
                call :run_cmd "!file_path! /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F"
            ) else if "!mode!"=="root_public" (
                echo "Ustawianie publicznych uprawnień administratora..."
                call :run_cmd "!file_path! /inheritance:r /c /grant:r SYSTEM:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX"
            )
        )
    )

    :: Pokaż wynikowe uprawnienia
    echo "Końcowe uprawnienia:"
    call :run_cmd "!file_path!" silent

    :: Sprawdź czy operacja się powiodła
    if %errorlevel% neq 0 (
        call :end_with_error 8 "Nie udało się przetworzyć pliku: !file_path!"
    )

    :: Sprawdź czy plik jest dostępny po zmianie uprawnień
    echo "Weryfikacja dostępu do pliku..."
    if exist "!file_path!" (
        dir "!file_path!" >nul 2>&1
        if %errorlevel% neq 0 (
            echo "OSTRZEŻENIE: Plik istnieje, ale może mieć problemy z dostępem."
        ) else (
            echo "Dostęp do pliku zweryfikowany pomyślnie."
        )
    ) else (
        call :end_with_error 11 "Plik przestał istnieć po zmianie uprawnień: !file_path!"
    )

    echo "Pomyślnie przetworzono plik: !file_path!"
) >> "%log_file%" 2>&1
shift
goto :process_files

:run_cmd
:: Przygotuj argumenty polecenia icacls
set args=%~1
echo "Wykonywanie: icacls %args%"

:: Wyświetlaj polecenia tylko jeśli nie jest w trybie cichym
if "%~2"=="" (
    @echo on
)

:: Wykonaj polecenie icacls z poprawnymi cudzysłowami
icacls %args%

:: Przywróć tryb cichy
@echo off

:: Obsługa błędów wykonania polecenia
if %errorlevel% neq 0 (
    call :end_with_error 9 "Błąd wykonania polecenia icacls dla %args%"
)

exit /b 0

:end_with_error
:: Zapisz informacje o błędzie do pliku dziennika jeśli istnieje
if defined log_file (
    echo ------------------------------------------------------------->> "%log_file%"
    echo BŁĄD %1: %2 [%date% %time%]>> "%log_file%"
    echo Polecenie: %~3>> "%log_file%"
    echo ------------------------------------------------------------->> "%log_file%"
)

:: Wyświetl komunikat błędu w standardowym wyjściu błędów
echo %1: %2 >&2

:: Wyświetl komunikat błędu w standardowym wyjściu z więcej informacjami
echo.
echo ====================================================================
echo BŁĄD %1: %2
echo ====================================================================
echo.

:: Jeśli to błąd związany z użyciem, pokaż instrukcję
if "%~3"=="usage" (
    echo "Nieprawidłowe parametry: %*"
    echo.
    echo "Użycie: %~nx0 [id] [mode] [ścieżki_do_plików, ...]"
    echo "Dostępne tryby: default, private, root_private, root_public"
    echo.
    echo "Opis trybów:"
    echo "  default      - domyślne uprawnienia systemowe"
    echo "  private      - uprawnienia tylko dla bieżącego użytkownika"
    echo "  root_private - uprawnienia tylko dla administratora i systemu"
    echo "  root_public  - uprawnienia dla administratora z dostępem do odczytu dla innych"
    echo.
    echo "Przykład:"
    echo "  %~nx0 123 private C:\ścieżka\do\pliku.txt"
    echo "  %~nx0 456 root_public "C:\ścieżka ze spacjami\*""
    echo.
)

:: Zakończ skrypt z kodem błędu
exit %1

:happy_end
:: Informacja o pomyślnym zakończeniu
echo.
echo ====================================================================
echo "Zakończono przetwarzanie wszystkich plików pomyślnie."
echo ====================================================================
echo.

:: Wyświetl podsumowanie jeśli plik dziennika istnieje
if defined log_file (
    echo "Podsumowanie operacji:"
    echo " - Identyfikator: %id%"
    echo " - Tryb uprawnień: %mode%"
    echo " - Plik dziennika: %log_file%"
    echo.
    echo "Aby zobaczyć szczegółowy dziennik, otwórz plik:"
    echo "%log_file%"
)

exit 0

:help
:: Wyświetl pełną pomoc
echo.
echo ====================================================================
echo "repo_keys.bat - Narzędzie do zarządzania uprawnieniami plików"
echo ====================================================================
echo.
echo "Użycie: %~nx0 [id] [mode] [ścieżki_do_plików, ...]"
echo.
echo "Parametry:"
echo "  [id]         - Identyfikator numeryczny operacji (używany w nazwie pliku dziennika)"
echo "  [mode]       - Tryb uprawnień do zastosowania"
echo "  [ścieżki]    - Jedna lub więcej ścieżek do plików do przetworzenia"
echo.
echo "Dostępne tryby:"
echo "  default      - Przywraca domyślne uprawnienia systemowe"
echo "  private      - Nadaje pełne uprawnienia tylko bieżącemu użytkownikowi"
echo "  root_private - Nadaje uprawnienia tylko administratorowi i systemowi"
echo "  root_public  - Nadaje uprawnienia administratorowi oraz odczyt dla innych"
echo.
echo "Przykłady:"
echo "  %~nx0 123 private "C:\Repozytorium\tajny.txt""
echo "  %~nx0 456 root_public "C:\Dane\publiczne\*""
echo.
echo "Kody błędów:"
echo "  1 - Błąd inicjalizacji"
echo "  2 - Nieprawidłowy identyfikator"
echo "  3 - Nieprawidłowy tryb"
echo "  4 - Brak ścieżek do plików"
echo "  5-8 - Błędy przetwarzania"
echo "  9 - Błąd wykonania polecenia icacls"
echo "  10 - Błąd podwyższenia uprawnień"
echo "  11 - Błąd weryfikacji dostępu"
echo.

exit 0

:run_elevated
:: Uruchom skrypt z uprawnieniami administratora
@echo on
echo "Uruchamianie z uprawnieniami administratora..."
PowerShell -Command "Start-Process cmd -ArgumentList '/c %~dpnx0 re' -Verb RunAs -Wait -PassThru | Out-Null"
@echo off

:: Sprawdź czy uruchomienie z podwyższonymi uprawnieniami się powiodło
if %errorlevel% neq 0 (
    call :end_with_error 10 "Błąd podczas próby uruchomienia z uprawnieniami administratora"
)
exit /b 0