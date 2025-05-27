#!/bin/bash
###############################################################################
# copy4prepare.sh - Mentor Lab Preparation Utility
# 
# This script prepares Raspberry Pi devices for lab environments by copying
# necessary files from a source location and configuring the system.
# 
# Features:
# - Copy files from USB drive or directory to target location
# - Create backups of modified files
# - Mount and unmount block devices
# - Run preparation scripts after file copying
# - Restore from backups or clean backup files
#
# Usage: sudo ./copy4prepare.sh [options]
# See --help for available options
###############################################################################

# Script version
WERSJA=7.7.0
echo "copy4prepare ver: $WERSJA (enhanced error handling, backup protection)"

# Set default values for all parameters
do_umount=0                          # Flag to track if we mounted a device
from=/dev/sda1                       # Source location (block device or directory)
mntdir=/home/pi/mnt                  # Mount point for block devices
target=/home/pi                      # Target directory for file operations
home_dir=home4copy                   # Directory name on source containing files
file=prepare4lab.sh                  # Script filename to run after copying
quick=0                              # Flag to skip confirmation delays
norun=0                              # Flag to skip running scripts
nosync=0                             # Flag to skip rsync operations
job="urelease"                       # Default job type for the script
timeout=0                            # Wait time before starting operations
run="/home/pi/.mentor/prepare4lab.sh" # Path to the script to run
dry=0                                # Flag for simulation mode (no changes)
brestore=0                           # Flag to restore from backups and exit
bclear=0                             # Flag to clear backup files and exit
nobackup=0                           # Flag to skip creating backup files

# Initialize error and warning counters
error_count=0
warning_count=0

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════════
║ copy4prepare.sh v$WERSJA - Mentor Lab Preparation Utility
╠══════════════════════════════════════════════════════════════════════════════
║ Usage: sudo $0 [options]
║
║ Main Options:
║   --from <path>          Block device or directory (default: ${from})
║   --mnt <path>           Mount point for the device (default: ${mntdir})
║   --target <path>        Target directory (default: ${target})
║   --home_dir <dir>       Home directory name (default: ${home_dir})
║   --file <filename>      Script filename (default: ${file})
║   --timeout <seconds>    Wait time before starting the process (default: ${timeout})
║
║ Process Control:
║   --quick                Skip confirmation delays
║   --norun                Do not run the script after copying files
║   --dry                  Simulate operations without making changes
║   --nosync               Do not sync directories (skip rsync)
║
║ Backup Management:
║   --brestore             Restore from backup files and exit
║   --nobackup             Do not create backup files during operation
║   --bclear               Remove all backup files and exit
║
║ Script Execution:
║   --run <path>           Path to the script to run (default: ${run})
║   --job <args>           Arguments for the script (default: ${job})
║                          Known job types: release, devel, debug
║
║ NOTE: --job must always be the LAST ARGUMENT!
║
║ Help:
║   --help                 Show this help message
║
║ Examples:
║   sudo $0 --from /dev/sda1 --quick
║   sudo $0 --brestore
║   sudo $0 --job release
╚══════════════════════════════════════════════════════════════════════════════
EOF
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

    # Check if source file exists using is_file
    if ! is_file "$_sourcefile"; then
        print_warning "$_sourcefile does not exist. Please check the paths."
        return 1
    fi

    # Check if the files are identical using cmp (faster binary comparison)
    if ! cmp -s "$_file" "$_sourcefile"; then
        echo "Files are different after rsync: $_file and $_sourcefile"
        # If verbose debugging is needed, uncomment the diff line
        # diff -u "$_file" "$_sourcefile" || true
        # Continue processing even if files are different, as rsync might have modified them
    fi

    # Convert to Unix format (safely)
    echo "Converting $_file to Unix format"
    if ! dos2unix -f -k "$_file" 2>/dev/null; then
        echo "Warning: dos2unix conversion issue with $_file, continuing"
    fi

    # Handle special files
    if [[ "$_file" == *.sh ]]; then
        echo "Making $_file executable"
        if ! chmod +x "$_file"; then
            echo "Warning: Failed to make $_file executable, continuing"
        fi

        echo "Validating bash script $_file"
        if ! bash -n "$_file"; then
            echo "Warning: $_file contains syntax errors, continuing anyway"
            # Don't return error - let the script continue even with syntax errors
            # This allows more files to be processed even if some have issues
        fi
    fi
    
    # Optional sleep for monitoring
    [ "$timeout" -ne 0 ] && sleep 1
    
    return 0
}

