#!/bin/bash

device=/dev/sda1
do_umount=0
from=""
mnt=/mnt
file=prepare4lab.sh
target=/home/pi/.mentor
quick=0
norun=0
nosync=0
DESTRUCTIVE=0
job=release
dir=home4copy
timeout=30

show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --from <path>          Block device lub katalog (default: /dev/sda1)"
    echo "  --mnt <path>           Miejsce montowania dla urzadzenia from (default: /mnt)"
    echo "  --file <name>          Nazwa skryptu do rozruchu po kopiowaniu (default: prepare4lab.sh)"
    echo "  --target <path>        Katalog docelowy dla skryptu (default: /home/pi/.mentor)"
    echo "  --quick                Nie pyta przed rozruchem skryptu file"
    echo "  --norun                Nie uruchamia skryptu file"
    echo "  --nosync               Nie synchronizuje katalogow przed kopiowaniem"
    echo "  --DESTRUCTIVE          Usuwa wszystkie pliki z katalogu target"
    echo "  --dir <name>           Katalog docelowy w target (default: home4copy)"
    echo "  --timeout <seconds>    Czas oczekiwania przed rozpoczęciem procesu (default: 30)"
    echo "  --job <args>           Argumenty dla skryptu (default: release)"
    echo "                                               (alternatywy prepare4lab: quick, devel, debug)"
    echo "  --job                  ZAWSZE JAKO OSTATNI ARGUMENT!"
    echo "  --help                 Show this help message"
}

diff_files() {
  if [ "$DESTRUCTIVE" -eq 1 ]; then
    echo "Running in DESTRUCTIVE mode"
    # rsync -avq --dry-run --delete --progress "$from/$dir/" "$target/"
    echo "DESTRUCTIVE not implemented"
    exit 1
  else
    echo "Running in non-DESTRUCTIVE mode"
    # rsync -avq --dry-run --progress "$from/$dir/" "$target/"
    true
  fi
}

main() {
    echo "Starting script with arguments: $@"
    parse "$@"

    if [ "$(id -u)" -ne 0 ]; then
      echo "Wymaga sudo!"
      exit 1
    fi

    echo "Reloading systemd daemon"
    systemctl daemon-reload
    echo "Unmounting $mnt"
    umount "$mnt"

    echo "Creating target directory $target"
    mkdir -p "$target" || { print_error "Blad zapisu do $target"; }

    input_path="${device}"
    device=""

    if is_block_device "$input_path"; then
        echo "$input_path is a block device"
        device=$input_path
        if is_mounted "$input_path"; then
            echo "$input_path is already mounted"
            mnt=$(mount | grep "$input_path" | awk '{print $3}')
            set_from "$mnt"
        else
            echo "Mounting $input_path"
            do_umount=1
            mount_device "$input_path"
            set_from "$mnt"
        fi
    elif is_directory "$input_path"; then
        echo "$input_path is a directory"
        mnt=""
        set_from "$input_path"
    else
        print_error "Niewlasciwa sciezka: $input_path"
    fi

    if [ "$nosync" -ne 1 ]; then
        echo "Synchronizing files"
        diff_files
    fi

    if [ "$nosync" -ne 1 ] && [ $DESTRUCTIVE -eq 1 ]; then
        echo "Wszystkie pliki w $target zostana usuniete jezeli nie znajduja sie jednoczenie w $from/$dir!"
    fi

    echo "Start po $timeout sekundach od nacisniecia [Enter]. W tym czasie odlacz klawiature i podlacz pendrive z $dir."
    read -rp "Naciśnij [Enter], gdy bedziesz gotowy..."
    echo "Podlacz teraz pendrive zawierajacy $dir."
    if [ "$timeout" -gt 0 ]; then
        echo "Sleeping for $timeout seconds"
        sleep "$timeout"
    fi

    if [ "$nosync" -ne 1 ]; then
        if [ "$DESTRUCTIVE" -eq 1 ]; then
            echo "Running rsync in DESTRUCTIVE mode"
            # rsync -avq --delete --progress "$from/$dir/" "$target/"
            exit 1
        else
            echo "Running rsync in non-DESTRUCTIVE mode"
            rsync -avq --progress "$from/$dir/" "$target/"
        fi
    fi

    if [ "$do_umount" -eq 1 ]; then
        echo "Unmounting $mnt"
        if ! umount "$mnt"; then
            print_error "Nie udalo sie umount $mnt"
        fi
    fi

    ok=false

    echo "Converting $target/$file to Unix format"
    if ! dos2unix "$target/$file"; then
        print_error "Failed to convert file to Unix format"
    fi

    echo "Changing owner of $target to pi:pi"
    chown -R pi:pi "$target" || { print_error "Failed to change file owner"; }

    echo "Making $target/$file executable"
    chmod +x "$target/$file" || { print_error "Failed to make file executable"; }

    echo "Checking if $target/$file is a valid bash script"
    if ! bash -n "$target/$file"; then
        print_error "Plik nie jest poprawnym skryptem bash"
    fi

    if [ "$norun" -ne 1 ]; then
        echo "Running $target/$file with job $job"
        ok=true

        if [ "$ok" = true ]; then
            if [ "$quick" -eq 0 ]; then
                read -rp "Press [Enter] to continue..."
            fi
            "$target/$file" "$job" &
        else
            print_error "Failed to run the script"
        fi
    fi
}

parse() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --from)
                input_path="$2"
                echo "Option --from with value $input_path"
                shift 2
                ;;
            --mnt)
                mnt="$2"
                echo "Option --mnt with value $mnt"
                shift 2
                ;;
            --file)
                file="$2"
                echo "Option --file with value $file"
                shift 2
                ;;
            --target)
                target="$2"
                echo "Option --target with value $target"
                shift 2
                ;;
            --quick)
                quick=1
                echo "Option --quick"
                shift
                ;;
            --norun)
                norun=1
                echo "Option --norun"
                shift
                ;;
            --nosync)
                nosync=1
                echo "Option --nosync"
                shift
                ;;
            --DESTRUCTIVE)
                DESTRUCTIVE=1
                echo "Option --DESTRUCTIVE"
                shift
                ;;
            --job)
                shift
                job="$*"
                echo "Option --job with value $job"
                break
                ;;
            --dir)
                dir="$2"
                echo "Option --dir with value $dir"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                echo "Option --timeout with value $timeout"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

print_error() {
    echo "Error: $1"
    exit 1
}

is_block_device() {
    [ -b "$1" ]
}

is_directory() {
    [ -d "$1" ]
}

is_mounted() {
    mount | grep -q "on $1 "
}

mount_device() {
    echo "Mounting device $1 at $mnt"
    if ! mount "$1" "$mnt"; then
        print_error "Failed to mount $1 at $mnt"
    fi
}

set_from() {
    from="$1"
    echo "Setting from to $from"
}

main "$@"