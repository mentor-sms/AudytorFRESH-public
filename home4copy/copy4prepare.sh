#!/bin/bash

WERSJA=2.0.0
echo "copy4prepare ver: $WERSJA"

do_umount=0
from=/dev/sda1
mntdir=/home/pi/mnt
file=prepare4lab.sh
target=/home/pi
quick=0
norun=0
nosync=0
job="release"
home_dir=home4copy
timeout=30
run="/home/pi/.mentor/prepare4lab.sh"
dry=0

show_help() {
    echo "Usage: sudo $0 [options]"
    echo "Options:"
    echo "  --from <path>          Block device or directory (default: /dev/sda1)"
    echo "  --mnt <path>           Mount point for the device (default: /home/pi/mnt)"
    echo "  --file <name>          Script name to run after copying (default: prepare4lab.sh)"
    echo "  --target <path>        Target directory for the script (default: /home/pi)"
    echo "  --quick                Do not prompt before running the script"
    echo "  --norun                Do not run the script"
    echo "  --nosync               Do not sync directories before copying"
    echo "  --home_dir <name>      Source directory in from (default: home4copy)"
    echo "  --timeout <seconds>    Wait time before starting the process (default: 30)"
    echo "  --run <path>           Path to the script to run (default: /home/pi/.mentor/prepare4lab.sh)"
    echo "  --job <args>           Argumenty dla skryptu (default: release)"
    echo "                                               (alternatywy prepare4lab: devel, debug, RELEASE...)"
    echo "  --job                  ZAWSZE JAKO OSTATNI ARGUMENT!"
    echo "  --help                 Show this help message"
}

