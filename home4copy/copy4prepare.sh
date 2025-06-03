#!/bin/bash
# -*- coding: utf-8 -*-
WERSJA=0.7.7
do_umount=0                          # Flag to track if we mounted a device
from="USB"                       # Source location (block device or directory)
mntdir=/home/pi/mnt                          # Mount point for block devices
target=/home/pi                      # Target directory for file operations
home_dir=home4copy                   # Directory name on source containing files
file=prepare4lab.sh                  # Script filename to run after copying
quick=0                              # Flag to skip confirmation delays
norun=0                              # Flag to skip running scripts
nosync=0                             # Flag to skip rsync operations
job="install"
timeout=0                            # Wait time before starting operations
run="/home/pi/.mentor/prepare4lab.sh" # Path to the script to run
dry=0                                # Flag for simulation mode (no changes)
brestore=0                           # Flag to restore from backups and exit
bclear=0                             # Flag to clear backup files and exit
nobackup=0                           # Flag to skip creating backup files
user=1
debug=0

show_help() {
    cat << EOF
===============================================================================
 copy4prepare.sh v$WERSJA - Mentor Lab Preparation Utility (Enhanced Path Detection)
===============================================================================
 Usage: sudo $0 job [options]
 Job Type (required - first argument):
   prepare              Preparation job
   install              Installation job  
   setup                Setup job
   bstatus              Show backup status and exit
 Main Options:
   --from <path>          Block device or directory (default: ${from})
   --mnt <path>           Mount point for the device (default: ${mntdir})
   --timeout <seconds>    Wait time before starting the process (default: ${timeout})
 Script Execution:
   --quick                Skip confirmation delays (passed to prepare4lab)
   --debug                Set debug verbosity level (passed to prepare4lab)
 prepare4lab-specific Options (passed through to prepare4lab.sh):
   --continue             Don't start from scratch, for 'install'
   --student [Nr] [IP]    For 'setup' job
   --mic                  Dynamic mode
   --remote               Via SSH
   --devel                When student4lab from sources
 Backup Operations:
   --brestore             Restore configuration from backups and exit
   --bclear               Clear backup files and exit
   --nobackup             Skip creating backup files
 Help:
   --help                 Show this help message
 Use:
   sudo dos2unix /media/pi/audytor/home4copy/copy4prepare.sh
   sudo chmod +x /media/pi/audytor/home4copy/copy4prepare.sh
   sudo /media/pi/audytor/home4copy/copy4prepare.sh install --devel --quick --timeout 0 --from /media/pi/audytor
===============================================================================
EOF
}

echo_error() {
  local lineno="$1"
  local message="$2"
  echo "[err@$lineno] $message"
  if [ "$user" -eq 1 ] && [ $quick -eq 0 ]; then
      echo "[Enter] to continue, Ctrl+C to cancel..."
      read -r
  fi
  exit 1
}

echo_info() {
    local msg="$1"
    echo "$msg"
}

echo_info "copy4prepare ver: $WERSJA"

echo_stop() {
    local operation="$1"
    sync
    if [ "$user" -eq 1 ]; then
        echo ""
        if [ "$quick" -eq 1 ]; then
            echo "?> $operation //[Enter] (7s)"
            read -t 7 -r || true
        else
            echo "?> $operation"
            echo "[Enter] to continue, Ctrl+C to cancel..."
            read -r
        fi
    else
        echo "?> $operation"
    fi
}

echo_wait() {
    local message="$1"
    if [ "$user" -eq 1 ]; then
        echo ""
    fi
    if [[ "$user" -eq 1 || "$debug" -eq 1 ]] && [ "$quick" -eq 0 ]; then
        echo "!> $message"
        read -t 1 -r || true
    else
        echo "!> $message"
    fi
}

is_file() {
    local path="$1"
    last_is_file=0
    if [ -f "$path" ]; then
        last_is_file=1
    fi
}

is_directory() {
    local path="$1"
    last_is_directory=0
    if [ -d "$path" ] || [[ "$path" =~ /$ ]]; then
        last_is_directory=1
    fi
}

