#!/bin/bash

WERSJA=6.6.6
echo "copy4prepare ver: $WERSJA"

do_umount=0
from=/dev/sda1
mntdir=/home/pi/mnt
file=prepare4lab.sh
target=/home/pi
quick=0
norun=0
nosync=0
job="urelease"
home_dir=home4copy
timeout=30
run="/home/pi/.mentor/prepare4lab.sh"
dry=0
brestore=0
bclear=0
nobackup=0

show_help() {
        echo "Usage: sudo $0 [options]"
        echo "Options:"
        echo "  --from <path>          Block device or directory (default: ${from})"
        echo "  --mnt <path>           Mount point for the device (default: ${mntdir})"
        echo "  --timeout <seconds>    Wait time before starting the process (default: ${timeout})"
        echo ""
        echo "  --norun                Do not run the script"
        echo "  --dry                  Dry sync directories"
        echo "  --nosync               Do not sync directories"
        echo ""
        echo "  --brestore             Restore from backup and exit"
        echo "  --nobackup             Do not backup files"
        echo "  --bclear               Remove backup files and exit"
        echo ""
        echo "  --job <args>           Argumenty dla skryptu (default: release)"
        echo "                                               (opcje prepare4lab: release, devel, debug)"
        echo "  --job                  ZAWSZE JAKO OSTATNI ARGUMENT!"
        echo ""
        echo "  --help                 Show this help message"
}

noquick() {
  if [ "$quick" -eq 0 ]; then
      echo "3, 2, 1... Ctrl+C to cancel."
      sleep 4
  fi
}

