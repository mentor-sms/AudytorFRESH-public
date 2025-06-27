#!/bin/bash
# -*- coding: utf-8 -*-
WERSJA=1.1.0-Vanilla #4lab>var
show_help() {
    cat << EOF
===============================================================================
 copy4prepare.sh v[WERSJA] - Mentor Lab Preparation Utility
===============================================================================
 Usage: sudo $0 job [options]
 Job Type (required - first argument):
   help                 Show this help message
   prepare
   install              Installation job
   setup
   bstatus              Show backup status and exit
   brestore             Restore configuration from backups and exit
   bclear               Clear backup files and exit
 Main Options:
   --from <path>          Block device or directory (default: ${from})
   --mnt <path>           Mount point for the device (default: ${mntdir})
   --timeout <seconds>    Wait time before starting the process (default: ${timeout})
 Script Execution:
   --quick                Skip confirmation delays (passed to prepare4lab)
   --debug                Set debug verbosity level (passed to prepare4lab)
 prepare4lab-specific Options (passed through to prepare4lab.sh):
   --continue             Don't start from scratch, for 'install'
   --student [Nr] [IP]    For 'setup' job
   --mic                  Dynamic mode
   --remote               Via SSH
   --devel                When student4lab from sources
 Backup Operations:
   --nobackup             Skip creating backup files
 Use:
   sudo dos2unix /media/pi/audytor/home4copy/copy4prepare.sh
   sudo chmod +x /media/pi/audytor/home4copy/copy4prepare.sh
   sudo /media/pi/audytor/home4copy/copy4prepare.sh install --devel --quick --timeout 0 --from /media/pi/audytor
===============================================================================
EOF
}
SECONDS_START=$(date +%s)
do_umount=0                          # Flag to track if we mounted a device
from="USB"                       # Source location (block device or directory)
mntdir=/home/pi/mnt                          # Mount point for block devices
target=/home/pi                      # Target directory for file operations
home_dir=home4copy                   # Directory name on source containing files
file=prepare4lab.sh                  # Script filename to run after copying
quick=0                              # Flag to skip confirmation delays
norun=0                              # Flag to skip running scripts
nosync=0                             # Flag to skip rsync operations
job="help"
timeout=0                            # Wait time before starting operations
run="/home/pi/.mentor/prepare4lab.sh" # Path to the script to run
dry=0                                # Flag for simulation mode (no changes)
nobackup=0                           # Flag to skip creating backup files
user=1
debug=0
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            prepare|install|setup|bstatus|bclear|brestore|help)
                job="$1"
                echo_info "Job: $job"
                ;;
            --from)
                shift
                from="${1:-}"
                if [ -z "$from" ]; then
                    echo_error $LINENO "Missing argument for --from"
                fi
                ;;
            --mnt)
                shift
                mntdir="${1:-}"
                if [ -z "$mntdir" ]; then
                    echo_error $LINENO "Missing argument for --mnt"
                fi
                ;;
            --timeout)
                shift
                timeout="${1:-}"
                if [ -z "$timeout" ]; then
                    echo_error $LINENO "Missing argument for --timeout"
                fi
                ;;
            --quick)
                quick=1
                echo_info "quick"
                ;;
            --debug)
                debug=1
                echo_info "debug"
                ;;
            --nobackup)
                nobackup=1
                echo_info "nobackup"
                ;;
            --dry)
                dry=1
                echo_info "dry"
                ;;
            *)
                # Pass through other arguments to prepare4lab
                ;;
        esac
        shift
    done

    echo_info "from=$from"
    echo_info "mnt=$mntdir"
    echo_info "timeout=$timeout"
    echo_info "job: $job"
}