create_backup() {
    local filepath="$1"
    if [ "$nobackup" -eq 1 ]; then
        echo "--nobackup enabled. Skipping backup creation for $filepath"
        [ "$timeout" -ne 0 ] && sleep 1
        return 0
    fi
    local backup_path="${filepath}.mentorbak"

    # Check if filepath contains "home/pi/.mentor" or "home/pi/.source4rpi"
    if [[ "$filepath" == *"home/pi/.mentor"* || "$filepath" == *"home/pi/.source4rpi"* ]]; then
        echo "Skipping backup creation for $filepath (excluded path)"
        [ "$timeout" -ne 0 ] && sleep 1
        return 0
    fi

    # If backup already exists, don't overwrite it
    if [ -f "$backup_path" ]; then
        echo "Backup already exists for $filepath, skipping backup creation"
        [ "$timeout" -ne 0 ] && sleep 1
        return 0
    fi

    # Create backup only if original file exists using is_file
    if is_file "$filepath"; then
        if [ "$dry" -ne 1 ]; then
            echo "backup: $filepath to $backup_path"
            if ! sudo -u pi cp "$filepath" "$backup_path"; then
                print_warning "Failed to create backup file $backup_path but continuing"
                # Not exiting with error, just warning
            fi
        else
            echo "dry: backup: $filepath to $backup_path"
        fi
        
        [ "$timeout" -ne 0 ] && sleep 1
    else
        echo "Original file $filepath does not exist, no backup needed"
    fi
    return 0
}

rsync_line_test() {
  local p1="$1"
  local p2="$2"

  # Skip if parameters are empty or contain certain patterns
  if [ -z "$p1" ] || [ -z "$p2" ]; then
    echo "Skipping empty rsync line parameters"
    return 1
  fi
  
  # Skip rsync status lines
  if [[ "$p1" == "sending" || "$p1" == "sent" || "$p1" == "total" || "$p1" == *"speedup"* ]]; then
    return 1
  fi

  # Normalize paths to ensure they start with "/"
  p1="/${p1#/}"
  p2="/${p2#/}"

  # Debug output for path processing
  if [ "$timeout" -ne 0 ]; then
    echo "Processing rsync paths:"
    echo "  Path 1: '$p1'"
    echo "  Path 2: '$p2'"
  fi

  # Skip directories (paths ending with "/")
  if [[ "${p1: -1}" == "/" ]]; then
    [ "$timeout" -ne 0 ] && echo "Skipping directory path: $p1"
    return 1
  fi

  # Skip paths with trailing slashes in the second part too
  if [[ "${p2: -1}" == "/" ]]; then
    [ "$timeout" -ne 0 ] && echo "Skipping path with trailing slash: $p2"
    return 1
  fi
  
  # Skip paths containing special rsync output patterns
  if [[ "$p1" == *"building file list"* || "$p2" == *"building file list"* ]]; then
    return 1
  fi
  
  # Skip paths with mentorbak extension
  if [[ "$p1" == *.mentorbak || "$p2" == *.mentorbak ]]; then
    [ "$timeout" -ne 0 ] && echo "Skipping backup file: $p1"
    return 1
  fi

  # If we get here, the path is valid for processing
  return 0
}

