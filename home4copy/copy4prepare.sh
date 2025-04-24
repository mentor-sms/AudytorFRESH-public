#!/bin/bash

WERSJA=1.0.0
echo "copy4prepare ver: $WERSJA"

do_umount=0
from=/dev/sda1
mntdir=/home/pi/mnt
file=prepare4lab.sh
target=/home/pi
quick=0
norun=0
nosync=0
job="user"
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
    echo "  --job <args>           Argumenty dla skryptu (default: user)"
    echo "                                               (alternatywy prepare4lab: debug)"
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

    echo "Handling file $_file"

    if [[ "${_file: -1}" == "/" || "${_sourcefile: -1}" == "/" ]]; then
        echo "Ignoring directory $_file"
        return 0
    fi

    if [[ ! -f "$_file" || ! -f "$_sourcefile" ]]; then
        echo "Either $_file or $_sourcefile does not exist. Please check the paths."
        return 1
    fi

    #echo "Files are different. Updating $_file with $_sourcefile."
    #sudo rm -f "$_file" || { echo "Failed to remove $_file"; return 1; }
    #sudo cp -rf "$_sourcefile" "$_file" || { echo "Failed to copy $_sourcefile to $_file"; return 1; }

    if ! file "$_file" | grep -q 'text'; then
        echo "$_file is not a text file."
        return 0
    fi

    echo "Converting $_file to Unix format"
    dos2unix -f -k "$_file" || { echo "Failed to convert $_file to Unix format."; return 1; }

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

run_rsync() {
    echo "Running rsync for home_dir (copy4prepare)"
    
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
    echo "RSYNC: $from/$home_dir/ >> $target ($exclude_option)"
    echo "CMD: $rsync_cmd"
    eval "$rsync_cmd" | while read -r line; do
        first_part="${line%% *}"
        second_part="${line#* }"
        
        echo ">$line;"

        # Check each character in first_part if it matches [a-zA-Z0-9./_]
        if [[ ! $first_part =~ ^[a-zA-Z0-9./_]+$ ]]; then
            continue
        fi

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

    if [[ "$norun" -eq 0 ]] && [[ -d $from/$home_dir/root4rpi ]]; then
      script_path=$(realpath "$0")
      if ! sudo bash -c "$script_path --from $from/$home_dir --mnt '' --file '' --target / --quick --norun --root --home_dir root4rpi --timeout 0" | tee copy4root.log; then
          echo "Error: The second run of the script failed."
          exit 1
      fi
    elif [[ "$norun" -eq 0 ]]; then
      echo "No root4rpi directory found in $from/$home_dir. Skipping the second run."
    fi
    
    un_un
}

un_un() {
    if [ "$do_umount" -eq 1 ]; then
        echo "Unmounting $mntdir"
        do_umount=0
        if ! umount "$mntdir"; then
            print_error "Failed to unmount $mntdir"
        fi
    fi
}

mnt_mnt() {
  echo "Creating mount directory $mntdir"
  if [[ $use_root -eq 1 ]]; then
      sudo -u pi mkdir -p "$mntdir"
  else
      mkdir -p "$mntdir"
  fi
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
    if [ "$use_root" -ne 1 ]; then
        sudo chown pi:pi "$target" || { print_error "Failed to change ownership of $target"; }
        mkdir -p "$target" || { print_error "Failed to write to $target"; }
    else 
        sudo mkdir -p "$target" || { print_error "Failed to write to $target"; }
    fi
    
    sudo rm -rf "$target"/.mentor || { true; }
    
    echo "Reloading systemd daemon"
    sudo systemctl daemon-reload
    sleep 5
    lsblk

    mnt_init

    if [ "$nosync" -ne 1 ]; then
        run_rsync
    fi

    un_un

    if [ "$norun" -ne 1 ]; then
        echo "Will run $run with job $job"

        if [ "$quick" -eq 0 ]; then
            read -rp "Press [Enter] to continue..."
            echo "Will run $run in 3, 2, 1..."
            sleep 3
        fi
        
        if [ -n "${job//[[:space:]]/}" ]; then
          job=""
        else
          job=" $job"
        fi
    
        echo "Running \"$run\" with job \"$job\"..."
        sleep 4
        "$run""$job" | tee /home/pi/.mentor/"$(basename "$run").log"
        sudo chown pi:pi /home/pi/.mentor/"$run".log
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
                mntdir="$2"
                echo "Option --mnt with value $mntdir"
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
            --home_dir)
                home_dir="$2"
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
            --root)
                use_root=1
                echo "Option --root"
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
        if ! umount "$mntdir"; then
            print_error "Failed to unmount $mntdir"
        fi
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