is_block_device() {
    local path="$1"
    last_is_block_device=0
    
    if [ -b "$path" ]; then
        last_is_block_device=1
        return
    fi

    # Extract device name (e.g., sda1 -> sda)
    local device_name
    device_name=$(basename "$path")
    local base_device=${device_name%[0-9]*}  # Remove partition number
    # Check if it's a removable device
    local removable_file="/sys/block/$base_device/removable"
    if [ -f "$removable_file" ] && [ "$(cat "$removable_file")" = "1" ]; then
        last_is_block_device=1
        return
    fi
    
    # Additional check: look for USB subsystem in device path
    local device_path="/sys/block/$base_device"
    if [ -d "$device_path" ]; then
        # Follow symlinks to find if device is connected via USB
        local real_path
        real_path=$(readlink -f "$device_path")
        if [[ "$real_path" == *"/usb"* ]]; then
            last_is_block_device=1
            return
        fi
    fi
    
    # Check if device is in typical removable media mount points
    if [[ "$path" == /media/* ]] || [[ "$path" == /mnt/* ]]; then
        # Additional safety: check if it's not a system partition
        if ! grep -q "^$path " /proc/mounts 2>/dev/null || \
           ! grep -q " / \| /boot \| /home \| /var \| /usr " /proc/mounts 2>/dev/null; then
            last_is_block_device=1
            return
        fi
    fi
}

is_mounted() {
    local device="$1"
    local mountpoint="$2"
    last_is_mounted=0
    if mount | grep -q "$device.*$mountpoint"; then
        last_is_mounted=1
    fi
}

set_from() {
    from="$1"
    echo_info "Source path set to: $from"
}

restore_from_backup() {
    local filepath="$1"
    local force_restore="${2:-0}"
    local backup_path="${filepath}.lab.bak"
    
    if [ ! -f "$backup_path" ]; then
        echo_info "No backup found for $filepath, skipping restore"
        return 1
    fi
    
    if [ "$force_restore" -eq 1 ] || [ "$brestore" -eq 1 ]; then
        echo_info "Restoring $filepath from backup $backup_path"
        
        # Verify backup integrity before restore
        if [ ! -s "$backup_path" ]; then
            echo_error $LINENO "Backup file $backup_path is empty or corrupted"
        fi
        
        # Create a safety backup of current file if it exists and differs
        if [ -f "$filepath" ] && ! cmp -s "$filepath" "$backup_path"; then
            local safety_backup
            safety_backup="${filepath}.before_restore.$(date +%s)"
            echo_info "Creating safety backup: $safety_backup"
            cp "$filepath" "$safety_backup" || echo_info "Warning: Failed to create safety backup"
        fi
        
        # Restore from backup using sudo mv -f
        if [ "$dry" -ne 1 ]; then
            sudo mv -f "$backup_path" "$filepath" || echo_error $LINENO "Failed to restore $filepath from backup"
            echo_info "Successfully restored $filepath from backup"
        else
            echo_info "dry: Would restore $filepath from $backup_path"
        fi
        
        return 0
    else
        echo_info "Restore not requested for $filepath"
        return 1
    fi
}

handle_brestore() {
    if [ "$brestore" -eq 1 ]; then
        echo_info "Restoring configuration from backup files..."
        echo_info "Scanning entire filesystem for .lab.bak files..."
        
        local restore_count=0
        local fail_count=0
        
        # Find all .lab.bak files on entire filesystem and process them without losing variable changes
        while IFS= read -r backup_file; do
            local original_file="${backup_file%.lab.bak}"

            echo_info "Found backup: $backup_file"

            if restore_from_backup "$original_file" 1; then
                restore_count=$((restore_count + 1))
                echo_info "✓ Restored: $original_file"
            else
                fail_count=$((fail_count + 1))
                echo_info "✗ Failed to restore: $original_file"
            fi
        done < <(find / -name "*.lab.bak" -type f 2>/dev/null)
        
        echo_info "=== Restore Summary ==="
        echo_info "Successfully restored: $restore_count files"
        echo_info "Failed to restore: $fail_count files"
        echo_info "======================="
        
        if [ $restore_count -gt 0 ]; then
            echo_info "Restore operation completed. Some services may need to be restarted."
            echo_info "Consider running: sudo systemctl restart ssh"
        fi
        
        exit 0
    fi
}

handle_bclear() {
    if [ "$bclear" -eq 1 ]; then
        echo_info "Clearing backup files..."
        echo_info "Scanning entire filesystem for .lab.bak files..."
        
        local clear_count=0
        local fail_count=0
        local total_size=0
        
        # Find all .lab.bak files on entire filesystem and process them without losing variable changes
        while IFS= read -r backup_file; do
            if [ -f "$backup_file" ]; then
                local backup_size
                backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
                total_size=$((total_size + backup_size))
                
                echo_info "Clearing: $backup_file (${backup_size} bytes)"
                
                if [ "$dry" -ne 1 ]; then
                    if rm -f "$backup_file"; then
                        clear_count=$((clear_count + 1))
                        echo_info "✓ Cleared: $backup_file"
                    else
                        fail_count=$((fail_count + 1))
                        echo_info "✗ Failed to clear: $backup_file"
                    fi
                else
                    clear_count=$((clear_count + 1))
                    echo_info "dry: Would clear: $backup_file"
                fi
            fi
        done < <(find / -name "*.lab.bak" -type f 2>/dev/null)
        
        echo_info "=== Clear Summary ==="
        echo_info "Successfully cleared: $clear_count files"
        echo_info "Failed to clear: $fail_count files"
        echo_info "Total space freed: $total_size bytes"
        echo_info "==================="
        
        exit 0
    fi
}

show_backup_status() {
    echo_info "=== Backup Status Report ==="
    echo_info "Scanning entire filesystem for .lab.bak files..."
    echo_info ""
    
    local backup_count=0
    local total_size=0
    
    while IFS= read -r backup_file; do
        if [ -f "$backup_file" ]; then
            local original_file="${backup_file%.lab.bak}"
            local backup_size
            backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
            local backup_date
            backup_date=$(stat -c%y "$backup_file" 2>/dev/null || echo "unknown")
            local status="OK"

            # Check if original file exists and differs
            if [ -f "$original_file" ]; then
                if cmp -s "$original_file" "$backup_file"; then
                    status="IDENTICAL"
                else
                    status="DIFFERS"
                fi
            else
                status="ORIGINAL_MISSING"
            fi

            echo_info "  $backup_file"
            echo_info "    Size: $backup_size bytes"
            echo_info "    Date: $backup_date"
            echo_info "    Status: $status"
            echo_info ""

            backup_count=$((backup_count + 1))
            total_size=$((total_size + backup_size))
        fi
    done < <(find / -name "*.lab.bak" -type f 2>/dev/null)
    
    echo_info "=== Summary ==="
    echo_info "Total backups found: $backup_count"
    echo_info "Total backup size: $total_size bytes"
    echo_info "================="
}

create_backup() {
    local filepath="$1"
    if [ "$nobackup" -eq 1 ]; then
        echo_info "--nobackup enabled. Skipping backup creation for $filepath"
    elif [[ "$filepath" == *"home/pi/.mentor"* || "$filepath" == *"home/pi/.source4rpi"* ]]; then
        echo_info "Skipping backup creation for $filepath (excluded path)"
    else
        local backup_path="${filepath}.lab.bak"
        local backup_dir
        backup_dir="$(dirname "$backup_path")"

        # Check if backup already exists (compatible with prepare4lab.sh)
        if [ -f "$backup_path" ]; then
            echo_info "Backup already exists for $filepath, skipping backup creation"
            
            # Verify existing backup integrity
            if [ -f "$filepath" ] && ! cmp -s "$filepath" "$backup_path"; then
                echo_info "Warning: Existing backup differs from current file, keeping existing backup"
            fi
        else
            is_file "$filepath"
            if [ $last_is_file -ne 1 ]; then
                echo_info "Source file $filepath does not exist, no backup needed"
                return 0
            fi

            # Ensure backup directory exists
            if [ ! -d "$backup_dir" ]; then
                echo_info "Creating backup directory: $backup_dir"
                if ! sudo -u pi mkdir -p "$backup_dir"; then
                    echo_error $LINENO "Failed to create backup directory $backup_dir"
                fi
            fi

            if [ "$dry" -ne 1 ]; then
                echo_info "backup: $filepath to $backup_path"
                # Use cp with preservation of attributes (compatible with prepare4lab.sh)
                if ! cp -p "$filepath" "$backup_path"; then
                    echo_error $LINENO "Failed to create backup file $backup_path"
                fi

                # Verify backup was created successfully
                if [ ! -f "$backup_path" ]; then
                    echo_error $LINENO "Backup verification failed: $backup_path does not exist"
                fi

                # Compare source and backup to ensure integrity
                if ! cmp -s "$filepath" "$backup_path"; then
                    echo_error $LINENO "Backup verification failed: $backup_path content differs from source"
                fi
            else
                echo_info "dry: backup: $filepath to $backup_path"
            fi
        fi
    fi
}

verify_prepare_script() {
    local wersja_in_script
    echo_info "Verifying prepare script integrity before running: $run"
    is_file "$run"
    if [ $last_is_file -ne 1 ]; then
        echo_error $LINENO "$run"
    fi
    bash -n "$run" || echo_error $LINENO "$run"
    wersja_in_script=$(grep -m 1 "^WERSJA=" "$run" | cut -d'=' -f2)
    if [ -z "$wersja_in_script" ]; then
        echo_info "Warning: Could not extract version from prepare script"
        echo_wait "Script version not found, continue anyway?"
    else
        if [ "$wersja_in_script" != "$WERSJA" ]; then
            echo_info "WARNING: Version mismatch detected!"
            echo_info "  copy4prepare.sh version: $WERSJA"
            echo_info "  $file version: $wersja_in_script"
            echo_stop "Version mismatch" "Running prepare script with different version may cause issues"
        else
            echo_info "Version check passed: Both scripts at version $WERSJA"
        fi
    fi
    if [ ! -x "$run" ]; then
        echo_info "Adding execute permission to prepare script"
        chmod +x "$run" || echo_error $LINENO ""
    fi
    echo_info "Script verification completed"
}

handle_file() {
    local _file=$1
    local _sourcefile=$2
    _file="${_file%"${_file##*[![:space:]]}"}"
    _sourcefile="${_sourcefile%"${_sourcefile##*[![:space:]]}"}"
    echo_info "Handling file $_file"
    is_file "$_sourcefile"
    if [ $last_is_file -ne 1 ]; then
        echo_error $LINENO "$_sourcefile"
    fi
    cmp -s "$_file" "$_sourcefile" || echo_info "Files are different after rsync: $_file and $_sourcefile"
    echo_info "Converting $_file to Unix format"
    dos2unix -f -k "$_file" 2>/dev/null || echo_info "Warning: dos2unix conversion issue with $_file, continuing"
    if [[ "$_file" == *.sh ]]; then
        echo_info "Making $_file executable"
        chmod +x "$_file" || echo_info "Warning: Failed to make $_file executable, continuing"
        echo_info "Validating bash script $_file"
        bash -n "$_file" || echo_error $LINENO "$_file"
    fi
}

last_rsync_test=1
rsync_line_test() {
    last_rsync_test=0
    local p1="$1"
    local p2="$2"
    if [ -z "$p1" ] || [ -z "$p2" ]; then
        echo_info "Empty parameters provided to rsync_line_test"
    elif [[ "$p1" == "sending" || "$p1" == "sent" || "$p1" == "total" || "$p1" == *"speedup"* ]]; then
        echo_info "Skipping rsync status line: $p1"
    else
        p1="/${p1#/}"
        p2="/${p2#/}"
        if [[ "${p1: -1}" == "/" ]]; then
            echo_info "Skipping directory path: $p1"
        elif [[ "${p2: -1}" == "/" ]]; then
            echo_info "Skipping path with trailing slash: $p2"
        elif [[ "$p1" == *"building file list"* || "$p2" == *"building file list"* ]]; then
            echo_info "Skipping building file list line"
        elif [[ "$p1" == *.lab.bak || "$p2" == *.lab.bak ]]; then
            echo_info "Skipping backup file: $p1"
        elif [[ "$p1" == *.fill || "$p2" == *.lab.bak ]]; then
            echo_info "Skipping fill file: $p1"
        elif [[ "$p1" == *.fix || "$p2" == *.lab.bak ]]; then
            echo_info "Skipping fix file: $p1"
        else
            echo_wait "$p1 $p2"
        fi
    fi
}

run_rsync() {
    echo_info "Running rsync for home_dir (copy4prepare)"
    local exclude_option
    exclude_option="--exclude=/root4rpi --exclude=/copy4prepare.sh --exclude=*.lab.bak"
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
    echo_info "Performing dry run to identify files for backup..."
    echo_info "DRY RSYNC: $from/$home_dir/ >> $target ($dry_exclude_option)"
    local dry_run_file
    dry_run_file=$(mktemp)
    $dry_rsync_cmd > "$dry_run_file" || echo_info "Warning: Dry run rsync failed, continuing anyway"
    while read -r line; do
        local first_part
        local second_part
        first_part="${line%% *}"
        second_part="${line#* }"
        rsync_line_test "$first_part" "$second_part"
        if [ $last_rsync_test -eq 1 ]; then
          local fpath
          fpath="$target/$first_part"
          if [ "$dry" -ne 1 ]; then
              create_backup "$fpath"
              echo_info "Removing $fpath before copy"
              if [ -e "$fpath" ]; then
                  rm -rf "$fpath" || echo_info "Warning: Failed to remove $fpath, attempting to continue"
              fi
          else
              echo_info "dry: Would remove $fpath"
          fi
        fi
    done < "$dry_run_file"
    rm -f "$dry_run_file"
    echo_info "Starting actual rsync operation..."
    echo_info "RSYNC: $from/$home_dir/ >> $target ($exclude_option)"
    if [ "$dry" -ne 1 ]; then
        local rsync_output_file
        rsync_output_file=$(mktemp)
        $rsync_cmd > "$rsync_output_file" || echo_info "Warning: Rsync operation completed with errors, checking results"
        while read -r line; do
            local first_part
            local second_part
            first_part="${line%% *}"
            second_part="${line#* }"
            rsync_line_test "$first_part" "$second_part"
            if [ $last_rsync_test -ne 1 ]; then
                echo_error $LINENO "$first_part $second_part"
            fi
            if [[ $first_part == "$second_part" ]] || [[ $second_part == *uptodate* ]]; then
                echo_info "Processing $target/$first_part"
                handle_file "$target/$first_part" "$from/$home_dir/$first_part" || true
            fi
        done < "$rsync_output_file"
        rm -f "$rsync_output_file"
    else
        echo_info "Dry run mode: skipping actual rsync operation"
    fi
    echo_info "Rsync operation completed"
}

un_un() {
    if [ "$do_umount" -eq 1 ]; then
        echo_wait "Unmounting $mntdir"
        do_umount=0
        if mount | grep -q "$mntdir"; then
            echo_info "Unmounting $mntdir..."
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
                echo_stop "Failed to unmount $mntdir after $max_attempts attempts, continuing anyway"
            fi
        else
            echo_info "$mntdir is not mounted"
        fi
        if [ -d "$mntdir" ]; then
            echo_info "Removing mount directory $mntdir"
            rm -rf "$mntdir" || echo_stop "Failed to remove directory $mntdir, continuing anyway"
        fi
    fi
}

mnt_mnt() {
    echo_info "Preparing mount point $mntdir"
    if [ ! -d "$mntdir" ]; then
        echo_info "Creating mount directory $mntdir"
        sudo -u pi mkdir -p "$mntdir" || echo_error $LINENO "Failed to create mount directory $mntdir"
    fi
    is_mounted "$from" "$mntdir"
    if [ $last_is_mounted -eq 1 ]; then
        echo_info "$from is already mounted at $mntdir"
        local actual_mntdir
        actual_mntdir=$(mount | grep "$from" | awk '{print $3}')
        echo_info "Using actual mount point: $actual_mntdir"
        set_from "$actual_mntdir"
    else
        local existing_mount
        existing_mount=$(mount | grep "$from" | awk '{print $3}' | head -n1)
        if [ -n "$existing_mount" ]; then
            echo_info "$from is already mounted at $existing_mount, using that mount point"
            set_from "$existing_mount"
        else
            echo_info "Mounting device $from at $mntdir"
            sudo mount "$from" "$mntdir" || echo_error $LINENO "Failed to mount $from at $mntdir"
            do_umount=1
            set_from "$mntdir"
        fi
    fi
}

mnt_init() {
    echo_info "Initializing mount system for source: $from"
    
    if [ "$from" = "USB" ]; then
        echo_info "USB mode detected, scanning for USB devices..."
        local found_device=0
        
        # Iterate over /dev/sd[a-e][1-4] possibilities
        for drive in {a..e}; do
            for partition in {1..4}; do
                local device_path="/dev/sd${drive}${partition}"
                
                if [ -e "$device_path" ]; then
                    echo_info "Found device: $device_path"
                    
                    # Check if it's mounted
                    local mount_point
                    mount_point=$(mount | grep "^$device_path " | awk '{print $3}')
                    
                    if [ -n "$mount_point" ]; then
                        echo_info "$device_path is mounted at $mount_point"
                        set_from "$mount_point"
                        found_device=1
                        break 2
                    else
                        echo_info "$device_path is not mounted, attempting to mount"
                        set_from "$device_path"
                        mnt_mnt "$device_path"
                        found_device=1
                        break 2
                    fi
                else
                    continue
                fi
            done
        done
        
        if [ $found_device -eq 0 ]; then
            echo_error $LINENO "No USB devices found in /dev/sd[a-e][1-4] range"
        fi
    else
        # Original logic for non-USB sources
        is_block_device "$from"
        if [ $last_is_block_device -eq 1 ]; then
            echo_info "$from is a block device, proceeding with mount"
            mnt_mnt "$from"
        else
            is_directory "$from"
            if [ $last_is_directory -eq 1 ]; then
                echo_info "$from is a directory, using directly"
                set_from "$from"
            else
                echo_error $LINENO "Source $from is neither a valid block device nor directory"
            fi
        fi
    fi
}

# Parse command line arguments
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

if [ $# -gt 0 ]; then
    job="$1"
    shift
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --from)
                shift
                from="${1:-}"
                if [ -z "$from" ]; then
                    echo_error $LINENO "Missing argument for --from"
                fi
                ;;
            --mnt)
                shift
                mntdir="${1:-}"
                if [ -z "$mntdir" ]; then
                    echo_error $LINENO "Missing argument for --mnt"
                fi
                ;;
            --timeout)
                shift
                timeout="${1:-}"
                if [ -z "$timeout" ]; then
                    echo_error $LINENO "Missing argument for --timeout"
                fi
                ;;
            --quick)
                quick=1
                ;;
            --debug)
                debug=1
                ;;
            --brestore)
                brestore=1
                ;;
            --bclear)
                bclear=1
                ;;
            --nobackup)
                nobackup=1
                ;;
            --dry)
                dry=1
                ;;
            *)
                # Pass through other arguments to prepare4lab
                ;;
        esac
        shift
    done
fi

# Handle backup operations first
handle_brestore
handle_bclear

# Show backup status if requested
if [ "$job" = "bstatus" ]; then
    show_backup_status
    exit 0
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo_error $LINENO "This script must be run as root (use sudo)"
fi

# Wait timeout if specified
if [ "$timeout" -gt 0 ]; then
    echo_info "Waiting $timeout seconds before starting..."
    sleep "$timeout"
fi

# Initialize mount system
mnt_init

# Check if home_dir exists in source
if [ ! -d "$from/$home_dir" ]; then
    echo_error $LINENO "Source directory $from/$home_dir does not exist"
fi

# Run rsync operation
if [ "$nosync" -eq 0 ]; then
    run_rsync
else
    echo_info "Skipping rsync operations (--nosync)"
fi

# Verify and run prepare script
if [ "$norun" -eq 0 ]; then
    verify_prepare_script
    
    # Build command line for prepare4lab
    prepare_args="$job"
    if [ "$quick" -eq 1 ]; then
        prepare_args="$prepare_args --quick"
    fi
    if [ "$debug" -eq 1 ]; then
        prepare_args="$prepare_args --debug"
    fi
    
    echo_info "Running prepare script: $run $prepare_args"
    if [ "$dry" -ne 1 ]; then
        cd /home/pi || echo_error $LINENO "Failed to change to /home/pi"
        sudo -u pi "$run" "$prepare_args" || echo_error $LINENO "Prepare script execution failed"
    else
        echo_info "dry: Would run: $run $prepare_args"
    fi
else
    echo_info "Skipping prepare script execution (--norun)"
fi

# Cleanup
un_un

echo_info "copy4prepare.sh completed successfully"
exit 0