run_rsync() {
  echo "Running rsync for home_dir (copy4prepare)"

  # Define excluded paths
  local exclude_option
  exclude_option="--exclude=/root4rpi --exclude=/copy4prepare.sh --exclude=*.mentorbak"

  # Add mount directory to exclusions if needed
  if [[ "$mntdir" == "$target/"* ]]; then
      exclude_option="$exclude_option --exclude=/${mntdir#"$target"/}"
  fi
  
  # Additional exclusions for dry run
  local dry_exclude_option
  dry_exclude_option="$exclude_option --exclude=/.source4rpi --exclude=/.mentor"
  
  # Define rsync command base
  local rcmd
  rcmd="sudo -u pi rsync -avvc --relative"
  local cont
  cont="$from/$home_dir/./ $target"

  # Full rsync commands
  local rsync_cmd
  rsync_cmd="$rcmd $exclude_option $cont"
  local dry_rsync_cmd
  dry_rsync_cmd="$rcmd --dry-run $dry_exclude_option $cont"

  echo "Performing dry run to identify files for backup..."
  echo "DRY RSYNC: $from/$home_dir/ >> $target ($dry_exclude_option)"
  
  # Use a temporary file to store the dry run results
  local dry_run_file
  dry_run_file=$(mktemp)
  
  # Capture dry run output to file to avoid pipe issues
  if ! $dry_rsync_cmd > "$dry_run_file"; then
    echo "Warning: Dry run rsync failed, continuing anyway"
  fi
  
  # Process dry run results from file
  while read -r line; do
    local first_part
    local second_part
    first_part="${line%% *}"
    second_part="${line#* }"

    if ! rsync_line_test "$first_part" "$second_part"; then
      continue
    fi
    
    local fpath
    fpath="$target/$first_part"
    
    # Create backup before removal
    if [ "$dry" -ne 1 ]; then
      create_backup "$fpath"
      
      echo "Removing $fpath before copy"
      if [ -e "$fpath" ] && ! rm -rf "$fpath"; then
        echo "Warning: Failed to remove $fpath, attempting to continue"
      fi
    else
      echo "dry: Would remove $fpath"
    fi
  done < "$dry_run_file"
  
  # Remove temporary file
  rm -f "$dry_run_file"

  echo "Starting actual rsync operation..."
  echo "RSYNC: $from/$home_dir/ >> $target ($exclude_option)"
  
  # Perform the actual rsync operation
  if [ "$dry" -ne 1 ]; then
    local rsync_output_file
    rsync_output_file=$(mktemp)
    
    if ! $rsync_cmd > "$rsync_output_file"; then
      echo "Warning: Rsync operation completed with errors, checking results"
    fi
    
    # Process rsync results from file
    while read -r line; do
      local first_part
      local second_part
      first_part="${line%% *}"
      second_part="${line#* }"

      # Skip lines that don't match our pattern
      if ! rsync_line_test "$first_part" "$second_part"; then
        continue
      fi

      # Process successful transfers
      if [[ $first_part == "$second_part" ]] || [[ $second_part == *uptodate* ]]; then
        echo "Processing $target/$first_part"
        # Process file even if handle_file returns error
        handle_file "$target/$first_part" "$from/$home_dir/$first_part" || true
      fi
    done < "$rsync_output_file"
    
    # Remove temporary file
    rm -f "$rsync_output_file"
  else
    echo "Dry run mode: skipping actual rsync operation"
  fi
  
  echo "Rsync operation completed"
}

