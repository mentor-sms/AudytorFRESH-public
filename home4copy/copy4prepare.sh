#!/bin/bash

WERSJA=3.0.0
echo copy4prepare ver: $WERSJA

do_umount=0
from=/dev/sda1
mnt=/mnt
file=prepare4lab.sh
target=/home/pi/.mentor
quick=0
norun=0
nosync=0
restore=0
job=release
home_dir=home4copy
root_dir=home4copy/root4rpi
timeout=30
installed_file="/.mentor/installed"

show_help() {
    echo "Usage: sudo $0 [options]"
    echo "Options:"
    echo "  --from <path>          Block device lub katalog (default: /dev/sda1)"
    echo "  --mnt <path>           Miejsce montowania dla urzadzenia from (default: /mnt)"
    echo "  --file <name>          Nazwa skryptu do rozruchu po kopiowaniu (default: prepare4lab.sh)"
    echo "  --target <path>        Katalog docelowy dla skryptu (default: /home/pi/.mentor)"
    echo "  --quick                Nie pyta przed rozruchem skryptu file"
    echo "  --norun                Nie uruchamia skryptu file"
    echo "  --nosync               Nie synchronizuje katalogow przed kopiowaniem"
    echo "  --restore              Uzywa kopii zapasowej zamiast kopiowac (o ile istnieje, ignoruje --from i --mnt)"
    echo "  --home_dir <name>      Katalog docelowy w from (default: home4copy)"
    echo "  --root_dir <path>      Katalog do synchronizacji z root (default: home4copy/root4rpi)"
    echo "  --timeout <seconds>    Czas oczekiwania przed rozpoczeciem procesu (default: 30)"
    echo "  --job <args>           Argumenty dla skryptu (default: release)"
    echo "                                               (alternatywy prepare4lab: devel, debug)"
    echo "  --job                  ZAWSZE JAKO OSTATNI ARGUMENT!"
    echo "  --help                 Show this help message"
}

backup_files() {
    echo "Creating backup of files that will be overridden by rsync"
    rsync -avq --dry-run --progress "$from/$home_dir/" "$target/" | grep -E '^deleting|^>f' | while read -r line; do
        file=$(echo "$line" | awk '{print $2}')
        if [ -f "$target/$file" ]; then
            cp "$target/$file" "$target/$file.mbak"
        fi
    done
}

run_rsync() {
    echo "Running rsync for home_dir (copy4prepare.sh)"
    exclude_option=""
    if [ -n "$root_dir" ] && [ -n "$home_dir" ] && [[ "$root_dir" == "$home_dir/$root_dir"* ]]; then
        exclude_option="--exclude=${from#"$root_dir"/}"
        echo "default home rsync: rsync -avq --progress $exclude_option $from/ $target/"
        rsync -avq --progress "$exclude_option" "$from/$home_dir/" "$target/" | grep -E '^>f' | awk '{print $2}' | while read -r file; do
            echo "$target/$file" >> "$installed_file"
        done
    elif [ -n "$home_dir" ]; then
        echo "home rsync: rsync -avq --progress $from/$home_dir/ $target/"
        rsync -avq --progress "$from/$home_dir/" "$target/" | grep -E '^>f' | awk '{print $2}' | while read -r file; do
            echo "$target/$file" >> "$installed_file"
        done
    fi
    if [ -n "$root_dir" ]; then
        echo "root rsync: rsync -avq --progress $from/$root_dir/ $target/"
        rsync -avq --progress "$root_dir/" / | grep -E '^>f' | awk '{print $2}' | while read -r file; do
            echo "/$file" >> "$installed_file"
        done
    fi
}

restore_files() {
    echo "Restoring files from $installed_file"
    while read -r file; do
        if [ -f "$file.mbak" ]; then
            mv "$file.mbak" "$file"
        else
            rm -f "$file"
        fi
    done < "$installed_file"
}

main() {
    echo "Starting script with arguments: $*"
    parse "$@"

    if [ "$(id -u)" -ne 0 ]; then
      echo "Wymaga sudo!"
      show_help
      echo "Wymaga sudo!"
      exit 1
    fi

    if [ "$timeout" -ne 0 ]; then
      echo "Start po $timeout sekundach od nacisniecia [Enter]. W tym czasie odlacz klawiature i podlacz pendrive z $home_dir."
      read -rp "Nacisnij [Enter], gdy bedziesz gotowy..."
      echo "Podlacz teraz pendrive zawierajacy $home_dir."
      if [ "$timeout" -gt 0 ]; then
          echo "Sleeping for $timeout seconds"
          sleep "$timeout"
      fi
    fi

    echo "Creating target directory $target"
    mkdir -p "$target" || { print_error "Blad zapisu do $target"; }

    if [ "$restore" -eq 1 ]; then
        echo "Restoring files from $installed_file"
        restore_files
    elif [ "$nosync" -ne 1 ]; then
        echo "Creating backup of files that will be overridden by rsync"
        backup_files
    fi

    echo "Reloading systemd daemon"
    systemctl daemon-reload
    echo "$from"

    if is_block_device "$from"; then
        echo "$from is a block device"
        if is_mounted "$from"; then
            echo "$from is already mounted"
            mnt=$(mount | grep "$from" | awk '{print $3}')
            set_from "$mnt"
        else
            echo "Mounting $from"
            do_umount=1
            mount_device "$from"
            set_from "$mnt"
        fi
    elif is_directory "$from"; then
        echo "$from is a directory"
        mnt=""
        set_from "$from"
    else
        print_error "Niewlasciwa sciezka: $from"
    fi

    if [ "$nosync" -ne 1 ]; then
        run_rsync
    fi

    if [ "$do_umount" -eq 1 ]; then
        echo "Unmounting $mnt"
        if ! umount "$mnt"; then
            print_error "Nie udalo sie umount $mnt"
        fi
    fi

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
        echo "Will run $target/$file with job $job"

        if [ "$quick" -eq 0 ]; then
            read -rp "Press [Enter] to continue..."
            echo "Will run $target/$file in 3, 2, 1..."
            sleep 3
        fi
        echo "Running $target/$file with job $job..."
        "$target/$file" "$job" &
    fi
}

parse() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --from)
                from="$2"
                echo "Option --from with value $from"
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
            --restore)
                restore=1
                echo "Option --restore"
                shift
                ;;
            --job)
                shift
                job="$*"
                echo "Option --job with value $job"
                break
                ;;
            --home_dir)
                home_dir="$2"
                echo "Option --home_dir with value $home_dir"
                shift 2
                ;;
            --root_dir)
                root_dir="$2"
                echo "Option --root_dir with value $root_dir"
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