handle_file() {
    local _file=$1
    local _sourcefile=$2

    # Trim trailing spaces from file paths
    _file="${_file%"${_file##*[![:space:]]}"}"
    _sourcefile="${_sourcefile%"${_sourcefile##*[![:space:]]}"}"

    echo "Handling file $_file"

    if [[ ! -f "$_sourcefile" ]]; then
        echo "$_sourcefile does not exist. Please check the paths."
        return 1
    fi

    # Check if the files are identical    
    if cmp -s "$_file" "$_sourcefile"; then
      true
    else
      echo "Files are different after rsync (cmp): $_file and $_sourcefile"
      if diff -u "$_file" "$_sourcefile"; then
        echo "Files are identical after all: $_file and $_sourcefile"
      else
        echo "Files are different after rsync (diff): $_file and $_sourcefile"
        return 1
      fi
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
    if [ "$quick" -eq 0 ]; then
          sleep 1
    fi
}

create_backup() {
    local filepath="$1"
    if [ "$nobackup" -eq 1 ]; then
        echo "--nobackup enabled. Skipping backup creation for $filepath"
        if [ "$quick" -eq 0 ]; then
              sleep 1
        fi
        return
    fi
    local backup_path="${filepath}.mentorbak"

    # Check if filepath contains "home/pi/.mentor" or "home/pi/.source4rpi"
    if [[ "$filepath" == *"home/pi/.mentor"* || "$filepath" == *"home/pi/.source4rpi"* ]]; then
        echo "Skipping backup creation for $filepath (excluded path)"
        
        if [ "$quick" -eq 0 ]; then
              sleep 1
        fi
        return
    fi

    if [ ! -f "$backup_path" ] && [ -f "$filepath" ]; then
      if [ "$dry" -ne 1 ]; then
        echo "backup: $filepath to $backup_path"
        sudo -u pi cp "$filepath" "$backup_path" || { echo "Error: Failed to create backup file $backup_path."; exit 1; }
      else
        echo "bry: backup: $filepath to $backup_path"
      fi
      
      if [ "$quick" -eq 0 ]; then
          sleep 1
      fi
    else
        echo "Skipping backup creation of $filepath"
    fi
}

rsync_line_test() {
  local p1="$1"
  local p2="$2"

  # Ensure both p1 and p2 start with "/"
  p1="/${p1#/}"
  p2="/${p2#/}"

  # Check if the last character of p1 is "/"
  if [[ "${p1: -1}" == "/" ]]; then
    echo "-p1: $p1"
    return 1
  else
    echo "+p1: $p1"
  fi

  # Check if the last character of p2 is "/"
  if [[ "${p2: -1}" == "/" ]]; then
    echo "+p1: $p1"
    echo "-p2: $p2"
    return 1
  else
    echo "+p2: $p2"
  fi

  return 0
}

run_rsync() {
  echo "Running rsync for home_dir (copy4prepare)"

  local exclude_option
  exclude_option="--exclude=/root4rpi --exclude=/copy4prepare.sh"

  if [[ "$mntdir" == "$target/"* ]]; then
      exclude_option="$exclude_option --exclude=/${mntdir#"$target"/}"
  fi
  
  local dry_exclude_option
  dry_exclude_option="$exclude_option --exclude=/.source4rpi --exclude=/.mentor"
  
  local rcmd
  rcmd="sudo -u pi rsync -avvc --relative"
  local cont
  cont="$from/$home_dir/./ $target"

  local rsync_cmd
  rsync_cmd="$rcmd $exclude_option $cont"
  local dry_rsync_cmd
  dry_rsync_cmd="$rcmd --dry-run $dry_exclude_option $cont"

  local first_part
  local second_part
  $dry_rsync_cmd | while read -r line; do
    first_part="${line%% *}"  # Extract the first part
    second_part="${line#* }"  # Extract the second part

    if ! rsync_line_test "$first_part" "$second_part"; then
      continue
    fi
    
    local fpath
    fpath="$target/$first_part"
    
    if [ "$dry" -ne 1 ]; then
      create_backup "$fpath"
    fi
    
    if [ "$dry" -ne 1 ]; then
      echo "rm $fpath"
      rm -rf "$fpath" || { echo "Error: Failed to remove $fpath."; exit 1; }
    else
      echo "dry: rm $fpath"
    fi
  done

  echo "RSYNC: $from/$home_dir/ >> $target ($exclude_option)"
  echo "CMD: $rsync_cmd"
  $rsync_cmd | while read -r line; do
    first_part="${line%% *}"
    second_part="${line#* }"

    echo ">$line;"

    if ! rsync_line_test "$first_part" "$second_part"; then
      continue
    fi

    if [[ $first_part == "$second_part" ]]; then
      echo "+> $target/$first_part"
    elif [[ $second_part == *uptodate* ]]; then
      echo ".> $target/$first_part"
    else
      continue
    fi

    if ! handle_file "$target/$first_part" "$from/$home_dir/$first_part"; then
      print_error "Error occurred while handling $target/$first_part"
    fi
  done
}

un_un() {
  if [ "$do_umount" -eq 1 ]; then
    echo "Unmounting $mntdir"
    if [ "$quick" -eq 0 ]; then
      echo "3, 2, 1... Ctrl+C to cancel."
      sleep 4
    fi
    do_umount=0
    sudo umount "$mntdir" || { echo "err unmount $mntdir"; exit 1; }
    rm -rf "$mntdir" || { echo "err rm $mntdir"; exit 1; }
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

is_block_device() {
    local path="$1"
    if [ -b "$path" ]; then
        return 0
    else
        return 1
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

    if [ "$(id -u)" -ne 0 ]; then
      echo "Requires sudo!"
      show_help
      echo "Requires sudo!"
      exit 1
    fi
    
    parse "$@"
    
    echo "Will clean previous mentor files..."
    noquick
    
    if [ "$brestore" -eq 1 ]; then
        echo "Restoring configuration from backup files..."
        sudo find "/" -name "*.mentorbak" -exec sh -c '
            original_file="${1%.mentorbak}"
            echo "Restoring $original_file from $1"
            sudo -u pi mv "$1" "$original_file" || { echo "Error: Failed to restore $original_file from $1"; exit 1; }
        ' sh {} \;
        exit 0
    fi
    
    if [ "$bclear" -eq 1 ]; then
        echo "Clearing backup files..."
        sudo find "/" -name "*.mentorbak" -exec sh -c '
            echo "Removing $1"
            rm -f "$1" || { echo "Error: Failed to clear backup file $1"; exit 1; }
        ' sh {} \;
        exit 0
    fi

    if [ "$timeout" -ne 0 ]; then
      echo "Starting after $timeout seconds from pressing [Enter]. During this time, disconnect the keyboard and connect the USB drive with $home_dir."
      read -rp "Press [Enter] when ready..."
      echo "Now connect the USB drive containing $home_dir."
      echo "It will be safe to disconnect the USB drive after the script asks you to press [Enter] again."
      if [ "$timeout" -gt 0 ]; then
        echo ""
        echo "Sleeping for $timeout seconds..."
        read -rp "Press [Enter] to continue, Ctrl+C to cancel..."
        sleep "$timeout"
      fi
    fi
    
    rm -rf "$target"/.mentor || true
    rm -rf "$target"/.source4rpi || true
    rm -rf "$target"/.config/Mentor || true
    rm -rf "$target"/.prepare4lab.step || true
    rm -rf "$target"/.source4rpi || true
    echo "0" | sudo -u pi tee "$target"/.prepare4lab.step > /dev/null || { echo "Error: failed to write to '$target'/.prepare4lab.step"; exit 1; }
    cp -rf /etc/skel/.profile "$target"/. || true

    mnt_init
    noquick

    if [ "$nosync" -ne 1 ]; then
        run_rsync || { print_error "Failed to run rsync"; }
    fi

    un_un
    
    if [ "$norun" -ne 1 ]; then
      echo "Will run $run with job \"$job\""
      log_file="/home/pi/copy4prepare.log"
      echo "Log file: $log_file"
      if [ "$quick" -eq 0 ]; then
          echo "3, 2, 1... Ctrl+C to cancel."
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
            --brestore)
                brestore=1
                echo "Option --brestore"
                shift
                ;;
            --bclear)
                bclear=1
                echo "Option --bclear"
                shift
                ;;
            --nobackup)
                nobackup=1
                echo "Option --nobackup"
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
                if [ "$job" == "release" ]; then
                    job="urelease"
                elif [ "$job" == "devel" ]; then
                    job="udevel"
                elif [ "$job" == "debug" ]; then
                    job="udebug"
                else
                    echo "Uwaga! Unknown job: $job"
                    exit 1
                fi
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
  local message="$1"
  echo "Error: $message"
  exit 1
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