un_un() {
  if [ "$do_umount" -eq 1 ]; then
    echo "Unmounting $mntdir"
    if [ "$quick" -eq 0 ]; then
      echo "3, 2, 1... Ctrl+C to cancel."
      sleep 4
    fi
    
    # Set flag to indicate unmounting is in progress
    do_umount=0
    
    # Check if the directory is still mounted
    if mount | grep -q "$mntdir"; then
      echo "Unmounting $mntdir..."
      # Try to unmount with a retry mechanism
      local max_attempts=3
      local attempt=1
      local unmounted=0
      
      while [ $attempt -le $max_attempts ] && [ $unmounted -eq 0 ]; do
        if sudo umount "$mntdir"; then
          echo "Successfully unmounted $mntdir"
          unmounted=1
        else
          echo "Attempt $attempt to unmount $mntdir failed, waiting and retrying..."
          sleep 2
          attempt=$((attempt + 1))
        fi
      done
      
      if [ $unmounted -eq 0 ]; then
        print_warning "Failed to unmount $mntdir after $max_attempts attempts, continuing anyway"
      fi
    else
      echo "$mntdir is not mounted"
    fi
    
    # Remove mount directory if it exists
    if [ -d "$mntdir" ]; then
      echo "Removing mount directory $mntdir"
      if ! rm -rf "$mntdir"; then
        print_warning "Failed to remove directory $mntdir, continuing anyway"
      fi
    fi
  fi
}

mnt_mnt() {
  echo "Preparing mount point $mntdir"
  
  # Ensure mount directory exists with better error handling
  if [ ! -d "$mntdir" ]; then
    echo "Creating mount directory $mntdir"
    if ! sudo -u pi mkdir -p "$mntdir"; then
      print_error "Failed to create mount directory $mntdir"
    fi
  fi
  
  # Check if already mounted
  if is_mounted "$from" "$mntdir"; then
    echo "$from is already mounted at $mntdir"
    # Get actual mount point to ensure correct path
    local actual_mntdir
    actual_mntdir=$(mount | grep "$from" | awk '{print $3}')
    echo "Using actual mount point: $actual_mntdir"
    set_from "$actual_mntdir"
    return 0
  fi
  
  # Check if device is already mounted elsewhere
  local existing_mount
  existing_mount=$(mount | grep "$from" | awk '{print $3}' | head -n1)
  if [ -n "$existing_mount" ]; then
    echo "$from is already mounted at $existing_mount, using that mount point"
    set_from "$existing_mount"
    return 0
  fi
  
  # Mount the device
  echo "Mounting device $from at $mntdir"
  if ! sudo mount "$from" "$mntdir"; then
    # Try with more options if first attempt fails
    echo "First mount attempt failed, trying with additional options..."
    if ! sudo mount -o rw,noatime "$from" "$mntdir"; then
      print_error "Failed to mount $from at $mntdir after multiple attempts"
    fi
  fi
  
  echo "Successfully mounted $from at $mntdir"
  do_umount=1
  set_from "$mntdir"
}


mnt_init() {
  echo "Initializing mount system for source: $from"
  
  # Case 1: from is a block device
  if is_block_device "$from"; then
      echo "$from is a block device, proceeding with mount"
      mnt_mnt "$from"
      return 0
  fi
  
  # Case 2: from is an existing directory
  if is_directory "$from"; then
      echo "$from is a directory, using directly"
      set_from "$from"
      return 0
  fi
  
  # Case 3: from is a pattern for a block device
  if echo "$from" | grep -q '/dev/sd[a-z][0-9]'; then
      echo "Searching for block device matching pattern: $from"
      local gotit=0
      
      # First try exact match
      if [ -b "$from" ]; then
          echo "Found exact match for block device: $from"
          gotit=1
          mnt_mnt "$from"
          return 0
      fi
      
      # Try to find any matching block device
      echo "Searching for available block devices..."
      for dev in /dev/sd*[0-9]; do
          if is_block_device "$dev"; then
              echo "Found block device $dev"
              gotit=1
              from=$dev
              mnt_mnt "$from"
              return 0
          fi
      done
      
      # Additional search for USB devices
      if [ "$gotit" -eq 0 ]; then
          echo "Checking for USB block devices..."
          for dev in /dev/disk/by-id/usb-*-part*; do
              if is_block_device "$dev"; then
                  echo "Found USB block device $dev"
                  gotit=1
                  from=$dev
                  mnt_mnt "$from"
                  return 0
              fi
          done
      fi
      
      if [ "$gotit" -eq 0 ]; then
          print_error "Failed to find any suitable block device"
      fi
  else
      # Case 4: None of the above, try to guess what the user meant
      echo "Path '$from' is not a block device or directory"
      
      # Try to interpret as a partial path
      if [ -d "/media/pi/$from" ]; then
          echo "Found matching directory at /media/pi/$from"
          from="/media/pi/$from"
          set_from "$from"
          return 0
      fi
      
      # If all else fails
      print_error "Invalid path: $from - must be a block device or existing directory"
  fi
}

