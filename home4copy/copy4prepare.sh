#!/bin/bash
# -*- coding: utf-8 -*-

# Script version
WERSJA=4.2.2

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

do_umount=0                          # Flag to track if we mounted a device
# Set default values for all parameters
from="/dev/sd[a-z][1-9]"                       # Source location (block device or directory)
mntdir=/mnt                          # Mount point for block devices
target=/home/pi                      # Target directory for file operations
home_dir=home4copy                   # Directory name on source containing files
file=prepare4lab.sh                  # Script filename to run after copying
quick=0                              # Flag to skip confirmation delays
norun=0                              # Flag to skip running scripts
nosync=0                             # Flag to skip rsync operations
job="release"                        # Default job type for the script
timeout=0                            # Wait time before starting operations
run="/home/pi/.mentor/prepare4lab.sh" # Path to the script to run
dry=0                                # Flag for simulation mode (no changes)
brestore=0                           # Flag to restore from backups and exit
bclear=0                             # Flag to clear backup files and exit
nobackup=0                           # Flag to skip creating backup files

# Initialize error and warning counters
error_count=0
warning_count=0
    
# Initialize user and debug level variables
USER_LEVEL=1
DEBUG_LEVEL=0

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════════════════════
║ copy4prepare.sh v$WERSJA - Mentor Lab Preparation Utility (Enhanced Path Detection)
╠══════════════════════════════════════════════════════════════════════════════
║ Usage: sudo $0 [options]
║
║ Main Options:
║   --from <path>          Block device or directory (default: ${from})
║   --mnt <path>           Mount point for the device (default: ${mntdir})
║   --target <path>        Target directory (default: ${target})
║   --timeout <seconds>    Wait time before starting the process (default: ${timeout} or 0 if --quick)
║
║ Process Control:
║   --quick                Skip confirmation delays
║
║ Script Execution:
║   --debug                Set debug verbosity level
║   --job <args>           Arguments for the script (default: ${job})
║
║ NOTE: --job must always be the LAST ARGUMENT!
║
║ Help:
║   --help                 Show this help message
║
║ Examples:
║   sudo $0 --from /media/pi/usb_label --quick
║   sudo $0 --from /dev/sd[a-z]1 --target ~/mnt --job devel
╚══════════════════════════════════════════════════════════════════════════════
EOF
}

# Usage: command || report_error errno "message"
echo_error() {
  local status=$?        # Capture exit status of previous command
  local errno="$1"       # Error number/code
  local message="$2"     # Error message text
  local cmd_status="${3:-$status}"  # Use provided status or captured status
  
  # Ensure errno is a valid number
  if ! [[ "$errno" =~ ^[0-9]+$ ]]; then
    echo_info "Invalid error number: $errno. Using 255 instead."
    errno=255
  fi
  
  # Include command status if available
  if [ -n "$cmd_status" ]; then
    echo_info "[err$errno] $message [status=$cmd_status]"
  else
    echo_info "[err$errno] $message"
  fi
  
  # Interactive mode for user
  if [ "$USER_LEVEL" -eq 1 ] && [ $quick -eq 0 ]; then
    echo_info "[Enter] to continue, Ctrl+C to cancel..."
    read -r
  fi
  
  # Return the errno as exit code (ensuring it's in valid range 0-255)
  exit $(( errno % 256 ))
}

echo_info() {
  local msg="$1"
  local cmd_status="$2"

  # If command status is provided, include it in the output
  if [ -n "$cmd_status" ]; then
    msg="$msg [status=$cmd_status]"
  fi

  # Interactive mode with debug
  if [ "$DEBUG_LEVEL" -eq 1 ] && [ "$USER_LEVEL" -eq 1 ] && [ $quick -eq 0 ]; then
    echo "$msg //Enter..."
    read -r
  else
    echo "$msg"
  fi

  # Sleep in debug mode for better readability
  if [ "$DEBUG_LEVEL" -eq 1 ] && [ $quick -eq 0 ]; then
    sleep 1
  fi
}

echo_info "copy4prepare ver: $WERSJA"
verify_prepare_script() {
  local wersja_in_script
  
  echo_info "Verifying prepare script integrity before running: $run"
  
  # Check if script exists
  if ! is_file "$run"; then
    echo_error 20 "Prepare script not found at $run"
  fi
  
  # Check if script is readable
  if [ ! -r "$run" ]; then
    echo_error 60 "Prepare script exists but is not readable: $run"
  fi
  
  # Validate bash syntax
  if ! bash -n "$run"; then
    echo_error 200 "Prepare script contains syntax errors: $run"
  fi
  
  # Extract version from script
  wersja_in_script=$(grep -m 1 "^WERSJA=" "$run" | cut -d'=' -f2)
  
  # Check if version was extracted successfully
  if [ -z "$wersja_in_script" ]; then
    echo_info "Warning: Could not extract version from prepare script"
    echo_wait "Script version not found, continue anyway?"
  else
    # Compare versions
    if [ "$wersja_in_script" != "$WERSJA" ]; then
      echo_info "WARNING: Version mismatch detected!"
      echo_info "  copy4prepare.sh version: $WERSJA"
      echo_info "  $file version: $wersja_in_script"
      echo_stop "Version mismatch" "Running prepare script with different version may cause issues"
    else
      echo_info "Version check passed: Both scripts at version $WERSJA"
    fi
  fi
  
  # Check execute permission
  if [ ! -x "$run" ]; then
    echo_info "Adding execute permission to prepare script"
    chmod +x "$run" || echo_error 60 "Failed to add execute permission to prepare script"
  fi
  
  echo_info "Script verification completed"
  return 0
}