handle_file() {
    local _file=$1
    local _sourcefile=$2

    # Trim trailing spaces from file paths
    _file="${_file%"${_file##*[![:space:]]}"}"
    _sourcefile="${_sourcefile%"${_sourcefile##*[![:space:]]}"}"

    echo "Handling file $_file"

    if [[ ! -f "$_file" || ! -f "$_sourcefile" ]]; then
        echo "Either $_file or $_sourcefile does not exist. Please check the paths."
        return 1
    fi

    # Check if the files are identical    
    if cmp -s "$_file" "$_sourcefile"; then
      true
    else
      echo "Files are different after rsync: $_file and $_sourcefile"
      return 1
    fi

    echo "Converting $_file to Unix format"
    dos2unix -f -k "$_file" || true

    if [[ "$_file" == *.sh ]]; then
        echo "Making $_file executable"
        chmod +x "$_file" || { echo "Failed to make $_file executable."; return 1; }

        echo "Validating bash script $_file"
        if ! bash -n "$_file"; then
            echo "$_file contains syntax errors."
            return 1
        fi
    fi
}

create_backup() {
    local filepath="$1"
    local backup_path="${filepath}.bak"
    if [ ! -f "$backup_path" ]; then
      if [ "$dry" -ne 1 ]; then
        echo "Backing up $filepath to $backup_path"
        sudo -u pi cp "$filepath" "$backup_path" || { echo "Error: Failed to create backup file $backup_path."; exit 1; }
      else
        echo "--dry mode enabled. Skipping backup creation."
      fi
    else
      echo "Backup file $backup_path already exists. Skipping backup creation."
    fi
    
    if [ "$dry" -ne 1 ]; then
      echo "Removing up $filepath"
      rm -rf "$filepath" "$backup_path" || { echo "Error: Failed to remove $filepath."; exit 1; }
    fi
}

run_rsync() {
  echo "Running rsync for home_dir (copy4prepare)"

  exclude_option="--exclude=$home_dir/root4rpi --exclude=$target/copy4prepare.sh"

  if [[ "$mntdir" == "$target/"* ]]; then
      exclude_option="$exclude_option --exclude=${mntdir#"$target"/}"
  fi

  rsync_cmd="sudo -u pi rsync -avv --relative $exclude_option $from/$home_dir/./ $target"

  # Perform a dry-run to identify files being replaced or updated
  eval "$rsync_cmd --dry-run" | while read -r line; do
    first_part="${line%% *}"  # Extract the first part
    second_part="${line#* }"  # Extract the second part

    # Check if first_part is valid (matches [a-zA-Z0-9./_])
    if [[ ! $first_part =~ ^[a-zA-Z0-9./_]+$ ]]; then
      continue
    fi
    
    local AAA=$target/$first_part
    local BBB=$from/$home_dir/$first_part
    if [[ "${AAA: -1}" == "/" || "${BBB: -1}" == "/" ]]; then
      continue
    fi

    # Create backups for files that are being replaced or updated
    if [[ $first_part == "$second_part" ]]; then
      create_backup "$target/$first_part"
    else
      if [[ $second_part == *uptodate* ]]; then
        create_backup "$target/$first_part"
      fi
    fi
  done

  # Now perform the actual rsync operation
  if [ "$dry" -eq 0 ]; then
    echo "RSYNC: $from/$home_dir/ >> $target ($exclude_option)"
    echo "CMD: $rsync_cmd"
    eval "$rsync_cmd" | while read -r line; do
      first_part="${line%% *}"
      second_part="${line#* }"

      echo ">$line;"

      # Check if first_part is valid (matches [a-zA-Z0-9./_])
      if [[ ! $first_part =~ ^[a-zA-Z0-9./_]+$ ]]; then
        continue
      fi
      
      local AAA=$target/$first_part
      local BBB=$from/$home_dir/$first_part
      if [[ "${AAA: -1}" == "/" || "${BBB: -1}" == "/" ]]; then
        continue
      fi

      # Handle files as needed during the actual rsync
      if [[ $first_part == "$second_part" ]]; then
        echo "+> $target/$first_part"
        if ! handle_file "$target/$first_part" "$from/$home_dir/$first_part"; then
          print_error "Error occurred while handling $target/$first_part"
        fi
      else
        if [[ $second_part == *uptodate* ]]; then
          echo ".> $target/$first_part"
          if ! handle_file "$target/$first_part" "$from/$home_dir/$first_part"; then
            print_error "Error occurred while handling $target/$first_part"
          fi
        fi
      fi
    done
  else
    echo "--dry mode enabled. Skipping actual rsync operation."
  fi
}

un_un() {
    if [ "$do_umount" -eq 1 ]; then
        echo "Unmounting $mntdir"
        do_umount=0
        umount "$mntdir" || true
    fi
}

mnt_mnt() {
  echo "Creating mount directory $mntdir"
  sudo -u pi mkdir -p "$mntdir"
  if is_mounted "$from" "$mntdir"; then
      echo "$from is already mounted"
      mntdir=$(mount | grep "$from" | awk '{print $3}')
      set_from "$mntdir"
  else
      echo "Mounting $from"

      echo "Mounting device $from at $mntdir"
      if ! sudo mount "$from" "$mntdir"; then
          print_error "Failed to mount $from at $mntdir"
      else
          echo "Mounted $from at $mntdir"
          do_umount=1
      fi
      set_from "$mntdir"
  fi
}

mnt_init() {
  if is_block_device "$from"; then
      echo "$from is a block device"
      mnt_mnt "$from"
  elif is_directory "$from"; then
      echo "$from is a directory"
      set_from "$from"
  else
      if echo "$from" | grep -q '/dev/sd[a-z]1'; then
          echo "Trying to find a block device for $from"
          gotit=0
          for dev in /dev/sd*1; do
              if is_block_device "$dev"; then
                  echo "Found block device $dev"
                  gotit=1
                  from=$dev
                  mnt_mnt "$mntdir"
                  break
              fi
          done
          if [ "$gotit" -eq 0 ]; then
              print_error "Failed to find a block device for $from"
          fi
      else
        print_error "Invalid path: $from"
      fi
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
      echo "It will be safe to disconnect the USB drive after the script asks you to press [Enter] again."
      if [ "$timeout" -gt 0 ]; then
          echo "Sleeping for $timeout seconds"
          sleep "$timeout"
      fi
    fi

    echo "Creating target directory $target"
    sudo -u pi mkdir -p "$target" || { print_error "Failed to write to $target"; }
    
    rm -rf "$target"/.mentor || true
    
    echo "Reloading systemd daemon"
    systemctl daemon-reload
    lsblk
    sleep 4

    mnt_init

    if [ "$nosync" -ne 1 ]; then
        run_rsync || { print_error "Failed to run rsync"; }
    fi

    un_un
    
    if [ "$norun" -ne 1 ]; then
      echo "Will run $run with job \"$job\""
      log_file="/home/pi/copy4prepare.run"
      echo "Log file: $log_file"
      if [ "$quick" -eq 0 ]; then
          read -rp "Press [Enter] to continue, Ctrl+C to cancel..."
          echo "3, 2, 1..."
          sleep 4
      fi

      if [ "$dry" -eq 0 ]; then
        eval "$run" "$job" 2>&1 | sudo -u pi tee "$log_file"
    else
        echo "--dry mode enabled. Skipping script execution."
    fi
  fi
  exit 0
}

parse() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --from)
                if [[ -z "$2" ]]; then
                    echo "Error: Missing value for --from"
                    exit 1
                fi
                from="$2"
                echo "Option --from with value $from"
                shift 2
                ;;
            --mnt)
                if [[ -z "$2" ]]; then
                    echo "Error: Missing value for --mnt"
                    exit 1
                fi
                mntdir="$2"
                echo "Option --mnt with value $mntdir"
                shift 2
                ;;
            --file)
                if [[ -z "$2" ]]; then
                    echo "Error: Missing value for --file"
                    exit 1
                fi
                file="$2"
                echo "Option --file with value $file"
                shift 2
                ;;
            --target)
                if [[ -z "$2" ]]; then
                    echo "Error: Missing value for --target"
                    exit 1
                fi
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
            --home_dir)
                if [[ -z "$2" ]]; then
                    echo "Error: Missing value for --home_dir"
                    exit 1
                fi
                home_dir="$2"
                echo "Option --home_dir with value $home_dir"
                shift 2
                ;;
            --timeout)
                if [[ -z "$2" ]]; then
                    echo "Error: Missing value for --timeout"
                    exit 1
                fi
                timeout="$2"
                echo "Option --timeout with value $timeout"
                shift 2
                ;;
            --run)
                if [[ -z "$2" ]]; then
                    echo "Error: Missing value for --run"
                    exit 1
                fi
                run="$2"
                echo "Option --run with value $run"
                shift 2
                ;;
            --dry)
                dry=1
                echo "Option --dry"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            --job)
                shift
                job="$*"
                echo "Option --job with value $job"
                break
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
    if [ "$do_umount" -eq 1 ]; then
        echo "Unmounting $mntdir"
        umount "$mntdir" || true
        do_umount=0
    fi
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
    mount | grep -q "$1 on $2"
}

set_from() {
    from="$1"
    echo FROM: "$from"
}

main "$@"