print_parsed_arguments() {
    echo "  stad: $from"
    echo "  mount: $mntdir"
    echo "  tu: $target"
    echo "  home: $home_dir"
    echo "  skrypt: $file"
    echo "  szybko: $quick"
    echo "  bez skryptu? $norun"
    echo "  bez kopiowania? $nosync"
    echo "  zadanie: $job"
    echo "  oczekiwanie na uzytkownika: $timeout"
    echo "  skrypt na miejscu: $run"
    echo "  tylko udajemy? $dry"
    echo "  przywracamy? $brestore"
    echo "  czyscimy? $bclear"
    echo "  nie robimy kopii? $nobackup"
}

# Function to create a copy4prepare.marker file similar to prepare4lab.marker
create_copy4prepare_marker() {
  local marker_dir="$target/.mentor"
  local marker_file="copy4prepare.marker"
  
  # Create parent directory if it doesn't exist
  mkdir -p "$marker_dir" || { 
    print_error "Failed to create directory for marker file"; 
  }
  
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local username
  username="$(whoami)"
  local hostname
  hostname="$(hostname)"
  
  # Write marker content
  {
    echo "# $marker_file"
    echo "WERSJA=$WERSJA"
    echo "# "
    echo "# $timestamp"
    echo "# ${username}@${hostname}"
    echo "# Source: $from"
    echo "# Target: $target"
    echo "# Home directory: $home_dir"
    echo "# Job: $job"
    echo "# "
    echo "# STATISTICS"
    echo "# Warnings: $warning_count"
    echo "# Errors: $error_count"
    echo "# "
    echo "# CONFIGURATION"
    echo "# quick=$quick"
    echo "# norun=$norun"
    echo "# nosync=$nosync"
    echo "# dry=$dry"
    echo "# nobackup=$nobackup"
    echo "# "
    echo "# ---"
  } > "$marker_dir/$marker_file" || {
    print_warning "Failed to write to marker file"; 
  }
  
  echo "Created marker file: $marker_dir/$marker_file"
  return 0
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
    print_parsed_arguments    
    echo "Will clean previous mentor files..."
    noquick
    
    if [ "$brestore" -eq 1 ]; then
        echo "Restoring configuration from backup files..."
        # Use a more targeted find command to avoid system-wide search
        sudo find "/home/pi" -name "*.mentorbak" -exec sh -c '
            original_file="${1%.mentorbak}"
            echo "Restoring $original_file from $1"
            if [ -f "$1" ]; then
                if sudo -u pi cp -f "$1" "$original_file"; then
                    echo "Successfully restored $original_file"
                    sudo rm -f "$1"
                else
                    echo "Warning: Failed to restore $original_file from $1, keeping backup file"
                fi
            else
                echo "Warning: Backup file $1 not found"
            fi
        ' sh {} \;
        echo "Restoration complete"
        exit 0
    fi
    
    if [ "$bclear" -eq 1 ]; then
        echo "Clearing backup files..."
        # Use a more targeted find command to avoid system-wide search
        restore_count=0
        fail_count=0
        sudo find "/home/pi" -name "*.mentorbak" -exec sh -c '
            echo "Removing $1"
            if sudo rm -f "$1"; then
                restore_count=$((restore_count + 1))
            else
                echo "Warning: Failed to clear backup file $1"
                fail_count=$((fail_count + 1))
            fi
        ' sh {} \;
        echo "Cleared $restore_count backup files, $fail_count failures"
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
    
    # Clean up previous files with better error handling
    for path in "$target/.mentor" "$target/.source4rpi" "$target/.config/Mentor" "$target/.prepare4lab.step"; do
        if [ -e "$path" ]; then
            echo "Removing $path"
            if ! rm -rf "$path"; then
                print_warning "Failed to remove $path, continuing anyway"
            fi
        fi
    done
    
    echo "0" | sudo -u pi tee "$target"/.prepare4lab.step > /dev/null || { 
        print_error "Failed to write to '$target'/.prepare4lab.step"
    }
    
    if ! cp -rf /etc/skel/.profile "$target/." ; then
        print_warning "Failed to copy profile template, continuing anyway"
    fi

    mnt_init
    noquick

    if [ "$nosync" -ne 1 ]; then
        run_rsync || { print_error "Failed to run rsync"; }
    fi

    un_un
    
    if [ "$norun" -ne 1 ]; then
      if [ $quick -eq 1 ]; then
          job="Q$job"
      fi
      
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
        
        # Create marker file with operation information
        if [ "$dry" -eq 0 ]; then
      create_copy4prepare_marker
        else
      echo "--dry mode enabled. Skipping marker file creation."
        fi
        
        echo "Operation complete with $error_count errors and $warning_count warnings"
  exit 0
}

