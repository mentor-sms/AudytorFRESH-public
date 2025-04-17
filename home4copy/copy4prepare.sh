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
job=""
home_dir=home4copy
timeout=30
run="/home/pi/.mentor/prepare4lab.sh"
use_root=0

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
    echo "  --job <args>           Argumenty dla skryptu (default: \"\")"
    echo "                                               (alternatywy prepare4lab: release, devel, debug)"
    echo "  --root                 Use root user instead of pi"
    echo "  --job                  ZAWSZE JAKO OSTATNI ARGUMENT!"
    echo "  --help                 Show this help message"
}

handle_file() {
    local _file=$1
    local _sourcefile=$2

    # Trim trailing spaces from file paths
    _file="${_file%"${_file##*[![:space:]]}"}"
    _sourcefile="${_sourcefile%"${_sourcefile##*[![:space:]]}"}"

    echo "Handling file $_file" | tee -a copy4prepare.log

    if [[ "${_file: -1}" == "/" || "${_sourcefile: -1}" == "/" ]]; then
        echo "Ignoring directory $_file" | tee -a copy4prepare.log
        return 0
    fi

    if [[ ! -f "$_file" || ! -f "$_sourcefile" ]]; then
        echo "Either $_file or $_sourcefile does not exist. Please check the paths." | tee -a copy4prepare.log
        return 1
    fi

    local file_hash # AI: do not join declaration with assignment
    file_hash=$(sha256sum "$_file" | awk '{print $1}')
    
    local sourcefile_hash # AI: do not join declaration with assignment
    sourcefile_hash=$(sha256sum "$_sourcefile" | awk '{print $1}')

    if [[ "$file_hash" != "$sourcefile_hash" ]]; then
        echo "Files are different. Updating $_file with $_sourcefile." | tee -a copy4prepare.log
        sudo rm -f "$_file" || { echo "Failed to remove $_file" | tee -a copy4prepare.log; return 1; }
        sudo cp -rf "$_sourcefile" "$_file" || { echo "Failed to copy $_sourcefile to $_file" | tee -a copy4prepare.log; return 1; }
    fi

    if ! file "$_file" | grep -q 'text'; then
        echo "$_file is not a text file." | tee -a copy4prepare.log
        return 0
    fi

    echo "Converting $_file to Unix format" | tee -a copy4prepare.log
    dos2unix -f -k "$_file" || { echo "Failed to convert $_file to Unix format." | tee -a copy4prepare.log; return 1; }

    if [[ "$_file" == *.sh ]]; then
        echo "Making $_file executable" | tee -a copy4prepare.log
        chmod +x "$_file" || { echo "Failed to make $_file executable." | tee -a copy4prepare.log; return 1; }

        echo "Validating bash script $_file" | tee -a copy4prepare.log
        if ! bash -n "$_file"; then
            echo "$_file contains syntax errors." | tee -a copy4prepare.log
            return 1
        fi
    fi
}

run_rsync() {
    echo "Running rsync for home_dir (copy4prepare)" | tee -a copy4prepare.log
    
    exclude_option="--exclude=$home_dir/root4rpi --exclude=$target/copy4prepare.sh"
    
    if [[ "$mntdir" == "$target/"* ]]; then
        exclude_option="$exclude_option --exclude=${mntdir#"$target"/}"
    fi
    
    if [ "$use_root" -eq 1 ]; then
        rsync_cmd="sudo rsync -avv --relative $exclude_option $from/$home_dir/./ $target"
    else
        sudo chown pi:pi "$target" || { print_error "Failed to change ownership of $target"; }
        rsync_cmd="sudo rsync -avv --chown=pi:pi --relative $exclude_option $from/$home_dir/./ $target"
    fi
    echo "RSYNC: $from/$home_dir/ >> $target ($exclude_option)" | tee -a copy4prepare.log
    echo "CMD: $rsync_cmd" | tee -a copy4prepare.log
    eval "$rsync_cmd" | while read -r line; do
        first_part="${line%% *}"
        second_part="${line#* }"
        
        echo ">$line;" | tee -a copy4prepare.log

        # Check each character in first_part if it matches [a-zA-Z0-9./_]
        if [[ ! $first_part =~ ^[a-zA-Z0-9./_]+$ ]]; then
            continue
        fi

        if [[ $first_part == "$second_part" ]]; then
            echo "+> $target/$first_part" | tee -a copy4prepare.log
            if ! handle_file "$target/$first_part" "$from/$home_dir/$first_part"; then
                print_error "Error occurred while handling $target/$first_part"
            fi
        else
            if [[ $second_part == *uptodate* ]]; then
                echo ".> $target/$first_part" | tee -a copy4prepare.log
                if ! handle_file "$target/$first_part" "$from/$home_dir/$first_part"; then
                    print_error "Error occurred while handling $target/$first_part"
                fi
            fi
        fi
    done

    if [[ "$norun" -eq 0 ]] && [[ -d $from/$home_dir/root4rpi ]]; then
      script_path=$(realpath "$0")
      if ! sudo bash -c "$script_path --from $from/$home_dir --mnt '' --file '' --target / --quick --norun --root --home_dir root4rpi --timeout 0" | tee copy4root.log; then
          echo "Error: The second run of the script failed." | tee -a copy4prepare.log
          exit 1
      fi
    elif [[ "$norun" -eq 0 ]]; then
      echo "No root4rpi directory found in $from/$home_dir. Skipping the second run." | tee -a copy4prepare.log
    fi
    
    un_un
}

un_un() {
    if [ "$do_umount" -eq 1 ]; then
        echo "Unmounting $mntdir" | tee -a copy4prepare.log
        do_umount=0
        if ! umount "$mntdir"; then
            print_error "Failed to unmount $mntdir"
        fi
    fi
}

mnt_mnt() {
  echo "Creating mount directory $mntdir" | tee -a copy4prepare.log
  if [[ $use_root -eq 1 ]]; then
      sudo -u pi mkdir -p "$mntdir"
  else
      mkdir -p "$mntdir"
  fi
  if is_mounted "$from" "$mntdir"; then
      echo "$from is already mounted" | tee -a copy4prepare.log
      mntdir=$(mount | grep "$from" | awk '{print $3}')
      set_from "$mntdir"
  else
      echo "Mounting $from" | tee -a copy4prepare.log

      echo "Mounting device $from at $mntdir" | tee -a copy4prepare.log
      if ! sudo mount "$from" "$mntdir"; then
          print_error "Failed to mount $from at $mntdir"
      else
          echo "Mounted $from at $mntdir" | tee -a copy4prepare.log
          do_umount=1
      fi
      set_from "$mntdir"
  fi
}

mnt_init() {
  if is_block_device "$from"; then
      echo "$from is a block device" | tee -a copy4prepare.log
      mnt_mnt "$from"
  elif is_directory "$from"; then
      echo "$from is a directory" | tee -a copy4prepare.log
      set_from "$from"
  else
      if echo "$from" | grep -q '/dev/sd[a-z]1'; then
          echo "Trying to find a block device for $from" | tee -a copy4prepare.log
          gotit=0
          for dev in /dev/sd*1; do
              if is_block_device "$dev"; then
                  echo "Found block device $dev" | tee -a copy4prepare.log
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
    echo "Starting script with arguments: $*" | tee -a copy4prepare.log
    parse "$@"

    if [ "$(id -u)" -ne 0 ]; then
      echo "Requires sudo!" | tee -a copy4prepare.log
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
          echo "Sleeping for $timeout seconds" | tee -a copy4prepare.log
          sleep "$timeout"
      fi
    fi

    echo "Creating target directory $target" | tee -a copy4prepare.log
    sudo mkdir -p "$target" || { print_error "Failed to write to $target"; }
    if [ "$use_root" -ne 1 ]; then
        sudo chown pi:pi "$target" || { print_error "Failed to change ownership of $target"; }
    fi
    echo "Reloading systemd daemon" | tee -a copy4prepare.log
    sudo systemctl daemon-reload
    sleep 5
    lsblk

    mnt_init

    if [ "$nosync" -ne 1 ]; then
        run_rsync
    fi

    un_un

    if [ "$norun" -ne 1 ]; then
        echo "Will run $run with job $job" | tee -a copy4prepare.log

        if [ "$quick" -eq 0 ]; then
            read -rp "Press [Enter] to continue..."
            echo "Will run $run in 3, 2, 1..." | tee -a copy4prepare.log
            sleep 3
        fi
        if [[ -z "${job//[[:space:]]/}" ]]; then
            echo "Running $run with job \"$job\"..." | tee -a copy4prepare.log
            bash -c "$run \"$job\" | tee -a \"$target\"/.mentor/prepare4lab.log"
        else
            echo "Running $run with job \"auto\"..." | tee -a copy4prepare.log
            bash -c "$run | tee -a \"$target\"/.mentor/prepare4lab.log"
        fi
    fi
}

parse() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --from)
                from="$2"
                echo "Option --from with value $from" | tee -a copy4prepare.log
                shift 2
                ;;
            --mnt)
                mntdir="$2"
                echo "Option --mnt with value $mntdir" | tee -a copy4prepare.log
                shift 2
                ;;
            --file)
                file="$2"
                echo "Option --file with value $file" | tee -a copy4prepare.log
                shift 2
                ;;
            --target)
                target="$2"
                echo "Option --target with value $target" | tee -a copy4prepare.log
                shift 2
                ;;
            --quick)
                quick=1
                echo "Option --quick" | tee -a copy4prepare.log
                shift
                ;;
            --norun)
                norun=1
                echo "Option --norun" | tee -a copy4prepare.log
                shift
                ;;
            --nosync)
                nosync=1
                echo "Option --nosync" | tee -a copy4prepare.log
                shift
                ;;
            --home_dir)
                home_dir="$2"
                echo "Option --home_dir with value $home_dir" | tee -a copy4prepare.log
                shift 2
                ;;
            --timeout)
                timeout="$2"
                echo "Option --timeout with value $timeout" | tee -a copy4prepare.log
                shift 2
                ;;
            --run)
                run="$2"
                echo "Option --run with value $run" | tee -a copy4prepare.log
                shift 2
                ;;
            --root)
                use_root=1
                echo "Option --root" | tee -a copy4prepare.log
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            --job)
                shift
                break
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Unknown option: $1" | tee -a copy4prepare.log
                show_help
                exit 1
                ;;
        esac
    done

    if [[ $# -gt 0 ]]; then
        job="$*"
        echo "Option --job with value $job" | tee -a copy4prepare.log
    fi
}

print_error() {
    if [ "$do_umount" -eq 1 ]; then
        echo "Unmounting $mntdir" | tee -a copy4prepare.log
        if ! umount "$mntdir"; then
            print_error "Failed to unmount $mntdir"
        fi
    fi
    echo "Error: $1" | tee -a copy4prepare.log
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
    echo FROM: "$from" | tee -a copy4prepare.log
}

main "$@"