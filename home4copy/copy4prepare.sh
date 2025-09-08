#!/bin/bash
# -*- coding: utf-8 -*-
WERSJA=2.0.0 #4lab>var
show_help() {
    cat << EOF
===============================================================================
 copy4prepare.sh v[WERSJA] - Mentor Lab Preparation Utility
===============================================================================
 Usage: sudo $0 job [options]
 Job Type (required - first argument):
   install              Installation job
   bstatus              Show backup status and exit
   brestore             Restore configuration from backups and exit
   bclear               Clear backup files and exit
 Main Options:
   --timeout <seconds>
   --dry
   --from <path>
   --mnt <path>
   --target <path>
   --no-backup
   --quick
   --debug
   --username
   --target-lan
   --devel
===============================================================================
EOF
}
from="USB"
mntdir="/mnt/labusb"
target_root="/"
PI_USER="pi" #4lab>var
username="$PI_USER"
quick=0
job="help"
timeout=0
dry=0
debug=0
nobackup=0
devel=0
target_lan=0
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            prepare|install|setup|bstatus|bclear|brestore|help|clean|update)
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
            --target)
                shift
                target_root="${1:-}"
                if [ -z "$target_root" ]; then
                    echo_error $LINENO "Missing argument for --target"
                fi
                if [ "$target_root" != "/" ] && [ "${target_root%/}" = "$target_root" ]; then
                                               target_root="$target_root/"
                                                                fi
                ;;
            --mnt)
                shift
                mntdir="${1:-}"
                if [ -z "$mntdir" ]; then
                    echo_error $LINENO "Missing argument for --mnt"
                fi
                ;;
            --username)
                shift
                username="${1:-}"
                if [ -z "$username" ]; then
                    echo_error $LINENO "Missing argument for --username"
                fi
                ;;
            --target-lan)
                                                                target_lan=1
                echo_info "auto-reboot, no full-upgrade"
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
            --no-backup)
                nobackup=1
                echo_wait "no backup!"
                ;;
            --debug)
                debug=1
                echo_info "debug"
                ;;
            --devel)
                devel=1
                echo_info "setup4rpi"
                ;;
            --dry)
                dry=1
                echo_info "dry"
                ;;
            *)
                ;;
        esac
        shift
    done
    echo_info "from=$from"
    echo_info "mnt=$mntdir"
    echo_info "timeout=$timeout"
}
debian_upgrade() {
    APT_GET=${APT_GET:-"apt-get -q"}
    APT_Y=""
    APT_DPKG_OPTS=""
    APT_UPDATE_OPTS="--allow-releaseinfo-change"
    if [ "${quick:-0}" -eq 1 ]; then
        APT_Y="-y"
        APT_DPKG_OPTS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew"
    fi
    aptcmd_update="$APT_GET $APT_Y"
    aptcmd_pkg="$APT_GET $APT_Y $APT_DPKG_OPTS"
    #4lab>on echo_info "APT: aktualizacja listy pakietow"
    wait_apt
    echo_info "disabled: $aptcmd_update $APT_UPDATE_OPTS update"
    $aptcmd_update $APT_UPDATE_OPTS update || echo_stop "Nie można zaktualizować listy pakietów"
    #4lab>on wait_apt
    if [ "${target_lan:-0}" -eq 1 ]; then
        echo_info "Wykonywanie aktualizacji systemu (upgrade)"
        echo_info "disabled: $aptcmd_pkg upgrade"
    #4lab>on     $aptcmd_pkg upgrade || echo_stop "Aktualizacja systemu nie powiodla sie"
    else
        echo_info "Wykonywanie pełnej aktualizacji systemu (full-upgrade)"
        echo_info "disabled: $aptcmd_pkg full-upgrade"
    #4lab>on     $aptcmd_pkg full-upgrade || echo_stop "Pelna aktualizacja systemu nie powiodla sie"
    fi
    #4lab>on wait_apt
    echo_info "Instalowanie wymaganych pakietow"
    #4lab>on $aptcmd_pkg install \
    #4lab>on     #4lab>list deps4rpi.txt
    echo_info "disabled: $aptcmd_pkg install"
    #4lab>on if [ "${devel:-0}" -eq 1 ]; then
    #4lab>on     wait_apt
        echo_info "Instalowanie pakietow dla trybu deweloperskiego"
    #4lab>on     $aptcmd_pkg install \
    #4lab>on         #4lab>list deps4devel.txt
        echo_info "disabled: $aptcmd_pkg install"
    #4lab>on fi
    #4lab>on wait_apt
    echo_info "Usuwanie niepotrzebnych pakietow"
    $APT_GET $APT_Y autoremove || echo_stop "Usuwanie niepotrzebnych pakietow nie powiodlo sie"
    #4lab>on wait_apt
    echo_info "Czyszczenie pamieci podrecznej pakietow"
    $APT_GET clean || echo_stop "Czyszczenie pamieci podrecznej pakietow nie powiodlo sie"
}
wait_apt() {
    local max_wait
    max_wait=30
    if [ "$quick" -eq 1 ]; then
        max_wait=10
    fi
    local start_time
    start_time=$(date +%s)
    local current_time
    local elapsed_time

    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ $((elapsed_time % 10)) -eq 0 ]; then
            echo_info "Oczekiwanie na zwolnienie blokady APT (${elapsed_time}s)"
            fuser -v /var/lib/dpkg/lock-frontend 2>/dev/null || echo_error $LINENO "Nie mozna sprawdzic procesu blokujacego menedzer pakietow"
        fi
        if [ "$elapsed_time" -gt "$max_wait" ]; then
            pid=$(fuser /var/lib/dpkg/lock-frontend 2>/dev/null)
            if [ -n "$pid" ]; then
                if ! ps -p "$pid" > /dev/null 2>&1; then
                    rm -f /var/lib/dpkg/lock-frontend || echo_info "Nie mozna usunac blokady menedzera pakietow: $?"
                    rm -f /var/lib/dpkg/lock || echo_info "Nie mozna usunac blokady dpkg: $?"
                    dpkg --configure -a || echo_info "Nie mozna skonfigurowac pakietow: $?"
                    break
                else
                    echo_error $LINENO "Menedzer pakietow nadal zablokowany przez proces $pid"
                fi
            else
                echo_error $LINENO "Menedzer pakietow zablokowany przez nieznany proces"
            fi
        fi
        sleep 1
    done
}
SECONDS_START=$(date +%s)
do_umount=0
home_dir=home4copy
preparecztery=prepare4lab.sh
main() {
    echo_info "============================================================="
    echo_info "   copy4prepare v$WERSJA - Narzedzie Przygotowania Laboratorium Mentor"
    echo_info "============================================================="
    echo_info "Uzytkownik: $(whoami) | Host: $(hostname)"
                echo_info "============================================================="
    parse_arguments "$@"
                echo_info "============================================================="
    if [ "$job" = "help" ]; then
        show_help
        exit 0
                fi
    if [ "$job" = "bstatus" ]; then
     show_backup_status
     exit 0
                fi
    if [ "$job" = "clean" ]; then
     clean_home
     exit 0
                fi
    if [ "$job" = "update" ]; then
     update_itself
     exit 0
                fi
                echo_wait ""
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
    debian_upgrade
    if [ "$timeout" -gt 0 ]; then
        echo_info "Czekam $timeout sekund, podlacz pendrive z katalogiem home4copy..."
        sleep "$timeout"
    fi
    mnt_init
    if [ ! -d "$from/$home_dir" ]; then
        echo_error $LINENO "Katalog zrodlowy $from/$home_dir nie istnieje. Sprawdz, czy urzadzenie jest prawidlowo podlaczone i czy sciezka jest poprawna."
    fi
        run_rsync
    un_un
    if [ "$timeout" -gt 0 ]; then
            echo_stop "Odlacz pendrive, podlacz klawiature."
    fi
    verify_prepare_script
    prepare_args="$job"
    if [ "$target_root" != "/" ]; then
        prepare_args="$prepare_args --target $target_root"
    fi
    if [ "$nobackup" -eq 1 ]; then
        prepare_args="$prepare_args --no-backup"
    fi
    if [ "$quick" -eq 1 ]; then
        prepare_args="$prepare_args --quick"
    fi
    if [ "$debug" -eq 1 ]; then
        prepare_args="$prepare_args --debug"
    fi
    if [ "$username" != "pi" ]; then
        prepare_args="$prepare_args --username $username"
    fi
    if [ "$devel" -eq 1 ]; then
        prepare_args="$prepare_args --devel"
    fi
    if [ "$target_lan" -eq 1 ]; then
        prepare_args="$prepare_args --target-lan"
                fi
                set -o pipefail
                echo_info "Uruchamianie skryptu przygotowawczego: $run $prepare_args"
                if [ "$dry" -ne 1 ]; then
                                cd "$target" || echo_error $LINENO "Nie udalo sie zmienic katalogu na $target"
                                echo_info "Rozpoczynam wykonanie skryptu przygotowawczego..."
                                mkdir -p "$target/.mentor"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: $run $prepare_args" | tee "$target/.mentor/prepare4lab.lab.log" || true
                                eval "stdbuf -i0 -o0 -e0 $run $prepare_args" 2>&1 | tee -a "$target/.mentor/prepare4lab.lab.log"
                                exit_code=${PIPESTATUS[0]}
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] prepare4lab.sh exit code: $exit_code" | tee -a "$target/.mentor/prepare4lab.lab.log" || true
                                if [ "$exit_code" -eq 0 ]; then
                                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] prepare4lab.sh completed successfully" | tee -a "$target/.mentor/prepare4lab.lab.log" || true
                                                echo_info "Skrypt przygotowawczy zakonczony pomyslnie"
                                else
                                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] prepare4lab.sh failed with exit code: $exit_code" | tee -a "$target/.mentor/prepare4lab.lab.log" || true
                                                echo_error $LINENO "Wykonanie skryptu przygotowawczego nie powiodlo sie"
                                fi
                else
                                echo_info "Symulacja: Uruchomilbym: $run $prepare_args"
                fi
                set +o pipefail
    sync || true
    if [ "$quick" -eq 1 ]; then
        shutdown -r now || systemctl reboot || echo_error $LINENO "Natychmiastowy restart systemu nieudany"
        exit 0
    else
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
        echo_stop "RESTART SYSTEMU za minute"
        shutdown -r +1 || systemctl reboot || echo_error $LINENO "Restart systemu nieudany"
    fi
    sleep 90
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
}
echo_wait() {
    local message="$1"
    echo ""
    if [ "$quick" -eq 0 ] || [ "$debug" -eq 1 ]; then
        echo "$message"
        read -t 4 -r || true
    else
        echo "$message"
    fi
}
clean_home() {
    local pihome="$target_root"home/"$username"
    echo_info "Cleaning home directory: $pihome"
    if [ -d "$pihome/.mentor" ]; then
        echo_info "Removing .mentor directory"
        if [ "$dry" -ne 1 ]; then
            rm -rf "$pihome/.mentor" || echo_error $LINENO "Failed to remove .mentor directory"
        else
            echo_info "Dry run: Would remove $pihome/.mentor"
        fi
    else
        echo_info ".mentor directory does not exist"
    fi
    echo_info "Searching for files with '.lab' in the name"
    if [ "$dry" -ne 1 ]; then
        find "$pihome" -type f -name "*lab*" -print0 | while IFS= read -r -d '' file; do
            echo_info "Removing file: $file"
            rm -f "$file" || echo_info "Warning: Could not remove $file"
        done
    else
        find "$pihome" -type f -name "*lab*" -print | while IFS= read -r file; do
            echo_info "Dry run: Would remove $file"
        done
    fi
    if [ -f "$pihome/.mentor/prepare.lab.step" ]; then
        echo_info "Removing prepare.lab.step file"
        if [ "$dry" -ne 1 ]; then
            rm -f "$pihome/.mentor/prepare.lab.step" || echo_error $LINENO "Failed to remove prepare.lab.step file"
        else
            echo_info "Dry run: Would remove $pihome/.mentor/prepare.lab.step"
        fi
    else
        echo_info "prepare.lab.step file does not exist"
    fi
    if [ -d "$pihome/.source4rpi" ]; then
        echo_info "Removing .source4rpi directory"
        if [ "$dry" -ne 1 ]; then
            rm -rf "$pihome/.source4rpi" || echo_error $LINENO "Failed to remove .source4rpi directory"
        else
            echo_info "Dry run: Would remove $pihome/.source4rpi"
        fi
    else
        echo_info ".source4rpi directory does not exist"
    fi
    echo_info "Home directory cleanup completed"
}
update_itself() {
    echo_info "Updating copy4prepare.sh script"
    local script_path
    script_path=$(readlink -f "$0") || echo_error $LINENO "Failed to determine script path"
    local temp_script="/tmp/copy4prepare_new.sh"
    local backup_script
    backup_script="${script_path}.old.$(date +%s)"
    echo_info "Current script: $script_path"
    echo_info "Temporary download location: $temp_script"
    echo_info "Backup location: $backup_script"
    echo_info "Downloading new version from https://tinyurl.com/copy4prepare"
    if [ "$dry" -ne 1 ]; then
        if ! curl -L -o "$temp_script" "https://tinyurl.com/copy4prepare"; then
            echo_error $LINENO "Failed to download new version of the script"
        fi
    else
        echo_info "Dry run: Would download https://tinyurl.com/copy4prepare to $temp_script"
        echo_info "Dry run: Script update simulation completed"
        return 0
    fi
    if [ ! -f "$temp_script" ] || [ ! -s "$temp_script" ]; then
        echo_error $LINENO "Downloaded script is empty or does not exist"
    fi
    if ! head -n 1 "$temp_script" | grep -q "^#!/"; then
        echo_error $LINENO "Downloaded file does not appear to be a shell script"
    fi
    echo_info "Download successful, processing new script"
    if command -v dos2unix >/dev/null 2>&1; then
        echo_info "Converting line endings with dos2unix"
        dos2unix "$temp_script" || echo_info "Warning: dos2unix failed, continuing anyway"
    else
        echo_info "dos2unix not available, converting manually"
        sed -i 's/\r$//' "$temp_script" || echo_info "Warning: manual line ending conversion failed"
    fi
    echo_info "Setting executable permissions"
    chmod +x "$temp_script" || echo_error $LINENO "Failed to set executable permissions on new script"
    echo_info "Creating backup of current script"
    cp "$script_path" "$backup_script" || echo_error $LINENO "Failed to create backup of current script"
    echo_info "Replacing current script with new version"
    if ! mv "$temp_script" "$script_path"; then
        if ! mv "$backup_script" "$script_path"; then
            echo_error $LINENO "CRITICAL: Failed to restore backup! Script may be corrupted!"
        fi
        echo_error $LINENO "Script replacement failed"
    fi
    if [ ! -f "$script_path" ] || [ ! -x "$script_path" ]; then
        echo_error $LINENO "Script replacement verification failed"
    fi
    echo_info "Script update completed successfully"
    rm "$backup_script" || true
    echo_info "New version is now ready to use"
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
    if mountpoint -q "$path" 2>/dev/null; then
        return 1  # false - it's a mountpoint, not a device
    fi
    if [ -b "$path" ]; then
        return 0  # true - it's a block device
    fi
    local device_name
    device_name=$(basename "$path")
    local base_device=${device_name%[0-9]*}  # Remove partition number
    local removable_file="/sys/block/$base_device/removable"
    if [ -f "$removable_file" ] && [ "$(cat "$removable_file")" = "1" ]; then
        return 0  # true - removable device
    fi
    local device_path="/sys/block/$base_device"
    if [ -d "$device_path" ]; then
        local real_path
        real_path=$(readlink -f "$device_path")
        if [[ "$real_path" == *"/usb"* ]]; then
            return 0  # true - USB device
        fi
    fi
    if [[ "$path" == /dev/* ]]; then
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
                if [ ! -s "$backup_path" ]; then
                                echo_stop "Plik kopii zapasowej $backup_path jest pusty lub uszkodzony, pomijam przywracanie"
                                return 1
                fi
                if [ -f "$filepath" ] && ! cmp -s "$filepath" "$backup_path"; then
                                local safety_backup
                                safety_backup="${filepath}.before_restore.$(date +%s)"
                                echo_info "Tworzenie kopii bezpieczenstwa: $safety_backup"
                                cp "$filepath" "$safety_backup" || echo_info "Ostrzezenie: Nie udalo sie utworzyc kopii bezpieczenstwa"
                fi
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
    echo_info "Skanowanie systemu plikow w $target w poszukiwaniu plikow .lab.bak..."
    local restore_count=0
    local fail_count=0
    while IFS= read -r backup_file; do
        if [ -f "$backup_file" ]; then
            local original_file="${backup_file%.lab.bak}"
            echo_info "Znaleziono kopie zapasowa: $backup_file"
            if restore_from_backup "$original_file"; then
                restore_count=$((restore_count + 1))
                echo_info "✓ Przywrocono: $original_file"
            else
                fail_count=$((fail_count + 1))
                echo_info "✗ Nie udalo sie przywrocic: $original_file"
            fi
        fi
    done < <(find "$target" -name "*.lab.bak" -type f 2>/dev/null)
    echo_info "=== Podsumowanie przywracania ==="
    echo_info "Pomyslnie przywrocono: $restore_count plikow"
    echo_info "Nie udalo sie przywrocic: $fail_count plikow"
    echo_info "==================================="
    if [ $restore_count -gt 0 ]; then
        echo_info "Operacja przywracania zakonczona. Niektore uslugi moga wymagac ponownego uruchomienia."
        echo_info "Rozwaz wykonanie: sudo systemctl restart ssh"
    fi
}
show_backup_status() {
    echo_info "=== Backup Status Report ==="
    echo_info "Skanowanie systemu plikow w $target w poszukiwaniu plikow .lab.bak..."
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
    done < <(find "$target" -name "*.lab.bak" -type f 2>/dev/null)
    echo_info "=== Summary ==="
    echo_info "Total backups found: $backup_count"
    echo_info "Total backup size: $total_size bytes"
    echo_info "================="
}
handle_bclear() {
    echo_info "Clearing backup files..."
    echo_info "Skanowanie systemu plikow w $target w poszukiwaniu plikow .lab.bak..."
    local clear_count=0
    local fail_count=0
    local total_size=0
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
    done < <(find "$target" -name "*.lab.bak" -type f 2>/dev/null)
    echo_info "=== Clear Summary ==="
    echo_info "Successfully cleared: $clear_count files"
    echo_info "Failed to clear: $fail_count files"
    echo_info "Total space freed: $total_size bytes"
    echo_info "==================="
}
create_backup() {
    local filepath="$1"
    if [ "$nobackup" -eq 1 ]; then
        echo_info "--nobackup włączone. Pomijanie tworzenia kopii zapasowej dla: $filepath"
        return 0
    fi
    if [[ "$filepath" == *"home/$username/.mentor"* || "$filepath" == *"home/$username/.source4rpi"* ]]; then
        echo_info "Pomijanie tworzenia kopii zapasowej dla: $filepath (ścieżka wykluczona)"
        return 0
    fi
    local backup_path="${filepath}.lab.bak"
    echo_info "Przygotowanie kopii zapasowej: $filepath"
    if [ -f "$backup_path" ]; then
        echo_info "Kopia zapasowa już istnieje dla: $filepath, pomijanie"
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
        is_file "$filepath"
        if [ $last_is_file -ne 1 ]; then
            echo_info "Plik źródłowy nie istnieje, its ok: $filepath"
            return 0
        fi
        if [ "$dry" -ne 1 ]; then
            echo_info "Kopia zapasowa: $filepath do $backup_path"
            if ! cp -p "$filepath" "$backup_path"; then
                echo_error $LINENO "Nie udało się utworzyć pliku kopii zapasowej: $backup_path" "Tworzenie kopii zapasowej"
            fi
            if [ ! -f "$backup_path" ]; then
                echo_error $LINENO "Weryfikacja kopii zapasowej nie powiodła się: $backup_path nie istnieje" "Weryfikacja kopii zapasowej"
            fi
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
    is_file "$run"
    if [ $last_is_file -ne 1 ]; then
        echo_error $LINENO "Skrypt nie istnieje: $run" "Weryfikacja skryptu"
    fi
    echo_info "Sprawdzanie skladni: $run"
    if ! bash -n "$run"; then
        echo_error $LINENO "Blad skladni w skrypcie: $run" "Sprawdzanie skladni skryptu"
    else
        echo_info "Skladnia poprawna"
    fi
    wersja_in_script=$(grep -m 1 "^WERSJA=" "$run" | cut -d'=' -f2 | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//')
    if [ -z "$wersja_in_script" ]; then
        echo_info "Ostrzezenie: Nie mozna odczytac wersji ze skryptu"
        echo_wait "Wersja skryptu nie znaleziona, kontynuowac?"
    else
        echo_info "Znaleziona wersja skryptu: $wersja_in_script"
        if [ "$wersja_in_script" != "$WERSJA" ]; then
            echo_info "UWAGA: Wykryto niezgodnosc wersji!"
            echo_info "  Wersja copy4prepare.sh: $WERSJA"
            echo_info "  Wersja $preparecztery: $wersja_in_script"
            echo_stop "Niezgodnosc wersji" "Uruchomienie skryptu z inna wersja moze powodowac problemy"
        else
            echo_info "Weryfikacja wersji udana: Oba skrypty w wersji $WERSJA"
        fi
    fi
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
    echo_info "Przetwarzanie pliku (handle): $_file"
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
format_file_list() {
    local -n files_array=$1
    local formatted_list=""
    for file_path in "${files_array[@]}"; do
        local parent_dir filename formatted_path
        parent_dir=$(dirname "$file_path")
        filename=$(basename "$file_path")
        if [ "$parent_dir" = "." ]; then
            formatted_path="$filename"
        else
            formatted_path="$parent_dir/$filename"
        fi
        if [ -z "$formatted_list" ]; then
            formatted_list="$formatted_path"
        else
            formatted_list="$formatted_list, $formatted_path"
        fi
    done
    echo "$formatted_list"
}
run_rsync() {
    echo_info "Uruchamianie rsync dla katalogu home_dir (copy4prepare)"
    target="$target_root"home/"$username"/
    run="$target"mentor/prepare4lab/prepare4lab.sh
    local exclude_option
    exclude_option="--exclude=/root4rpi --exclude=/copy4prepare.sh --exclude=*.lab.bak"
    if [[ "$mntdir" == "$target"* ]]; then
        exclude_option="$exclude_option --exclude=/${mntdir#"$target"/}"
    fi
    local rcmd cont rsync_cmd dry_rsync_cmd
    rcmd="sudo -u $username rsync --relative -rtcvv"
    cont="$from/$home_dir/./ $target"
    rsync_cmd="$rcmd $exclude_option $cont"
    dry_rsync_cmd="$rcmd --dry-run $exclude_option $cont"
    echo_info "Wykonywanie suchego przebiegu, aby zidentyfikowac pliki do kopii zapasowej..."
    echo_info "SYMULACJA RSYNC: $from/$home_dir/ >> $target ($exclude_option)"
    local files_to_process=()
    echo_info "Pierwsza analiza rsync - zbieranie listy plikow do przetworzenia..."
    local dry_run_exit_code=0
    while IFS= read -r line; do
        echo "$line"  # Show live output
        local first_part second_part
        first_part="${line%% *}"
        second_part="${line#* }"
        if rsync_line_test "$first_part" "$second_part"; then
            true
        else
            files_to_process+=("$first_part")
        fi
    done < <($dry_rsync_cmd 2>&1; echo "RSYNC_EXIT_CODE:$?" >&2) 2> >(
        while IFS= read -r error_line; do
            if [[ "$error_line" == RSYNC_EXIT_CODE:* ]]; then
                dry_run_exit_code="${error_line#RSYNC_EXIT_CODE:}"
            else
                echo "$error_line" >&2
            fi
        done
    )
    if [ "$dry_run_exit_code" -ne 0 ]; then
        echo_error $LINENO "Symulacja rsync nie powiodla sie (kod: $dry_run_exit_code)" "Dry-run rsync failed"
    fi
    if [ ${#files_to_process[@]} -gt 0 ]; then
        local formatted_list
        formatted_list=$(format_file_list files_to_process)
        echo_stop "Lista plikow z pierwszej analizy: $formatted_list" \
            "Czy kontynuowac z przetwarzaniem ${#files_to_process[@]} plikow? Pliki zostana skopiowane i przetworzone."
        echo_info "Tworzenie kopii zapasowych..."
        for first_part in "${files_to_process[@]}"; do
            local fpath="$target$first_part"
            if [ "$dry" -ne 1 ]; then
                create_backup "$fpath"
            else
                echo_info "Symulacja: Utworzylbym kopie zapasowa pliku $fpath"
            fi
        done
    else
        echo_info "Brak plikow do przetworzenia"
    fi
    echo_info ""
    echo_info "rsync cmd: $rsync_cmd"
    echo_stop "Rozpoczynanie wlasciwej operacji rsync..." \
        "Czy kontynuowac z wykonaniem synchronizacji?"
    if [ "$dry" -ne 1 ]; then
        echo_info "Wykonywanie synchronizacji plikow..."
        local actual_processed_files=()
        local rsync_exit_code=0
        while IFS= read -r line; do
            echo "$line"  # Show live output
            local first_part second_part
            first_part="${line%% *}"
            second_part="${line#* }"
            if rsync_line_test "$first_part" "$second_part"; then
                true
            else
                actual_processed_files+=("$first_part")
            fi
        done < <($rsync_cmd 2>&1; echo "RSYNC_EXIT_CODE:$?" >&2) 2> >(
            while IFS= read -r error_line; do
                if [[ "$error_line" == RSYNC_EXIT_CODE:* ]]; then
                    rsync_exit_code="${error_line#RSYNC_EXIT_CODE:}"
                else
                    echo "$error_line" >&2
                fi
            done
        )
        if [ "$rsync_exit_code" -ne 0 ]; then
            echo_error $LINENO "Operacja rsync zakonczona z bledami (kod: $rsync_exit_code)" "Rsync execution failed"
        fi
        local missing_files=()
        for first_file in "${files_to_process[@]}"; do
            local found=0
            for second_file in "${actual_processed_files[@]}"; do
                if [ "$first_file" = "$second_file" ]; then
                    found=1
                    break
                fi
            done
            if [ $found -eq 0 ]; then
                missing_files+=("$first_file")
            fi
        done
        if [ ${#missing_files[@]} -gt 0 ]; then
            local formatted_missing_list
            formatted_missing_list=$(format_file_list missing_files)
            echo_error $LINENO "Pliki nieudane: $formatted_missing_list" "Critical files were not processed by rsync"
        else
            echo_info "Wszystkie pliki z pierwszej listy zostaly przetworzone"
        fi
        if [ ${#actual_processed_files[@]} -gt 0 ]; then
            local formatted_second_list
            formatted_second_list=$(format_file_list actual_processed_files)
            echo_stop "Lista plikow rzeczywiscie przetworzonych: $formatted_second_list" \
                "Czy kontynuowac z przetwarzaniem ${#actual_processed_files[@]} plikow?"
            local additional_files=()
            for file in "${actual_processed_files[@]}"; do
                local found=0
                for expected_file in "${files_to_process[@]}"; do
                    if [[ "$file" == "$expected_file" ]]; then
                        found=1
                        break
                    fi
                done
                if [ $found -eq 0 ]; then
                    additional_files+=("$file")
                fi
            done
            if [ ${#additional_files[@]} -gt 0 ]; then
                local formatted_additional_list
                formatted_additional_list=$(format_file_list additional_files)
                echo_error $LINENO "Nieoczekiwane dodatkowe pliki przetworzone: $formatted_additional_list" "Rsync processed unexpected files not in dry-run"
            else
                echo_info "Brak dodatkowych plikow - wszystkie przetworzone pliki byly oczekiwane"
            fi
        else
            if [ ${#files_to_process[@]} -gt 0 ]; then
                echo_error $LINENO "Brak plikow rzeczywiscie przetworzonych mimo oczekiwanych ${#files_to_process[@]} plikow" "Rsync failed to process any expected files"
            else
                echo_info "Brak plikow rzeczywiscie przetworzonych (zgodnie z oczekiwaniami)"
            fi
        fi
        echo_info "Przetwarzanie skopiowanych plikow..."
        for first_part in "${files_to_process[@]}"; do
            echo_info "Przetwarzanie pliku (rsync): $target$first_part"
            handle_file "$target$first_part" "$from/$home_dir/$first_part" || echo_error $LINENO "Nie udalo sie przetworzyc pliku: $target$first_part" "File processing failed"
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
        if mount | grep -q "$mntdir"; then
            echo_info "Odmontowywanie: $mntdir..."
            local max_attempts=3
            local attempt=1
            local unmounted=0
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
            if [ $unmounted -eq 0 ]; then
                echo_stop "Nie udalo sie odmontowac $mntdir po $max_attempts probach, kontynuuje mimo to" "Moze byc konieczne reczne odmontowanie pozniej"
            fi
        else
            echo_info "$mntdir nie jest zamontowany"
        fi
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
        mkdir -p "$mntdir" || echo_error $LINENO "Nie udało się utworzyć katalogu montowania $mntdir"
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
        for drive in {a..e}; do
            for partition in {1..4}; do
                local device_path="/dev/sd${drive}${partition}"
                if [ -e "$device_path" ]; then
                    echo_info "Znaleziono urzadzenie: $device_path"
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