parse() {
    local invalid_args=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --from)
               if [[ -z "$2" || "$2" == --* ]]; then
                   echo "Error: Missing or invalid value for --from"
                   invalid_args=1
                   shift
               else
                   from="${2%/}" # Remove trailing slash if present
                   echo "Option --from with value $from"
                   shift 2
               fi
               ;;
           --mnt)
               if [[ -z "$2" || "$2" == --* ]]; then
                   echo "Error: Missing or invalid value for --mnt"
                   invalid_args=1
                   shift
               else
                   mntdir="${2%/}" # Remove trailing slash if present
                   echo "Option --mnt with value $mntdir"
                   shift 2
               fi
               ;;
           --target)
               if [[ -z "$2" || "$2" == --* ]]; then
                   echo "Error: Missing or invalid value for --target"
                   invalid_args=1
                   shift
               else
                   target="${2%/}" # Remove trailing slash if present
                   echo "Option --target with value $target"
                   shift 2
               fi
               ;;
           --home_dir)
               if [[ -z "$2" || "$2" == --* ]]; then
                   echo "Error: Missing or invalid value for --home_dir"
                   invalid_args=1
                   shift
               else
                   home_dir="${2%/}" # Remove trailing slash if present
                   echo "Option --home_dir with value $home_dir"
                   shift 2
               fi
               ;;
            --file)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: Missing or invalid value for --file"
                    invalid_args=1
                    shift
                else
                    file="$2"
                    echo "Option --file with value $file"
                    shift 2
                fi
                ;;
            --quick)
                quick=1
                echo "Option --quick enabled"
                shift
                ;;
            --norun)
                norun=1
                echo "Option --norun enabled"
                shift
                ;;
            --nosync)
                nosync=1
                echo "Option --nosync enabled"
                shift
                ;;
            --brestore)
                brestore=1
                echo "Option --brestore enabled"
                shift
                ;;
            --bclear)
                bclear=1
                echo "Option --bclear enabled"
                shift
                ;;
            --nobackup)
                nobackup=1
                echo "Option --nobackup enabled"
                shift
                ;;
            --timeout)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: Missing or invalid value for --timeout"
                    invalid_args=1
                    shift
                else
                    # Validate timeout is a number
                    if [[ "$2" =~ ^[0-9]+$ ]]; then
                        timeout="$2"
                        echo "Option --timeout with value $timeout"
                    else
                        echo "Error: --timeout value must be a positive integer"
                        invalid_args=1
                    fi
                    shift 2
                fi
                ;;
            --run)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: Missing or invalid value for --run"
                    invalid_args=1
                    shift
                else
                    run="$2"
                    echo "Option --run with value $run"
                    shift 2
                fi
                ;;
            --dry)
                dry=1
                echo "Option --dry enabled (simulation mode)"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            --job)
                shift
                # Capture all remaining arguments as the job
                job="$*"
                echo "Raw job value: $job"
                
                # Map common job names to their internal representations
                if [ "$job" == "release" ]; then
                    job="urelease"
                    echo "Mapped 'release' to 'urelease'"
                elif [ "$job" == "devel" ]; then
                    job="udevel"
                    echo "Mapped 'devel' to 'udevel'"
                elif [ "$job" == "debug" ]; then
                    job="udebug"
                    echo "Mapped 'debug' to 'udebug'"
                else
                    echo ""
                    echo "Warning: Unknown job type: '$job'"
                    echo "Known job types are: release, devel, debug"
                    echo "Continuing with provided job value"
                    read -rp "Press [Enter] to continue, Ctrl+C to cancel..."
                fi
                echo "Final job value: $job"
                break
                ;;
            --)
                if [[ $# -gt 1 ]]; then
                    echo "Error: '--' must not be followed by any arguments"
                    show_help
                    invalid_args=1
                fi
                shift
                break
                ;;
            *)
                echo "Error: Unknown option: $1"
                invalid_args=1
                shift
                ;;
        esac
    done
    
    # If there were invalid arguments, show help and exit
    if [ $invalid_args -eq 1 ]; then
        echo "One or more arguments were invalid. Please check your command."
        show_help
        exit 1
    fi
    
    # Validate essential parameters
    if [ -z "$from" ]; then
        echo "Warning: No source specified, using default: $from"
    fi
    
    if [ -z "$mntdir" ]; then
        echo "Warning: No mount directory specified, using default: $mntdir"
    fi
    
    if [ -z "$target" ]; then
        echo "Warning: No target directory specified, using default: $target"
    fi
    
    # Check for mutually exclusive options
    if [ "$brestore" -eq 1 ] && [ "$bclear" -eq 1 ]; then
        echo "Error: --brestore and --bclear cannot be used together"
        exit 1
    fi
}