main() {
    # Show startup banner
    echo_info "============================================================="
    echo_info "   copy4prepare v$WERSJA - Narzedzie Przygotowania Laboratorium Mentor"
    echo_info "============================================================="
    echo_info "Uzytkownik: $(whoami) | Host: $(hostname)"

    parse_arguments "$@"
				echo_wait "============================================================="

    # Show backup status if requested
    if [ "$job" = "help" ]; then
    	show_help
    	exit 0
				fi
    if [ "$job" = "bstatus" ]; then
     show_backup_status
     exit 0
				fi

    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo_error $LINENO "This script must be run as root (use sudo)"
    fi

    if [ "$job" = "brestore" ]; then
    	handle_brestore
     exit 0
   	fi
    if [ "$job" = "bclear" ]; then
    	handle_bclear
     exit 0
    fi


    # Wait timeout if specified
    if [ "$timeout" -gt 0 ]; then
        echo_info "Waiting $timeout seconds before starting..."
        sleep "$timeout"
    fi

    # Initialize mount system
    mnt_init

    # Check if home_dir exists in source
    if [ ! -d "$from/$home_dir" ]; then
        echo_error $LINENO "Katalog zrodlowy $from/$home_dir nie istnieje. Sprawdz, czy urzadzenie jest prawidlowo podlaczone i czy sciezka jest poprawna."
    fi

    # Run rsync operation
    if [ "$nosync" -eq 0 ]; then
        run_rsync
    else
        echo_info "Skipping rsync operations (--nosync)"
    fi

    # Verify and run prepare script
    if [ "$norun" -eq 0 ]; then
        verify_prepare_script
        # Build command line for prepare4lab
        prepare_args="$job"
        if [ "$quick" -eq 1 ]; then
            prepare_args="$prepare_args --quick"
        fi
        if [ "$debug" -eq 1 ]; then
            prepare_args="$prepare_args --debug"
        fi
        echo_info "Uruchamianie skryptu przygotowawczego: $run $prepare_args"
        if [ "$dry" -ne 1 ]; then
            cd /home/pi || echo_error $LINENO "Nie udalo sie zmienic katalogu na /home/pi"
            echo_info "Rozpoczynam wykonanie skryptu przygotowawczego..."
            "$run $prepare_args" || echo_error $LINENO "Wykonanie skryptu przygotowawczego nie powiodlo sie"
            echo_info "Skrypt przygotowawczy zakonczony pomyslnie"
        else
            echo_info "Symulacja: Uruchomilbym: $run $prepare_args"
        fi
    else
        echo_info "Pomijam wykonanie skryptu przygotowawczego (--norun)"
    fi

    # Cleanup
    un_un

    # Print summary report
    echo_info "============================================================="
    echo_info "   PODSUMOWANIE WYKONANIA"
    echo_info "============================================================="
    echo_info "Skrypt: copy4prepare.sh v$WERSJA"
    echo_info "Zadanie: $job"
    echo_info "Zrodlo: $from"
    echo_info "Cel: $target"
    echo_info "Katalog domowy: $home_dir"
    echo_info "Tryb szybki: $([ "$quick" -eq 1 ] && echo "tak" || echo "nie")"
    echo_info "Tryb debugowania: $([ "$debug" -eq 1 ] && echo "tak" || echo "nie")"
    echo_info "Tryb symulacji: $([ "$dry" -eq 1 ] && echo "tak" || echo "nie")"
    echo_info "Czas rozpoczecia: $(date -d @"$SECONDS_START" '+%H:%M:%S' 2>/dev/null || echo "nieznany")"
    echo_info "Czas zakonczenia: $(date '+%H:%M:%S')"
    echo_info "Calkowity czas wykonania: $(($(date +%s) - SECONDS_START)) sekund"
    echo_info "============================================================="
    echo_info "copy4prepare.sh zakonczony pomyslnie"
    echo_stop "RESTART SYSTEMU"
    sync || true

    # Simplified reboot command with proper output handling
    if [ "$debug" -eq 1 ] || [ "$user" -eq 1 ]; then
        # Debug mode - show output
        shutdown -r now || systemctl reboot || echo_error $LINENO "Natychmiastowy restart systemu nieudany"
    else
        # Normal mode - suppress output
        shutdown -r now >/dev/null 2>&1 || systemctl reboot >/dev/null 2>&1 || echo_error $LINENO "Ciche restartowanie systemu nieudane"
    fi

    # If we reach here, reboot failed
    sleep 10
    echo_error $LINENO "System nie zrestartowal sie w wymaganym czasie"
}
echo_error() {
    local lineno="$1"
    local message="$2"
    local context="${3:-""}"
    local current_time
    current_time=$(date +"%H:%M:%S")
    echo "[BLAD@$lineno] $message"
    echo "[BLAD@$lineno] $message" >&2
    if [ -n "$context" ]; then
        echo "Kontekst: $context" >&2
    fi
    echo "Czas: $current_time | Uzytkownik: $(whoami) | Host: $(hostname)" >&2
    echo "Konczenie pracy skryptu. Kod bledu: 1" >&2
    exit 1
}
echo_info() {
    local msg="$1"
    local level="${2:-INFO}"
    local current_time
    current_time=$(date +"%H:%M:%S")
    case "$level" in
        DEBUG)
            if [ "$debug" -eq 1 ]; then
                echo "[DEBUG] $msg"
            fi
            ;;
        WARN)
            echo "[UWAGA] $msg"
            ;;
        SUCCESS)
            echo "[SUKCES] $msg"
            ;;
        *)
            echo "[INFO] $msg"
            ;;
    esac
}
echo_stop() {
    local operation="$1"
    local additional_info="${2:-}"
    sync
    if [ "$user" -eq 1 ]; then
        echo ""
        if [ "$quick" -eq 1 ]; then
            echo "[STOP] $operation //[Enter] (5s)"
            if [ -n "$additional_info" ]; then
                echo "$additional_info"
            fi
            read -t 5 -r || true
        else
            echo "[STOP] $operation"
            if [ -n "$additional_info" ]; then
                echo "$additional_info"
            fi
            echo "Nacisnij [Enter], aby kontynuowac, Ctrl+C, aby anulowac..."
            read -r
        fi
    else
        echo "[STOP] $operation"
        if [ -n "$additional_info" ]; then
            echo "$additional_info"
        fi
    fi
}
echo_wait() {
    local message="$1"

    if [ "$user" -eq 1 ]; then
        echo ""
    fi

    if [[ "$user" -eq 1 || "$debug" -eq 1 ]] && [ "$quick" -eq 0 ]; then
        echo "$message"
        read -t 4 -r || true
    else
        echo "$message"
    fi
}
is_file() {
    local path="$1"
    last_is_file=0
    if [ -f "$path" ]; then
        last_is_file=1
    fi
}
is_directory() {
    local path="$1"
    last_is_directory=0
    if [ -d "$path" ] || [[ "$path" =~ /$ ]]; then
        last_is_directory=1
    fi
}
is_block_device() {
    local path="$1"

    # Check if path is a mountpoint (mounted filesystem) - these should return false
    if mountpoint -q "$path" 2>/dev/null; then
        return 1  # false - it's a mountpoint, not a device
    fi

    # Now check if it's actually a block device file
    if [ -b "$path" ]; then
        return 0  # true - it's a block device
    fi

    # Extract device name (e.g., sda1 -> sda)
    local device_name
    device_name=$(basename "$path")
    local base_device=${device_name%[0-9]*}  # Remove partition number

    # Check if it's a removable device
    local removable_file="/sys/block/$base_device/removable"
    if [ -f "$removable_file" ] && [ "$(cat "$removable_file")" = "1" ]; then
        return 0  # true - removable device
    fi

    # Additional check: look for USB subsystem in device path
    local device_path="/sys/block/$base_device"
    if [ -d "$device_path" ]; then
        # Follow symlinks to find if device is connected via USB
        local real_path
        real_path=$(readlink -f "$device_path")
        if [[ "$real_path" == *"/usb"* ]]; then
            return 0  # true - USB device
        fi
    fi

    # Check if it's a device path (not a mountpoint in /media or /mnt)
    if [[ "$path" == /dev/* ]]; then
        # It's in /dev, likely a device
        return 0  # true - device path
    fi

    return 1  # false - default to not a block device
}
is_mounted() {
    local device="$1"
    local mountpoint="$2"
    last_is_mounted=0
    if mount | grep -q "$device.*$mountpoint"; then
        last_is_mounted=1
    fi
}
set_from() {
    from="$1"
    echo_info "Sciezka zrodlowa ustawiona na: $from"
    if [[ "$from" == /dev/* ]]; then
        echo_info "Uzywam urzadzenia blokowego"
    elif [[ "$from" == /media/* || "$from" == /mnt/* ]]; then
        echo_info "Uzywam zamontowanego urzadzenia"
    else
        echo_info "Uzywam sciezki katalogu"
    fi
}
restore_from_backup() {
    local filepath="$1"
    local backup_path="${filepath}.lab.bak"

    if [ ! -f "$backup_path" ]; then
        echo_info "Nie znaleziono kopii zapasowej dla $filepath, pomijam przywracanie"
        return 1
    fi

				echo_info "Przywracam $filepath z kopii zapasowej $backup_path"

				# Verify backup integrity before restore
				if [ ! -s "$backup_path" ]; then
								echo_stop "Plik kopii zapasowej $backup_path jest pusty lub uszkodzony, pomijam przywracanie"
								return 1
				fi

				# Create a safety backup of current file if it exists and differs
				if [ -f "$filepath" ] && ! cmp -s "$filepath" "$backup_path"; then
								local safety_backup
								safety_backup="${filepath}.before_restore.$(date +%s)"
								echo_info "Tworzenie kopii bezpieczenstwa: $safety_backup"
								cp "$filepath" "$safety_backup" || echo_info "Ostrzezenie: Nie udalo sie utworzyc kopii bezpieczenstwa"
				fi

				# Restore from backup using sudo mv -f
				if [ "$dry" -ne 1 ]; then
								sudo mv -f "$backup_path" "$filepath" || echo_error $LINENO "Nie udalo sie przywrocic $filepath z kopii zapasowej" "Przywracanie kopii zapasowej"
								echo_info "Pomyslnie przywrocono $filepath z kopii zapasowej"
				else
								echo_info "Symulacja: Przywrocilbym $filepath z $backup_path"
				fi

				return 0
}
handle_brestore() {
    echo_info "Przywracanie konfiguracji z plikow kopii zapasowych..."
				echo_info "Skanowanie calego systemu plikow w poszukiwaniu plikow .lab.bak..."

				local restore_count=0
				local fail_count=0

				# Find all .lab.bak files on entire filesystem and process them without losing variable changes
				while IFS= read -r backup_file; do
								local original_file="${backup_file%.lab.bak}"

								echo_info "Znaleziono kopie zapasowa: $backup_file"

								if restore_from_backup "$original_file" 1; then
												restore_count=$((restore_count + 1))
												echo_info "✓ Przywrocono: $original_file"
								else
												fail_count=$((fail_count + 1))
												echo_info "✗ Nie udalo sie przywrocic: $original_file"
								fi
				done < <(find / -name "*.lab.bak" -type f 2>/dev/null)

				echo_info "=== Podsumowanie przywracania ==="
				echo_info "Pomyslnie przywrocono: $restore_count plikow"
				echo_info "Nie udalo sie przywrocic: $fail_count plikow"
				echo_info "==================================="

				if [ $restore_count -gt 0 ]; then
								echo_info "Operacja przywracania zakonczona. Niektore uslugi moga wymagac ponownego uruchomienia."
								echo_info "Rozwaz wykonanie: sudo systemctl restart ssh"
				fi
}
handle_bclear() {
    echo_info "Clearing backup files..."
				echo_info "Scanning entire filesystem for .lab.bak files..."

				local clear_count=0
				local fail_count=0
				local total_size=0

				# Find all .lab.bak files on entire filesystem and process them without losing variable changes
				while IFS= read -r backup_file; do
								if [ -f "$backup_file" ]; then
												local backup_size
												backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
												total_size=$((total_size + backup_size))

												echo_info "Clearing: $backup_file (${backup_size} bytes)"

												if [ "$dry" -ne 1 ]; then
																if rm -f "$backup_file"; then
																				clear_count=$((clear_count + 1))
																				echo_info "✓ Cleared: $backup_file"
																else
																				fail_count=$((fail_count + 1))
																				echo_info "✗ Failed to clear: $backup_file"
																fi
												else
																clear_count=$((clear_count + 1))
																echo_info "dry: Would clear: $backup_file"
												fi
								fi
				done < <(find / -name "*.lab.bak" -type f 2>/dev/null)

				echo_info "=== Clear Summary ==="
				echo_info "Successfully cleared: $clear_count files"
				echo_info "Failed to clear: $fail_count files"
				echo_info "Total space freed: $total_size bytes"
				echo_info "==================="
}
show_backup_status() {
    echo_info "=== Backup Status Report ==="
    echo_info "Scanning entire filesystem for .lab.bak files..."
    echo_info ""

    local backup_count=0
    local total_size=0

    while IFS= read -r backup_file; do
        if [ -f "$backup_file" ]; then
            local original_file="${backup_file%.lab.bak}"
            local backup_size
            backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
            local backup_date
            backup_date=$(stat -c%y "$backup_file" 2>/dev/null || echo "unknown")
            local status="OK"

            # Check if original file exists and differs
            if [ -f "$original_file" ]; then
                if cmp -s "$original_file" "$backup_file"; then
                    status="IDENTICAL"
                else
                    status="DIFFERS"
                fi
            else
                status="ORIGINAL_MISSING"
            fi

            echo_info "  $backup_file"
            echo_info "    Size: $backup_size bytes"
            echo_info "    Date: $backup_date"
            echo_info "    Status: $status"
            echo_info ""

            backup_count=$((backup_count + 1))
            total_size=$((total_size + backup_size))
        fi
    done < <(find / -name "*.lab.bak" -type f 2>/dev/null)

    echo_info "=== Summary ==="
    echo_info "Total backups found: $backup_count"
    echo_info "Total backup size: $total_size bytes"
    echo_info "================="
}
create_backup() {
    local filepath="$1"

    # Check if backups are disabled
    if [ "$nobackup" -eq 1 ]; then
        echo_info "--nobackup włączone. Pomijanie tworzenia kopii zapasowej dla: $filepath"
        return 0
    fi

    # Check for excluded paths
    if [[ "$filepath" == *"home/pi/.mentor"* || "$filepath" == *"home/pi/.source4rpi"* ]]; then
        echo_info "Pomijanie tworzenia kopii zapasowej dla: $filepath (ścieżka wykluczona)"
        return 0
    fi

    # Prepare backup path and directory
    local backup_path="${filepath}.lab.bak"
    local backup_dir
    backup_dir="$(dirname "$backup_path")"

    echo_info "Przygotowanie kopii zapasowej: $filepath"

    # Check if backup already exists
    if [ -f "$backup_path" ]; then
        echo_info "Kopia zapasowa już istnieje dla: $filepath, pomijanie"

        # Verify existing backup integrity
        if [ -f "$filepath" ]; then
            if cmp -s "$filepath" "$backup_path"; then
                echo_info "Istniejąca kopia zapasowa jest identyczna z aktualnym plikiem"
            else
                echo_info "Ostrzeżenie: Istniejąca kopia zapasowa różni się od aktualnego pliku, zachowanie istniejącej kopii"

                if [ "$debug" -eq 1 ]; then
                    local orig_size
                    orig_size=$(stat -c%s "$filepath" 2>/dev/null || echo "nieznany")
                    local backup_size
                    backup_size=$(stat -c%s "$backup_path" 2>/dev/null || echo "nieznany")
                    echo_info "Rozmiar oryginalny: $orig_size, rozmiar kopii: $backup_size"
                fi
            fi
        else
            echo_info "Ostrzeżenie: Plik źródłowy nie istnieje, ale kopia zapasowa tak"
        fi
    else
        # Check if source file exists
        is_file "$filepath"
        if [ $last_is_file -ne 1 ]; then
            echo_info "Plik źródłowy nie istnieje: $filepath, kopia zapasowa nie jest potrzebna"
            return 0
        fi

        # Ensure backup directory exists
        if [ ! -d "$backup_dir" ]; then
            echo_info "Tworzenie katalogu kopii zapasowej: $backup_dir"
            if ! sudo -u pi mkdir -p "$backup_dir"; then
                echo_error $LINENO "Nie udało się utworzyć katalogu kopii zapasowej: $backup_dir" "Tworzenie kopii zapasowej"
            fi
        fi

        # Create the actual backup
        if [ "$dry" -ne 1 ]; then
            echo_info "Kopia zapasowa: $filepath do $backup_path"
            # Use cp with preservation of attributes
            if ! cp -p "$filepath" "$backup_path"; then
                echo_error $LINENO "Nie udało się utworzyć pliku kopii zapasowej: $backup_path" "Tworzenie kopii zapasowej"
            fi

            # Verify backup was created successfully
            if [ ! -f "$backup_path" ]; then
                echo_error $LINENO "Weryfikacja kopii zapasowej nie powiodła się: $backup_path nie istnieje" "Weryfikacja kopii zapasowej"
            fi

            # Compare source and backup to ensure integrity
            if ! cmp -s "$filepath" "$backup_path"; then
                echo_error $LINENO "Weryfikacja kopii zapasowej nie powiodła się: zawartość $backup_path różni się od źródła" "Weryfikacja kopii zapasowej"
            fi

            echo_info "Kopia zapasowa utworzona pomyślnie"
        else
            echo_info "Symulacja: kopia zapasowa: $filepath do $backup_path"
        fi
    fi

    return 0
}
verify_prepare_script() {
    local wersja_in_script
    echo_info "Weryfikacja integralnosci skryptu przed uruchomieniem: $run"

    # Check if file exists
    is_file "$run"
    if [ $last_is_file -ne 1 ]; then
        echo_error $LINENO "Skrypt nie istnieje: $run" "Weryfikacja skryptu"
    fi

    # Check for syntax errors
    echo_info "Sprawdzanie skladni: $run"
    if ! bash -n "$run"; then
        echo_error $LINENO "Blad skladni w skrypcie: $run" "Sprawdzanie skladni skryptu"
    else
        echo_info "Skladnia poprawna"
    fi

    # Check script version
    wersja_in_script=$(grep -m 1 "^WERSJA=" "$run" | cut -d'=' -f2 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//')
    if [ -z "$wersja_in_script" ]; then
        echo_info "Ostrzezenie: Nie mozna odczytac wersji ze skryptu"
        echo_wait "Wersja skryptu nie znaleziona, kontynuowac?"
    else
        echo_info "Znaleziona wersja skryptu: $wersja_in_script"
        if [ "$wersja_in_script" != "$WERSJA" ]; then
            echo_info "UWAGA: Wykryto niezgodnosc wersji!"
            echo_info "  Wersja copy4prepare.sh: $WERSJA"
            echo_info "  Wersja $file: $wersja_in_script"
            echo_stop "Niezgodnosc wersji" "Uruchomienie skryptu z inna wersja moze powodowac problemy"
        else
            echo_info "Weryfikacja wersji udana: Oba skrypty w wersji $WERSJA"
        fi
    fi

    # Check executable permission
    if [ ! -x "$run" ]; then
        echo_info "Dodawanie uprawnienia wykonywania do skryptu"
        if ! chmod +x "$run"; then
            echo_error $LINENO "Nie można ustawić uprawnienia wykonywania" "Ustawianie uprawnień"
        else
            echo_info "Uprawnienia ustawione pomyślnie"
        fi
    else
        echo_info "Skrypt ma już uprawnienia wykonywania"
    fi

    echo_info "Weryfikacja skryptu zakończona pomyślnie"
}
handle_file() {
    local _file=$1
    local _sourcefile=$2
    _file="${_file%"${_file##*[![:space:]]}"}"
    _sourcefile="${_sourcefile%"${_sourcefile##*[![:space:]]}"}"
    echo_info "Przetwarzanie pliku: $_file"
    is_file "$_sourcefile"
    if [ $last_is_file -ne 1 ]; then
        echo_error $LINENO "Plik źródłowy nie istnieje: $_sourcefile"
    fi
    cmp -s "$_file" "$_sourcefile" || echo_stop "Pliki różnią się po synchronizacji: $_file i $_sourcefile"
    echo_info "Konwersja pliku $_file do formatu Unix"
    dos2unix -f -k "$_file" 2>/dev/null || echo_wait "Ostrzeżenie: Problem z konwersją dos2unix dla pliku $_file, kontynuuję"
    if [[ "$_file" == *.sh ]]; then
        echo_info "Nadawanie uprawnień wykonywania dla $_file"
        chmod +x "$_file" || echo_wait "Ostrzeżenie: Nie udało się nadać uprawnień wykonywania dla $_file, kontynuuję"
        echo_info "Sprawdzanie składni skryptu bash $_file"
        bash -n "$_file" || echo_stop "Błąd składni w skrypcie: $_file"
    fi
}
rsync_line_test() {
    local p1="$1"
    local p2="$2"
    if [ -z "$p1" ] || [ -z "$p2" ]; then
        echo_info "Puste parametry przekazane do rsync_line_test"
    elif [[ "$p1" == "sending" || "$p1" == "sent" || "$p1" == "total" || "$p1" == *"speedup"* ]]; then
        echo_info "Pomijanie linii statusu rsync: $p1"
    else
        p1="/${p1#/}"
        p2="/${p2#/}"
        if [[ "${p1: -1}" == "/" ]]; then
            echo_info "Pomijanie ścieżki katalogu: $p1"
        elif [[ "${p2: -1}" == "/" ]]; then
            echo_info "Pomijanie ścieżki z końcowym ukośnikiem: $p2"
        elif [[ "$p1" == *"building file list"* || "$p2" == *"building file list"* ]]; then
            echo_info "Pomijanie linii budowania listy plików"
        elif [[ "$p1" == *.lab.bak || "$p2" == *.lab.bak ]]; then
            echo_info "Pomijanie pliku kopii zapasowej: $p1"
        elif [[ "$p1" == *.fill || "$p2" == *.fill ]]; then
            echo_info "Pomijanie pliku wypełniającego: $p1"
        elif [[ "$p1" == *.fix || "$p2" == *.fix ]]; then
            echo_info "Pomijanie pliku naprawiającego: $p1"
        elif [[ $p1 == "$p2" ]] || [[ $p2 == *uptodate* ]]; then
            echo_wait "Przetwarzanie: $p1 $p2"
            return 1  # Set flag to indicate file should be processed
								else
            echo_info "Pomijanie linii: $p1"
        fi
    fi
    return 0
}

run_rsync() {
    echo_info "Uruchamianie rsync dla katalogu home_dir (copy4prepare)"
    local exclude_option
    exclude_option="--exclude=/root4rpi --exclude=/copy4prepare.sh --exclude=*.lab.bak"
    if [[ "$mntdir" == "$target/"* ]]; then
        exclude_option="$exclude_option --exclude=/${mntdir#"$target"/}"
    fi
    local rcmd
    rcmd="sudo -u pi rsync --relative -rtcvv"
    local cont
    cont="$from/$home_dir/./ $target"
    local rsync_cmd
    rsync_cmd="$rcmd $exclude_option $cont"
    local dry_rsync_cmd
    dry_rsync_cmd="$rcmd --dry-run $exclude_option $cont"

    echo_info "Wykonywanie suchego przebiegu, aby zidentyfikowac pliki do kopii zapasowej..."
    echo_info "SYMULACJA RSYNC: $from/$home_dir/ >> $target ($exclude_option)"
    local dry_run_file
    dry_run_file=$(mktemp)
    $dry_rsync_cmd > "$dry_run_file" || echo_info "Ostrzezenie: Symulacja rsync nie powiodla sie, kontynuuje mimo to"

    # First rsync run - collect files that would be processed
    echo_info "Pierwsza analiza rsync - zbieranie listy plikow do przetworzenia..."
    local files_to_process=()
    while read -r line; do
        local first_part
        local second_part
        first_part="${line%% *}"
        second_part="${line#* }"

        if rsync_line_test "$first_part" "$second_part"; then
            true
        else
            files_to_process+=("$first_part")
        fi
    done < "$dry_run_file"

    # Display collected files to user and ask for approval
    if [ ${#files_to_process[@]} -gt 0 ]; then
        echo_info "Znalezione pliki do przetworzenia:"
        for file_path in "${files_to_process[@]}"; do
            echo_info "  - $file_path"
        done

        echo_stop "Czy kontynuowac z przetwarzaniem ${#files_to_process[@]} plikow?" \
            "Pliki zostana usuniete przed kopiowaniem, a nastepnie przetworzone."

        # Create backups for all files that will be processed
        echo_info "Tworzenie kopii zapasowych..."
        for first_part in "${files_to_process[@]}"; do
            local fpath="$target/$first_part"
            if [ "$dry" -ne 1 ]; then
                create_backup "$fpath"
                echo_info "Usuwanie pliku przed kopiowaniem: $fpath"
                if [ -e "$fpath" ]; then
                    echo_info "Plik istnieje, usuwanie: $fpath"
                    rm -rf "$fpath" || echo_info "Ostrzezenie: Nie udalo sie usunac pliku, proba kontynuacji"
                else
                    echo_info "Plik nie istnieje: $fpath"
                fi
            else
                echo_info "Symulacja: Usunięty zostałby plik $fpath"
            fi
        done
    else
        echo_info "Brak plikow do przetworzenia"
    fi

    rm -f "$dry_run_file"

    # Second rsync run - actual synchronization without line-by-line processing
    echo_info ""
    echo_info "rsync cmd: $rsync_cmd"
    echo_stop "Rozpoczynanie wlasciwej operacji rsync..."
    if [ "$dry" -ne 1 ]; then
        echo_info "Wykonywanie synchronizacji plikow..."
        rm -f /home/pi/rsync.lab.log || true
        $rsync_cmd || echo_info "Ostrzezenie: Operacja rsync zakonczona z bledami, sprawdzam wyniki"

        # Process all collected files after rsync completion
        echo_info "Przetwarzanie skopiowanych plikow..."
        for first_part in "${files_to_process[@]}"; do
            echo_info "Przetwarzanie pliku: $target/$first_part"
            handle_file "$target/$first_part" "$from/$home_dir/$first_part" || true
        done
    else
        echo_info "Tryb symulacji: pomijanie właściwej operacji rsync"
    fi

    echo_info "Operacja rsync zakończona"
}
un_un() {
    if [ "$do_umount" -eq 1 ]; then
        echo_wait "Odmontowywanie urzadzenia: $mntdir"
        do_umount=0

        # Check if mounted
        if mount | grep -q "$mntdir"; then
            echo_info "Odmontowywanie: $mntdir..."
            local max_attempts=3
            local attempt=1
            local unmounted=0

            # Try to unmount with multiple attempts
            while [ $attempt -le $max_attempts ] && [ $unmounted -eq 0 ]; do
                echo_info "Próba $attempt z $max_attempts..."
                if sudo umount "$mntdir"; then
                    echo_info "Pomyslnie odmontowano: $mntdir"
                    unmounted=1
                else
                    local mount_processes
                    mount_processes=$(lsof "$mntdir" 2>/dev/null | tail -n +2 | awk '{print $1,$2}' | sort -u)
                    if [ -n "$mount_processes" ]; then
                        echo_info "Procesy blokujace odmontowanie: $mount_processes"
                    fi
                    echo_wait "Proba $attempt odmontowania $mntdir nie powiodla sie, ponawiam..."
                    attempt=$((attempt + 1))
                fi
            done

            # Handle unmount failure
            if [ $unmounted -eq 0 ]; then
                echo_stop "Nie udalo sie odmontowac $mntdir po $max_attempts probach, kontynuuje mimo to" "Moze byc konieczne reczne odmontowanie pozniej"
            fi
        else
            echo_info "$mntdir nie jest zamontowany"
        fi

        # Remove mount directory
        if [ -d "$mntdir" ]; then
            echo_info "Usuwanie katalogu montowania: $mntdir"
            if ! rm -rf "$mntdir"; then
                echo_stop "Nie udalo sie usunac katalogu $mntdir, kontynuuje mimo to" "Katalog moze wymagac recznego usuniecia"
            else
                echo_info "Katalog usuniety pomyslnie"
            fi
        fi
    else
        echo_info "Brak potrzeby odmontowywania"
    fi
}
mnt_mnt() {
    echo_info "Przygotowywanie punktu montowania $mntdir"
    if [ ! -d "$mntdir" ]; then
        echo_info "Tworzenie katalogu montowania $mntdir"
        sudo -u pi mkdir -p "$mntdir" || echo_error $LINENO "Nie udało się utworzyć katalogu montowania $mntdir"
    fi
    is_mounted "$from" "$mntdir"
    if [ $last_is_mounted -eq 1 ]; then
        echo_info "$from jest już zamontowany w $mntdir"
        local actual_mntdir
        actual_mntdir=$(mount | grep "$from" | awk '{print $3}')
        echo_info "Używam aktualnego punktu montowania: $actual_mntdir"
        set_from "$actual_mntdir"
    else
        local existing_mount
        existing_mount=$(mount | grep "$from" | awk '{print $3}' | head -n1)
        if [ -n "$existing_mount" ]; then
            echo_info "$from jest już zamontowany w $existing_mount, używam tego punktu montowania"
            set_from "$existing_mount"
        else
            echo_info "Montuję urządzenie $from w $mntdir"
            sudo mount "$from" "$mntdir" || echo_error $LINENO "Nie udało się zamontować $from w $mntdir"
            do_umount=1
            set_from "$mntdir"
        fi
    fi
}
mnt_init() {
    echo_info "Inicjalizacja systemu montowania dla zrodla: $from"
    echo_info "Parametry: mntdir=$mntdir, target=$target, home_dir=$home_dir"

    if [ "$from" = "USB" ]; then
        echo_info "Wykryto tryb USB, skanowanie urzadzen USB..."
        echo_info "Szukam podlaczonych dyskow wymiennych USB"
        local found_device=0

        # Iterate over /dev/sd[a-e][1-4] possibilities
        for drive in {a..e}; do
            for partition in {1..4}; do
                local device_path="/dev/sd${drive}${partition}"

                if [ -e "$device_path" ]; then
                    echo_info "Znaleziono urzadzenie: $device_path"

                    # Check if it's mounted
                    local mount_point
                    mount_point=$(mount | grep "^$device_path " | awk '{print $3}')

                    if [ -n "$mount_point" ]; then
                        echo_info "$device_path jest już zamontowane w $mount_point"
                        echo_info "Używam istniejącego punktu montowania"
                        set_from "$mount_point"
                        found_device=1
                        break 2
                    else
                        echo_info "$device_path nie jest zamontowane, próbuję zamontować"
                        echo_info "Przygotowanie do montowania urządzenia..."
                        set_from "$device_path"
                        mnt_mnt "$device_path"
                        found_device=1
                        break 2
                    fi
                else
                    continue
                fi
            done
        done

        if [ $found_device -eq 0 ]; then
            echo_error $LINENO "Nie znaleziono urzadzen USB w zakresie /dev/sd[a-e][1-4]. Podlacz urzadzenie USB i sprobuj ponownie."
        fi
    else
        # Original logic for non-USB sources
        if is_block_device "$from"; then
            echo_info "$from is a block device, proceeding with mount"
            mnt_mnt "$from"
        else
            is_directory "$from"
            if [ $last_is_directory -eq 1 ]; then
                echo_info "$from is a directory, using directly"
                set_from "$from"
            else
                echo_error $LINENO "Source $from is neither a valid block device nor directory"
            fi
        fi
    fi
}

main "$@"