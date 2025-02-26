#!/bin/bash

WERSJA=0.0.1
echo "copy4prepare ver: $WERSJA"

do_umount=0
from=/dev/sda1
mnt=/home/pi/mnt
file=prepare4lab.sh
target=/home/pi
quick=0
norun=0
nosync=0
job=release
home_dir=home4copy
timeout=30
run="/home/pi/.mentor/prepare4lab.sh"

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
    echo "                                               (alternatywy prepare4lab: devel, debug)"
    echo "  --job                  ZAWSZE JAKO OSTATNI ARGUMENT!"
    echo "  --help                 Show this help message"
}

handle_file() {
    local _file=$1

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
    exclude_path="$home_dir/copy4prepare.sh"
    echo "Running rsync for home_dir ($script_path)"
    exclude_option="--exclude=$home_dir/root4rpi --exclude=$exclude_path"

    echo "Listing contents of target $target:"
    ls -a "$target"
    
    rsync_cmd="sudo -u pi rsync -avv --relative $exclude_option $from/$home_dir/./ $target"
    echo "RSYNC: $from/./$home_dir/ >> $target ($exclude_option)"
    eval "$rsync_cmd" | while read -r line; do
        echo "?> $line"
        
        if [[ ! $line =~ ^[0-9a-zA-Z.] ]]; then
            continue
        fi
        
        first_part="${line%% *}"
        second_part="${line#* }"
    
        # Check each character in first_part if it matches [a-zA-Z0-9./_]
        if [[ ! $first_part =~ ^[a-zA-Z0-9./_]+$ ]]; then
            continue
        fi
    
        if [[ -z $second_part || $second_part == *uptodate* ]]; then
            echo "+> $target/$home_dir/$first_part"
            handle_file "$target/$first_part"
        fi
    done

    
    echo "Listing contents of home4copy $from/$home_dir:"
    ls -a "$from/$home_dir"
    echo ""
    echo "Listing contents of root4rpi $from/$home_dir/root4rpi:"
    mkdir -p "$from/$home_dir/root4rpi"
    ls -a "$from/$home_dir"
    echo ""
    echo "Listing contents of target $target:"
    ls -a "$target"
    echo ""
    
    if ! sudo bash -c "$script_path --from $from --mnt $mnt --file '' --target / --quick --norun --home_dir $home_dir/root4rpi --timeout 0"; then
        echo "Error: The second run of the script failed."
        exit 1
    fi
}

mnt_mnt() {
  echo "Creating mount directory $mnt"
  mkdir -p "$mnt"
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
}

mnt_init() {
  echo FROM: "$from"
  if is_block_device "$from"; then
      echo "$from is a block device"
      mnt_mnt
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
                  if is_mounted "$dev"; then
                      echo "$dev is already mounted"
                      mnt=$(mount | grep "$dev" | awk '{print $3}')
                      set_from "$mnt"
                  else
                      echo "Mounting $dev"
                      do_umount=1
                      mount_device "$dev"
                      set_from "$mnt"
                  fi
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
    sudo -u pi mkdir -p "$target" || { print_error "Failed to write to $target/$home_dir"; }
    ls -a "$target"
    echo ""

    echo "Reloading systemd daemon"
    systemctl daemon-reload
    sleep 5
    lsblk
    
    mnt_init
    
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
    if ! sudo mount "$1" "$mnt"; then
        print_error "Failed to mount $1 at $mnt"
    else 
        echo "Mounted $1 at $mnt"
        echo "Listing contents of $mnt:"
        ls -a "$mnt"
        echo ""
    fi
}

set_from() {
    from="$1"
    echo FROM: "$from"
}

main "$@"