echo_stop() {
  local operation="$1"
  local details="$2"

  # Print operation with details if provided
  if [ -n "$details" ]; then
    echo_info "CRITICAL OPERATION: $operation [$details]"
  else
    echo_info "CRITICAL OPERATION: $operation"
  fi

  # Always flush disk buffers before critical operations
  sync

  # Interactive mode for user
  if [ "$USER_LEVEL" -eq 1 ] && [ $quick -eq 0 ]; then
    echo_info "[Enter] to continue, Ctrl+C to cancel..."
    read -r
  elif [ "$DEBUG_LEVEL" -eq 1 ] && [ $quick -eq 0 ]; then
    # In debug mode without user interaction, still pause briefly
    echo_info "Ctrl+C to cancel. 3, 2, 1..."
    sleep 5
  fi
}

echo_wait() {
  local message="$1"
  echo_info "WAIT: $message"
  if [ "$USER_LEVEL" -eq 1 ] && [ "$quick" -eq 0 ]; then
    echo_info "Press [Enter] to continue, or wait 5 seconds..."
    read -t 5 -r || echo_info "Timeout waiting for user input, continuing"
  elif [ "$DEBUG_LEVEL" -eq 1 ]; then
    sleep 2
  fi
  return 0
}

handle_file() {
    local _file=$1
    local _sourcefile=$2

    # Trim trailing spaces from file paths
    _file="${_file%"${_file##*[![:space:]]}"}"
    _sourcefile="${_sourcefile%"${_sourcefile##*[![:space:]]}"}"

    echo_info "Handling file $_file"

    # Check if source file exists using is_file
    if ! is_file "$_sourcefile"; then
        print_warning "$_sourcefile does not exist. Please check the paths."
        return 1
    fi

    # Check if the files are identical using cmp (faster binary comparison)
    if ! cmp -s "$_file" "$_sourcefile"; then
        echo_info "Files are different after rsync: $_file and $_sourcefile"
        # If verbose debugging is needed, uncomment the diff line
        # diff -u "$_file" "$_sourcefile" || true
        # Continue processing even if files are different, as rsync might have modified them
    fi

    # Convert to Unix format (safely)
    echo_info "Converting $_file to Unix format"
    if ! dos2unix -f -k "$_file" 2>/dev/null; then
        echo_info "Warning: dos2unix conversion issue with $_file, continuing"
    fi

    # Handle special files
    if [[ "$_file" == *.sh ]]; then
        echo_info "Making $_file executable"
        if ! chmod +x "$_file"; then
            echo_info "Warning: Failed to make $_file executable, continuing"
        fi

        echo_info "Validating bash script $_file"
        if ! bash -n "$_file"; then
            echo_error 1 "$_file contains syntax errors"
        fi
    fi
    
    return 0
}

create_backup() {
    local filepath="$1"
    if [ "$nobackup" -eq 1 ]; then
        echo_info "--nobackup enabled. Skipping backup creation for $filepath"
        return 0
    fi
    local backup_path="${filepath}.mentorbak"

    # Check if filepath contains "home/pi/.mentor" or "home/pi/.source4rpi"
    if [[ "$filepath" == *"home/pi/.mentor"* || "$filepath" == *"home/pi/.source4rpi"* ]]; then
        echo_info "Skipping backup creation for $filepath (excluded path)"
        return 0
    fi

    # If backup already exists, don't overwrite it
    if [ -f "$backup_path" ]; then
        echo_info "Backup already exists for $filepath, skipping backup creation"
        return 0
    fi

    # Create backup only if original file exists using is_file
    if is_file "$filepath"; then
        if [ "$dry" -ne 1 ]; then
            echo_info "backup: $filepath to $backup_path"
            if ! sudo -u pi cp "$filepath" "$backup_path"; then
                print_warning "Failed to create backup file $backup_path but continuing"
                # Not exiting with error, just warning
            fi
        else
            echo_info "dry: backup: $filepath to $backup_path"
        fi
    else
        echo_info "Original file $filepath does not exist, no backup needed"
    fi
    return 0
}

rsync_line_test() {
  local p1="$1"
  local p2="$2"

  # Skip if parameters are empty or contain certain patterns
  if [ -z "$p1" ] || [ -z "$p2" ]; then
    echo_info "Skipping empty rsync line parameters"
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
  echo_info "Processing rsync paths:"
  echo_info "  Path 1: '$p1'"
  echo_info "  Path 2: '$p2'"

  # Skip directories (paths ending with "/")
  if [[ "${p1: -1}" == "/" ]]; then
    echo_info "Skipping directory path: $p1"
    return 1
  fi

  # Skip paths with trailing slashes in the second part too
  if [[ "${p2: -1}" == "/" ]]; then
    echo_info "Skipping path with trailing slash: $p2"
    return 1
  fi
  
  # Skip paths containing special rsync output patterns
  if [[ "$p1" == *"building file list"* || "$p2" == *"building file list"* ]]; then
    return 1
  fi
  
  # Skip paths with mentorbak extension
  if [[ "$p1" == *.mentorbak || "$p2" == *.mentorbak ]]; then
    echo_info "Skipping backup file: $p1"
    return 1
  fi

  # If we get here, the path is valid for processing
  return 0
}

run_rsync() {
  echo_info "Running rsync for home_dir (copy4prepare)"

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

  echo_info "Performing dry run to identify files for backup..."
  echo_info "DRY RSYNC: $from/$home_dir/ >> $target ($dry_exclude_option)"
  
  # Use a temporary file to store the dry run results
  local dry_run_file
  dry_run_file=$(mktemp)
  
  # Capture dry run output to file to avoid pipe issues
  if ! $dry_rsync_cmd > "$dry_run_file"; then
    echo_info "Warning: Dry run rsync failed, continuing anyway"
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
      
      echo_info "Removing $fpath before copy"
      if [ -e "$fpath" ] && ! rm -rf "$fpath"; then
        echo_info "Warning: Failed to remove $fpath, attempting to continue"
      fi
    else
      echo_info "dry: Would remove $fpath"
    fi
  done < "$dry_run_file"
  
  # Remove temporary file
  rm -f "$dry_run_file"

  echo_info "Starting actual rsync operation..."
  echo_info "RSYNC: $from/$home_dir/ >> $target ($exclude_option)"
  
  # Perform the actual rsync operation
  if [ "$dry" -ne 1 ]; then
    local rsync_output_file
    rsync_output_file=$(mktemp)
    
    if ! $rsync_cmd > "$rsync_output_file"; then
      echo_info "Warning: Rsync operation completed with errors, checking results"
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
        echo_info "Processing $target/$first_part"
        # Process file even if handle_file returns error
        handle_file "$target/$first_part" "$from/$home_dir/$first_part" || true
      fi
    done < "$rsync_output_file"
    
    # Remove temporary file
    rm -f "$rsync_output_file"
  else
    echo_info "Dry run mode: skipping actual rsync operation"
  fi
  
  echo_info "Rsync operation completed"
}

un_un() {
  if [ "$do_umount" -eq 1 ]; then
    echo_wait "Unmounting $mntdir"
    
    # Set flag to indicate unmounting is in progress
    do_umount=0
    
    # Check if the directory is still mounted
    if mount | grep -q "$mntdir"; then
      echo_info "Unmounting $mntdir..."
      # Try to unmount with a retry mechanism
      local max_attempts=3
      local attempt=1
      local unmounted=0
      
      while [ $attempt -le $max_attempts ] && [ $unmounted -eq 0 ]; do
        if sudo umount "$mntdir"; then
          echo_info "Successfully unmounted $mntdir"
          unmounted=1
        else
          echo_wait "Attempt $attempt to unmount $mntdir failed, retrying..."
          attempt=$((attempt + 1))
        fi
      done
      
      if [ $unmounted -eq 0 ]; then
        print_warning "Failed to unmount $mntdir after $max_attempts attempts, continuing anyway"
      fi
    else
      echo_info "$mntdir is not mounted"
    fi
    
    # Remove mount directory if it exists
    if [ -d "$mntdir" ]; then
      echo_info "Removing mount directory $mntdir"
      if ! rm -rf "$mntdir"; then
        print_warning "Failed to remove directory $mntdir, continuing anyway"
      fi
    fi
  fi
}

mnt_mnt() {
  echo_info "Preparing mount point $mntdir"
  
  # Ensure mount directory exists with better error handling
  if [ ! -d "$mntdir" ]; then
    echo_info "Creating mount directory $mntdir"
    if ! sudo -u pi mkdir -p "$mntdir"; then
      print_error "Failed to create mount directory $mntdir"
    fi
  fi
  
  # Check if already mounted
  if is_mounted "$from" "$mntdir"; then
    echo_info "$from is already mounted at $mntdir"
    # Get actual mount point to ensure correct path
    local actual_mntdir
    actual_mntdir=$(mount | grep "$from" | awk '{print $3}')
    echo_info "Using actual mount point: $actual_mntdir"
    set_from "$actual_mntdir"
    return 0
  fi
  
  # Check if device is already mounted elsewhere
  local existing_mount
  existing_mount=$(mount | grep "$from" | awk '{print $3}' | head -n1)
  if [ -n "$existing_mount" ]; then
    echo_info "$from is already mounted at $existing_mount, using that mount point"
    set_from "$existing_mount"
    return 0
  fi
  
  # Mount the device
  echo_info "Mounting device $from at $mntdir"
  if ! sudo mount "$from" "$mntdir"; then
    # Try with more options if first attempt fails
    echo_info "First mount attempt failed, trying with additional options..."
    if ! sudo mount -o rw,noatime "$from" "$mntdir"; then
      print_error "Failed to mount $from at $mntdir after multiple attempts"
    fi
  fi
  
  echo_info "Successfully mounted $from at $mntdir"
  do_umount=1
  set_from "$mntdir"
}

mnt_init() {
  echo_info "Initializing mount system for source: $from"
  
  # Diagnostics before starting
  echo_info "Current mounts:"
  mount | grep -E '(^/dev/sd|^/media/pi)' || echo_info "No relevant mounts found"

  echo_info "Available block devices:"
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL 2>/dev/null || echo_info "lsblk failed or no devices found"

  # Case 1: from is a block device
  if is_block_device "$from"; then
      echo_info "$from is a block device, proceeding with mount"
      mnt_mnt "$from"
      return 0
  fi

  # Case 2: from is an existing directory
  if is_directory "$from"; then
      echo_info "$from is a directory, using directly"
      set_from "$from"
      return 0
  fi

  # Case 3: from potentially contains a pattern with ranges
  if echo "$from" | grep -q '\[[a-z]-[a-z]\]' || echo "$from" | grep -q '\[[0-9]-[0-9]\]'; then
      echo_info "Detected range pattern in: $from"
      local gotit=0
      
      # Use bash's built-in pattern matching
      shopt -s nullglob  # Ensure non-matching globs expand to nothing
      
      # Try to find all matching devices
      local matching_devices=("$from")
      
      # Reset globbing behavior
      shopt -u nullglob
      
      echo_info "Found ${#matching_devices[@]} potential matches for pattern $from"
      
      # Try each potentially matching device
      for dev in "${matching_devices[@]}"; do
          echo_info "Checking: $dev"
          if [ -b "$dev" ]; then
              echo_info "Found matching block device: $dev"
              gotit=1
              from=$dev
              mnt_mnt "$from"
              return 0
          fi
      done
      
      # If no matches were found, fail
      if [ "$gotit" -eq 0 ]; then
          print_error 1 "Failed to find any suitable block device matching pattern: $from"
          return 1
      fi
  else
      # Case 4: None of the above, try to guess what the user meant
      echo_info "Path '$from' is not recognized as a block device or directory"

      # Extended diagnostics
      echo_info "Detailed path analysis for '$from':"
      if [ -d "$from" ]; then
          echo_info "- Directory test: YES"
      else
          echo_info "- Directory test: NO"
      fi
      if [ -b "$from" ]; then
          echo_info "- Block device test: YES"
      else
          echo_info "- Block device test: NO"
      fi
      if [ -e "$from" ]; then
          echo_info "- File exists test: YES"
      else
          echo_info "- File exists test: NO"
      fi

      echo_info "- ls -la output: $(ls -la "$from" 2>&1 || echo_info "Cannot access")"
      echo_info "- mountpoint check: $(mountpoint "$from" 2>&1 || echo_info "Not a mountpoint")"

      # Check if the path is in /proc/mounts
      if grep -q " $from " /proc/mounts 2>/dev/null; then
          echo_info "Found '$from' in /proc/mounts:"
          grep " $from " /proc/mounts
      else
          echo_info "Path '$from' not found in /proc/mounts"
      fi

      # Try to interpret as a partial path in /media/pi/
      echo_info "Checking /media/pi/ for matching paths..."
      local found=0

      for media_path in /media/pi/*; do
          if [ -d "$media_path" ]; then
              echo_info "Found directory: $media_path"

              # Check if it's a mountpoint
              if mountpoint -q "$media_path" 2>/dev/null; then
                  echo_info "$media_path is a mountpoint"

                  # Check if the basename matches or contains our from value
                  media_basename=$(basename "$media_path")
                  if [ "$media_basename" = "$from" ] || [[ "$media_basename" == *"$from"* ]]; then
                      echo_info "Found matching directory at $media_path"
                      from="$media_path"
                      set_from "$from"
                      found=1
                      return 0
                  fi
              fi
          fi
      done

      if [ "$found" -eq 0 ] && [ -d "/media/pi/$from" ]; then
          echo_info "Found matching directory at /media/pi/$from"
          from="/media/pi/$from"
          set_from "$from"
          return 0
      fi

      # Last resort: check if any path in /media/pi contains files we need
      if [ "$found" -eq 0 ]; then
          echo_info "Checking if any mountpoint contains required files..."
          for media_path in /media/pi/*; do
              if [ -d "$media_path" ] && [ -d "$media_path/$home_dir" ]; then
                  echo_info "Found directory with $home_dir at $media_path"
                  from="$media_path"
                  set_from "$from"
                  found=1
                  return 0
              fi
          done
      fi

      # If all else fails
      if [ "$found" -eq 0 ]; then
          print_error "Invalid path: $from - must be a block device or existing directory"
      fi
  fi
}

print_parsed_arguments() {
    echo_info "  stad: $from"
    echo_info "  mount: $mntdir"
    echo_info "  tu: $target"
    echo_info "  home: $home_dir"
    echo_info "  skrypt: $file"
    echo_info "  szybko: $quick"
    echo_info "  bez skryptu? $norun"
    echo_info "  bez kopiowania? $nosync"
    echo_info "  zadanie: $job"
    echo_info "  oczekiwanie na uzytkownika: $timeout"
    echo_info "  skrypt na miejscu: $run"
    echo_info "  tylko udajemy? $dry"
    echo_info "  przywracamy? $brestore"
    echo_info "  czyscimy? $bclear"
    echo_info "  nie robimy kopii? $nobackup"
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
    echo_info "# $marker_file"
    echo_info "WERSJA=$WERSJA"
    echo_info "# "
    echo_info "# $timestamp"
    echo_info "# ${username}@${hostname}"
    echo_info "# Source: $from"
    echo_info "# Target: $target"
    echo_info "# Home directory: $home_dir"
    echo_info "# Job: $job"
    echo_info "# "
    echo_info "# STATISTICS"
    echo_info "# Warnings: $warning_count"
    echo_info "# Errors: $error_count"
    echo_info "# "
    echo_info "# CONFIGURATION"
    echo_info "# quick=$quick"
    echo_info "# norun=$norun"
    echo_info "# nosync=$nosync"
    echo_info "# dry=$dry"
    echo_info "# nobackup=$nobackup"
    echo_info "# user_level=$USER_LEVEL"
    echo_info "# debug_level=$DEBUG_LEVEL"
    echo_info "# "
    echo_info "# ---"
  } > "$marker_dir/$marker_file" || {
    print_warning "Failed to write to marker file"; 
  }
  
  echo_info "Created marker file: $marker_dir/$marker_file"
  return 0
}

main() {
    local status=0
    echo_info "Starting script with arguments: $*"

    if [ "$(id -u)" -ne 0 ]; then
      echo_info "Requires sudo!"
      show_help
      echo_info "Requires sudo!"
      return 1
    fi
    
    parse "$@"
    print_parsed_arguments    
    echo_info "Will clean previous mentor files..."
    
    if [ "$brestore" -eq 1 ]; then
        echo_info "Restoring configuration from backup files..."
        # Use a more targeted find command to avoid system-wide search
        sudo find "/home/pi" -name "*.mentorbak" -exec sh -c '
            original_file="${1%.mentorbak}"
            echo_info "Restoring $original_file from $1"
            if [ -f "$1" ]; then
                if sudo -u pi cp -f "$1" "$original_file"; then
                    echo_info "Successfully restored $original_file"
                    sudo rm -f "$1"
                else
                    echo_info "Warning: Failed to restore $original_file from $1, keeping backup file"
                fi
            else
                echo_info "Warning: Backup file $1 not found"
            fi
        ' sh {} \;
        echo_info "Restoration complete"
        return 0
    fi
    
    if [ "$bclear" -eq 1 ]; then
        echo_info "Clearing backup files..."
        # Use a more targeted find command to avoid system-wide search
        restore_count=0
        fail_count=0
        sudo find "/home/pi" -name "*.mentorbak" -exec sh -c '
            echo_info "Removing $1"
            if sudo rm -f "$1"; then
                restore_count=$((restore_count + 1))
            else
                echo_info "Warning: Failed to clear backup file $1"
                fail_count=$((fail_count + 1))
            fi
        ' sh {} \;
        echo_info "Cleared $restore_count backup files, $fail_count failures"
        return 0
    fi

    echo_stop "Starting after $timeout seconds from pressing [Enter]. During this time, disconnect the keyboard and connect the USB drive with $home_dir."
    echo_info "Now connect the USB drive containing $home_dir."
    if [ "$timeout" -ne 0 ]; then
      sleep "$timeout"
    fi
    echo_wait "It will be safe to disconnect the USB drive after the script asks you to press [Enter] again."
    
    # Clean up previous files with better error handling
    for path in "$target/.mentor" "$target/.source4rpi" "$target/.config/Mentor" "$target/.prepare4lab.step"; do
        if [ -e "$path" ]; then
            echo_info "Removing $path"
            if ! rm -rf "$path"; then
                print_warning "Failed to remove $path, continuing anyway"
            fi
        fi
    done
    
    echo_info "0" | sudo -u pi tee "$target"/.prepare4lab.step > /dev/null || { 
        print_error "Failed to write to '$target'/.prepare4lab.step"
    }
    
    if ! cp -rf /etc/skel/.profile "$target/." ; then
        print_warning "Failed to copy profile template, continuing anyway"
    fi

    mnt_init

    if [ "$nosync" -ne 1 ]; then
        run_rsync || { print_error "Failed to run rsync"; }
    fi

    un_un
    
    if [ "$norun" -ne 1 ]; then      
      echo_info "Will run $run with job \"$job\" (user_level=$USER_LEVEL, debug_level=$DEBUG_LEVEL)"
      log_file="/home/pi/copy4prepare.log"
      echo_wait "Log file: $log_file"

      if [ "$dry" -eq 0 ]; then
        verify_prepare_script || echo_error 200 "Prepare script verification failed"
        eval "$run" "$job" 2>&1 | sudo -u pi tee "$log_file"
    else
        echo_info "--dry mode enabled. Skipping script execution."
    fi
  fi
        
  # Create marker file with operation information
  if [ "$dry" -eq 0 ]; then
    create_copy4prepare_marker
  else
    echo_info "--dry mode enabled. Skipping marker file creation."
  fi
  
  echo_info "Operation complete with $error_count errors and $warning_count warnings"
  return $status
}

parse() {
    local invalid_args=0
    local user_timeout=0

    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                DEBUG_LEVEL=1
                shift
                ;;
            --from)
               if [[ -z "$2" || "$2" == --* ]]; then
                   echo_info "Error: Missing or invalid value for --from"
                   invalid_args=1
                   shift
               else
                   from="${2%/}" # Remove trailing slash if present
                   echo_info "Option --from with value $from"
                   shift 2
               fi
               ;;
           --mnt)
               if [[ -z "$2" || "$2" == --* ]]; then
                   echo_info "Error: Missing or invalid value for --mnt"
                   invalid_args=1
                   shift
               else
                   mntdir="${2%/}" # Remove trailing slash if present
                   echo_info "Option --mnt with value $mntdir"
                   shift 2
               fi
               ;;
           --target)
               if [[ -z "$2" || "$2" == --* ]]; then
                   echo_info "Error: Missing or invalid value for --target"
                   invalid_args=1
                   shift
               else
                   target="${2%/}" # Remove trailing slash if present
                   echo_info "Option --target with value $target"
                   shift 2
               fi
               ;;
           --home_dir)
               if [[ -z "$2" || "$2" == --* ]]; then
                   echo_info "Error: Missing or invalid value for --home_dir"
                   invalid_args=1
                   shift
               else
                   home_dir="${2%/}" # Remove trailing slash if present
                   echo_info "Option --home_dir with value $home_dir"
                   shift 2
               fi
               ;;
            --file)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo_info "Error: Missing or invalid value for --file"
                    invalid_args=1
                    shift
                else
                    file="$2"
                    echo_info "Option --file with value $file"
                    shift 2
                fi
                ;;
            --quick)
                quick=1
                echo_info "Option --quick enabled"
                shift
                ;;
            --norun)
                norun=1
                echo_info "Option --norun enabled"
                shift
                ;;
            --nosync)
                nosync=1
                echo_info "Option --nosync enabled"
                shift
                ;;
            --brestore)
                brestore=1
                echo_info "Option --brestore enabled"
                shift
                ;;
            --bclear)
                bclear=1
                echo_info "Option --bclear enabled"
                shift
                ;;
            --nobackup)
                nobackup=1
                echo_info "Option --nobackup enabled"
                shift
                ;;
            --timeout)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo_info "Error: Missing or invalid value for --timeout"
                    invalid_args=1
                    shift
                else
                    # Validate timeout is a number
                    if [[ "$2" =~ ^[0-9]+$ ]]; then
                        timeout="$2"
                        echo_info "Option --timeout with value $timeout"
                        user_timeout=1
                    else
                        echo_info "Error: --timeout value must be a positive integer"
                        invalid_args=1
                    fi
                    shift 2
                fi
                ;;
            --run)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo_info "Error: Missing or invalid value for --run"
                    invalid_args=1
                    shift
                else
                    run="$2"
                    echo_info "Option --run with value $run"
                    shift 2
                fi
                ;;
            --dry)
                dry=1
                echo_info "Option --dry enabled (simulation mode)"
                shift
                ;;
            --help)
                show_help
                return 0
                ;;
            --job)
                shift
                # Capture all remaining arguments as the job
                job="$*"
                echo_info "Raw job value: $job"
                
                # Define known job types
                declare -a known_job_types=("release" "devel" "test")

                # Extract the base job type (first word)
                base_job=$(echo_info "$job" | awk '{print $1}')
                rest_args=$(echo_info "$job" | cut -d' ' -f2-)
                
                if [ "$base_job" == "test" ]; then
                  USER_LEVEL=0
                  job="devel"
                fi

                # Check if base_job is a known type
                is_known=0
                for known_type in "${known_job_types[@]}"; do
                    if [ "$base_job" == "$known_type" ]; then
                        is_known=1
                        break
                    fi
                done

                if [ $is_known -eq 1 ]; then
                    if [ $USER_LEVEL -eq 1 ] && ! echo " $rest_args " | grep -q " --user "; then
                        rest_args="$rest_args --user"
                    fi
                    if [ $quick -eq 1 ] && ! echo " $job " | grep -q " --quick "; then
                        rest_args="$rest_args --quick"
                    fi
                    if [ $DEBUG_LEVEL -eq 1 ] && ! echo " $rest_args " | grep -q " --debug "; then
                        rest_args="$rest_args --debug"
                    fi

                    # Combine job and arguments
                    job="$base_job $rest_args"
                    echo_info "Prepared job command: $job"
                else
                    echo_info "Unknown job type: '$base_job'"
                    echo_info "Known job types are: ${known_job_types[*]}"
                    echo_stop "Continuing with provided job value: $job"
                fi

                echo_info "Final job value: $job"
                break
                ;;
            --)
                if [[ $# -gt 1 ]]; then
                    echo_info "Error: '--' must not be followed by any arguments"
                    show_help
                    invalid_args=1
                fi
                shift
                break
                ;;
            *)
                echo_info "Error: Unknown option: $1"
                invalid_args=1
                shift
                ;;
        esac
    done
    
    if [ $quick -eq 1 ] && [ $user_timeout -ne 1 ]; then
      timeout=0
    fi
      
    
    # If there were invalid arguments, show help and exit
    if [ $invalid_args -eq 1 ]; then
        echo_info "One or more arguments were invalid. Please check your command."
        show_help
        return 1
    fi
    
    # Validate essential parameters
    if [ -z "$from" ]; then
        echo_info "Warning: No source specified, using default: $from"
    fi
    
    if [ -z "$mntdir" ]; then
        echo_info "Warning: No mount directory specified, using default: $mntdir"
    fi
    
    if [ -z "$target" ]; then
        echo_info "Warning: No target directory specified, using default: $target"
    fi
    
    # Check for mutually exclusive options
    if [ "$brestore" -eq 1 ] && [ "$bclear" -eq 1 ]; then
        echo_error 1 "--brestore and --bclear cannot be used together"
    fi
}

is_directory() {
    local path="$1"

    if [ -z "$path" ]; then
        echo_info "Empty path provided to is_directory"
        return 1
    fi

    # Standard directory test
    if [ -d "$path" ]; then
        echo_info "$path is a standard directory (-d test succeeded)"
        return 0
    fi

    # Check if it's a mountpoint
    if mountpoint -q "$path" 2>/dev/null; then
        echo_info "$path is a mountpoint (mountpoint command succeeded)"
        return 0
    fi

    # Check if it's in /proc/mounts
    if grep -q " $path " /proc/mounts 2>/dev/null; then
        echo_info "$path found in /proc/mounts"
        return 0
    fi

    # Try to access the directory
    if cd "$path" >/dev/null 2>&1; then
        if ! cd - >/dev/null 2>&1; then
            print_error "Failed to return to previous directory"
        fi
        echo_info "$path is accessible via cd"
        return 0
    fi

    # Check if it's an automounted path with possibly strange characters
    if [[ "$path" == /media/pi/* ]]; then
        # Check all entries in /media/pi/ to see if any match after normalization
        for dir in /media/pi/*; do
            if [ -d "$dir" ]; then
                # Compare after removing problematic characters
                normalized_dir=$(echo_info "$dir" | tr -d '[:cntrl:]')
                normalized_path=$(echo_info "$path" | tr -d '[:cntrl:]')
                if [ "$normalized_dir" = "$normalized_path" ]; then
                    echo_info "$path matches normalized path $dir"
                    return 0
                fi
            fi
        done
    fi

    echo_info "$path is not a directory (all tests failed)"
    return 1
}

# is_file is used for checking file existence throughout the script
is_file() {
    local path="$1"

    if [ -z "$path" ]; then
        print_warning "Empty path provided to is_file"
        return 1
    fi

    # Standard file test
    if [ -f "$path" ]; then
        echo_info "$path is a standard file (-f test succeeded)"
        return 0
    fi

    # Check if it's a symlink to a file
    if [ -L "$path" ] && [ -f "$(readlink -f "$path")" ]; then
        echo_info "$path is a symlink to a file"
        return 0
    fi

    # Try to access the file with cat (zero bytes)
    if cat "$path" >/dev/null 2>&1; then
        echo_info "$path is accessible via cat"
        return 0
    fi

    echo_info "$path is not a file (all tests failed)"
    return 1
}

is_block_device() {
    local path="$1"

    if [ -z "$path" ]; then
        print_warning "Empty path provided to is_block_device"
        return 1
    fi

    # Standard block device test
    if [ -b "$path" ]; then
        echo_info "$path is a standard block device (-b test succeeded)"
        return 0
    fi

    # Check in /dev/disk/by-* symlinks
    local _target
    for disk_by in /dev/disk/by-id /dev/disk/by-uuid /dev/disk/by-label /dev/disk/by-path; do
        if [ -d "$disk_by" ]; then
            # Check if our path is a target of any symlink in these directories
            for link in "$disk_by"/*; do
                if [ -L "$link" ]; then
                    _target=$(readlink -f "$link")
                    if [ "$_target" = "$path" ] || [ "$_target" = "$(readlink -f "$path")" ]; then
                        echo_info "$path resolves to block device via symlink $link"
                        return 0
                    fi
                fi
            done
        fi
    done

    # Check if it appears as a block device in /proc/partitions
    if grep -q "$(basename "$path")" /proc/partitions 2>/dev/null; then
        echo_info "$path found in /proc/partitions"
        return 0
    fi

    # Check if lsblk recognizes it
    if lsblk "$path" >/dev/null 2>&1; then
        echo_info "$path recognized by lsblk"
        return 0
    fi

    echo_info "$path is not a block device (all tests failed)"
    return 1
}

is_mounted() {
    local dev="$1"
    local mnt="$2"

    if [ -z "$dev" ] || [ -z "$mnt" ]; then
        print_warning "Empty parameters provided to is_mounted"
        return 1
    fi

    # Normalize paths to canonical form
    local real_dev
    local real_mnt

    # Get real path for device if it exists
    if [ -e "$dev" ]; then
        real_dev=$(readlink -f "$dev")
    else
        real_dev="$dev"  # Use as-is if it doesn't exist
    fi

    # Get real path for mountpoint if it exists
    if [ -e "$mnt" ]; then
        real_mnt=$(readlink -f "$mnt")
    else
        real_mnt="$mnt"  # Use as-is if it doesn't exist
    fi

    # Check if device is mounted at the specified mountpoint
    if mount | grep -q "^$real_dev on $real_mnt "; then
        echo_info "$dev is mounted at $mnt (exact match in mount output)"
        return 0
    fi

    # Check /proc/mounts which contains canonical device paths
    if grep -q "^$real_dev $real_mnt " /proc/mounts 2>/dev/null; then
        echo_info "$dev is mounted at $mnt (found in /proc/mounts)"
        return 0
    fi

    # For block devices, check if any matching device is mounted at the mountpoint
    if is_block_device "$dev"; then
        # Get device name without /dev/ prefix
        local devname
        devname=$(basename "$real_dev")

        # Check if any entry in /proc/mounts matches the device and mountpoint
        if grep -q " $real_mnt " /proc/mounts 2>/dev/null; then
            # Get the device from matching mountpoint line
            local mounted_dev
            mounted_dev=$(grep " $real_mnt " /proc/mounts | cut -d' ' -f1)

            echo_info "Mountpoint $mnt is used by device $mounted_dev"

            # Check if it's our device or a link to it
            if [ "$mounted_dev" = "$real_dev" ] || readlink -f "$mounted_dev" 2>/dev/null | grep -q "$devname"; then
                echo_info "$dev is mounted at $mnt (device match by name)"
                return 0
            fi
        fi
    fi

    # Check for devices in /media/pi/ which might be automounted
    if [[ "$mnt" == /media/pi/* ]]; then
        for mounted in /media/pi/*; do
            if [ -d "$mounted" ] && mountpoint -q "$mounted" 2>/dev/null; then
                # Get the device for this mountpoint
                local auto_dev
                auto_dev=$(grep " $mounted " /proc/mounts 2>/dev/null | cut -d' ' -f1)

                if [ -n "$auto_dev" ]; then
                    echo_info "Found automounted device $auto_dev at $mounted"

                    # Check if it matches our device
                    if [ "$auto_dev" = "$real_dev" ] || [ "$auto_dev" = "$dev" ]; then
                        echo_info "$dev is automounted at $mounted (device match)"
                        return 0
                    fi

                    # Check if device names match after normalization
                    local norm_auto_dev # ai! do not join declaration with assignment please!
                    local norm_dev # ai! do not join declaration with assignment please!
                    norm_auto_dev=$(basename "$auto_dev" | tr -d '[:cntrl:]')
                    norm_dev=$(basename "$dev" | tr -d '[:cntrl:]')
                    if [ "$norm_auto_dev" = "$norm_dev" ]; then
                        echo_info "$dev matches normalized device $auto_dev at $mounted"
                        return 0
                    fi
                fi
            fi
        done
    fi

    echo_info "$dev is not mounted at $mnt (all tests failed)"
    return 1
}

set_from() {
    if [ -z "$1" ]; then
        print_warning "Empty path provided to set_from"
        return 1
    fi
    
    from="$1"
    echo_info "Source location set to: $from"
    
    # Validate the path exists
    if ! [ -e "$from" ]; then
        # Additional diagnostics for non-existent paths
        echo_info "Path diagnostics for non-existent path: $from"
        if [ "$quick" -ne 0 ]; then
            echo_info "- Parent directory: $(dirname "$from")"
            if [ -d "$(dirname "$from")" ]; then
                echo_info "- Parent exists: YES"
            else
                echo_info "- Parent exists: NO"
            fi
            if parent_contents=$(ls -la "$(dirname "$from")" 2>&1); then
                echo_info "- Parent contents: $parent_contents"
            else
                echo_info "- Parent contents: Cannot access"
            fi
        fi
        echo_error 1 "Source path does not exist: $from"
    else
        # Check if the source path contains the required home_dir
        if [ -d "$from/$home_dir" ]; then
            echo_info "Found required $home_dir directory in $from"
        else
            if [ "$quick" -ne 0 ]; then
                if source_contents=$(ls -la "$from" 2>&1); then
                    echo_info "Contents of $from: $source_contents"
                else
                    echo_info "Contents of $from: Cannot access"
                fi
            fi
            echo_error 1 "Required directory $home_dir not found in $from"
        fi
    fi
    
    return 0
}

main "$@"
exit $?