print_error() {
  local message="$1"
  error_count=$((error_count + 1))
  echo "Error: $message"
  # Log the error to a file for debugging
  echo "$(date): ERROR: $message" >> /tmp/copy4prepare_error.log
  exit 1
}

print_warning() {
  local message="$1"
  warning_count=$((warning_count + 1))
  echo "Warning: $message"
  # Log the warning to a file for debugging
  echo "$(date): WARNING: $message" >> /tmp/copy4prepare_warning.log
}

print_debug() {
  if [ "$timeout" -ne 0 ]; then
    local message="$1"
    echo "Debug: $message"
  fi
}

is_directory() {
    if [ -z "$1" ]; then
        print_warning "Empty path provided to is_directory"
        return 1
    fi
    [ -d "$1" ]
}

# is_file is used for checking file existence throughout the script
is_file() {
    if [ -z "$1" ]; then
        print_warning "Empty path provided to is_file"
        return 1
    fi
    [ -f "$1" ]
}

is_block_device() {
    if [ -z "$1" ]; then
        print_warning "Empty path provided to is_block_device"
        return 1
    fi
    [ -b "$1" ]
}

is_mounted() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        print_warning "Empty parameters provided to is_mounted"
        return 1
    fi
    
    # Check with grep for exact match
    if mount | grep -q "$1 on $2"; then
        return 0
    fi
    
    # Check if the device is mounted anywhere
    if [ -b "$1" ] && mount | grep -q "^$1 "; then
        print_debug "$1 is mounted somewhere else"
        return 0
    fi
    
    return 1
}

set_from() {
    if [ -z "$1" ]; then
        print_warning "Empty path provided to set_from"
        return 1
    fi
    
    from="$1"
    echo "Source location set to: $from"
    
    # Validate the path exists
    if ! [ -e "$from" ]; then
        print_warning "Source path does not exist: $from"
    fi
    
    return 0
}

# We've removed the unused functions for better code maintenance
# is_file and is_directory are kept as they're used in the script

main "$@"
