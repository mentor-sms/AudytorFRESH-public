#!/bin/bash

WERSJA=0.0.1
echo "copy4prepare ver: $WERSJA"

do_umount=0
from=/dev/sda1
mnt=/mnt
file=prepare4lab.sh
target=/home/pi
quick=0
norun=0
nosync=0
restore=0
job=release
home_dir=home4copy
root_dir=$home_dir/root4rpi
timeout=30
installed_file="/.mentor/installed"
run="/home/pi/.mentor/prepare4lab.sh"

show_help() {
    echo "Usage: sudo $0 [options]"
    echo "Options:"
    echo "  --from <path>          Block device or directory (default: /dev/sda1)"
    echo "  --mnt <path>           Mount point for the device (default: /mnt)"
    echo "  --file <name>          Script name to run after copying (default: prepare4lab.sh)"
    echo "  --target <path>        Target directory for the script (default: /home/pi)"
    echo "  --quick                Do not prompt before running the script"
    echo "  --norun                Do not run the script"
    echo "  --nosync               Do not sync directories before copying"
    echo "  --restore              Use backup instead of copying (if exists, ignores --from and --mnt)"
    echo "  --home_dir <name>      Source directory in from (default: home4copy)"
    echo "  --timeout <seconds>    Wait time before starting the process (default: 30)"
    echo "  --run <path>           Path to the script to run (default: /home/pi/.mentor/prepare4lab.sh)"
    echo "  --job <args>           Argumenty dla skryptu (default: release)"
    echo "                                               (alternatywy prepare4lab: devel, debug)"
    echo "  --job                  ZAWSZE JAKO OSTATNI ARGUMENT!"
    echo "  --help                 Show this help message"
}

backup_files() {
    echo "Creating backup of files that will be overridden by rsync"
}

handle_file() {
    local _file=$1
    echo "$target/$_file" >> "$installed_file"

    if file "$_file" | grep -q 'text'; then
        echo "Converting $_file to Unix format"
        if ! dos2unix "$_file"; then
            print_error "Failed to convert file to Unix format"
        fi
    fi

    if [[ "$_file" == *.sh ]]; then
        echo "Making $_file executable"
        chmod +x "$_file" || { print_error "Failed to make $_file executable"; }

        echo "Checking if $_file is a valid bash script"
        if ! sudo -u pi bash -n "$_file"; then
            print_error "$_file is not a valid bash script"
        fi
    fi
}

run_rsync() {
    script_path=$(realpath "$0")
    exclude_path="$from/$home_dir/copy4prepare.sh"
    echo "Running rsync for home_dir ($script_path)"
    exclude_option="--exclude=$exclude_path"
    
    run_rsync_task() {
        rsync_cmd=$1
        from=$2
        target=$3
        echo "Executing: $rsync_cmd"
        eval "$rsync_cmd" | while read -r line; do
            if echo "$line" | grep -q "$from" && echo "$line" | grep -q '^/' && ! echo "$line" | grep -q '/$'; then
                source_file=$(echo "$line" | awk '{print $NF}')
                echo "source_file: $source_file"
                echo "from: $from"
                relative_path="${source_file#$from/}"
                echo "relative_path: $relative_path"
                effective_path="$target/$relative_path"
                echo "Handling file: $effective_path"
                handle_file "$effective_path"
            fi
        done
    }
    
    if [ -n "$root_dir" ] && [ -n "$home_dir" ]; then
        exclude_option="$exclude_option --exclude=$from/$root_dir"
        rsync_cmd="sudo -u pi rsync -av --progress --relative $exclude_option $from/$home_dir/ $target/"
        run_rsync_task "$rsync_cmd" "$from/$home_dir" "$target"
    fi
    
    if [ -n "$home_dir" ] && [ -z "$root_dir" ]; then
        rsync_cmd="sudo -u pi rsync -av --progress --relative $exclude_option $from/$home_dir/ $target/"
        run_rsync_task "$rsync_cmd" "$from/$home_dir" "$target"
    fi
    
    if [ -n "$root_dir" ]; then
        rsync_cmd="sudo rsync -av --progress --relative $exclude_option $from/$root_dir/ /"
        run_rsync_task "$rsync_cmd" "$from/$root_dir" "/"
    fi

    echo "Listing contents of $from/$home_dir:"
    ls -la "$from/$home_dir"
    echo "Listing contents of $target:"
    ls -la "$target"
    if [ -n "$root_dir" ]; then
        echo "Listing contents of $from/$root_dir:"
        ls -la "$from/$root_dir"
    fi
}


main() {
    echo "Starting script with arguments: $*"
    parse "$@"

    if [ "$(id -u)" -ne 0 ]; then
      echo "Requires sudo!"
      show_help
      echo "Requires sudo!"
      exit 1
    fi

    if [ "$timeout" -ne 0 ]; then
      echo "Starting after $timeout seconds from pressing [Enter]. During this time, disconnect the keyboard and connect the USB drive with $home_dir."
      read -rp "Press [Enter] when ready..."
      echo "Now connect the USB drive containing $home_dir."
      if [ "$timeout" -gt 0 ]; then
          echo "Sleeping for $timeout seconds"
          sleep "$timeout"
      fi
    fi

    echo "Creating target directory $target"
    sudo -u pi mkdir -p "$target" || { print_error "Failed to write to $target"; }

    echo "Reloading systemd daemon"
    systemctl daemon-reload
    sleep 5
    lsblk
    echo FROM: "$from"

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
        print_error "Invalid path: $from"
    fi

    if [ "$restore" -eq 1 ]; then
        echo "Restoring files from $installed_file"
        restore_files
    elif [ "$nosync" -ne 1 ]; then
        echo "Creating backup of files that will be overridden by rsync"
        backup_files
    fi

    if [ "$nosync" -ne 1 ]; then
        run_rsync
    fi

    if [ "$do_umount" -eq 1 ]; then
        echo "Unmounting $mnt"
        if ! umount "$mnt"; then
            print_error "Failed to unmount $mnt"
        fi
    fi

    if [ "$norun" -ne 1 ]; then
        echo "Will run $run with job $job"

        if [ "$quick" -eq 0 ]; then
            read -rp "Press [Enter] to continue..."
            echo "Will run $run in 3, 2, 1..."
            sleep 3
        fi
        echo "Running $run with job $job..."
        sudo "$run" "$job"
    fi
}

restore_files() {
    echo "Restoring files from $installed_file"
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
            --home_dir)
                home_dir="$2"
                root_dir=$home_dir/root4rpi
                echo "Option --home_dir with value $home_dir"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                echo "Option --timeout with value $timeout"
                shift 2
                ;;
            --run)
                run="$2"
                echo "Option --run with value $run"
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

    if [[ $# -gt 0 ]]; then
        job="$*"
        echo "Option --job with value $job"
    fi
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