#!/bin/bash
# -*- coding: utf-8 -*-
do_umount=0                          # Flag to track if we mounted a device
from="/dev/sd[a-z][1-9]"                       # Source location (block device or directory)
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
error_count=0
warning_count=0
user=1
debug=0
WERSJA="!WERSJA!"
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
    return 0
}

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
    return 0
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
    if ! cmp -s "$_file" "$_sourcefile"; then
        echo_info "Files are different after rsync: $_file and $_sourcefile"
    fi
    echo_info "Converting $_file to Unix format"
    if ! dos2unix -f -k "$_file" 2>/dev/null; then
        echo_info "Warning: dos2unix conversion issue with $_file, continuing"
    fi
    if [[ "$_file" == *.sh ]]; then
        echo_info "Making $_file executable"
        if ! chmod +x "$_file"; then
            echo_info "Warning: Failed to make $_file executable, continuing"
        fi
        echo_info "Validating bash script $_file"
        if ! bash -n "$_file"; then
            echo_error $LINENO "$_file"
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
    local backup_path="${filepath}.lab.bak"
    if [[ "$filepath" == *"home/pi/.mentor"* || "$filepath" == *"home/pi/.source4rpi"* ]]; then
        echo_info "Skipping backup creation for $filepath (excluded path)"
        return 0
    fi
    if [ -f "$backup_path" ]; then
        echo_info "Backup already exists for $filepath, skipping backup creation"
        return 0
    fi
    is_file "$_sourcefile"
    if [ $last_is_file -ne 1 ]; then
        echo_error $LINENO "$_sourcefile"
    fi
    if [ "$dry" -ne 1 ]; then
        echo_info "backup: $filepath to $backup_path"
        if ! sudo -u pi cp "$filepath" "$backup_path"; then
            echo_into "Failed to create backup file $backup_path but continuing"
        fi
    else
        echo_info "dry: backup: $filepath to $backup_path"
    fi
    return 0
}
rsync_line_test() {
    local p1="$1"
    local p2="$2"
    if [ -z "$p1" ] || [ -z "$p2" ]; then
        return 1
    fi
    if [[ "$p1" == "sending" || "$p1" == "sent" || "$p1" == "total" || "$p1" == *"speedup"* ]]; then
        return 1
    fi
    p1="/${p1#/}"
    p2="/${p2#/}"
    echo_info "Processing rsync paths:"
    echo_info "  Path 1: '$p1'"
    echo_info "  Path 2: '$p2'"
    if [[ "${p1: -1}" == "/" ]]; then
        echo_info "Skipping directory path: $p1"
        return 1
    fi
    if [[ "${p2: -1}" == "/" ]]; then
        echo_info "Skipping path with trailing slash: $p2"
        return 1
    fi
    if [[ "$p1" == *"building file list"* || "$p2" == *"building file list"* ]]; then
        return 1
    fi
    if [[ "$p1" == *.lab.bak || "$p2" == *.lab.bak ]]; then
        echo_info "Skipping backup file: $p1"
        return 1
    fi
    if [[ "$p1" == *.fill || "$p2" == *.lab.bak ]]; then
        echo_info "Skipping fill file: $p1"
        return 1
    fi
    if [[ "$p1" == *.fix || "$p2" == *.lab.bak ]]; then
        echo_info "Skipping fix file: $p1"
        return 1
    fi
    return 0
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
    if ! $dry_rsync_cmd > "$dry_run_file"; then
        echo_info "Warning: Dry run rsync failed, continuing anyway"
    fi
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
    rm -f "$dry_run_file"
    echo_info "Starting actual rsync operation..."
    echo_info "RSYNC: $from/$home_dir/ >> $target ($exclude_option)"
    if [ "$dry" -ne 1 ]; then
        local rsync_output_file
        rsync_output_file=$(mktemp)
        if ! $rsync_cmd > "$rsync_output_file"; then
            echo_info "Warning: Rsync operation completed with errors, checking results"
        fi
        while read -r line; do
            local first_part
            local second_part
            first_part="${line%% *}"
            second_part="${line#* }"
            if ! rsync_line_test "$first_part" "$second_part"; then
                continue
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
            if ! rm -rf "$mntdir"; then
                print_stop "Failed to remove directory $mntdir, continuing anyway"
            fi
        fi
    fi
}
mnt_mnt() {
    echo_info "Preparing mount point $mntdir"
    if [ ! -d "$mntdir" ]; then
        echo_info "Creating mount directory $mntdir"
        if ! sudo -u pi mkdir -p "$mntdir"; then
            print_error "Failed to create mount directory $mntdir"
        fi
    fi
    if is_mounted "$from" "$mntdir"; then
        echo_info "$from is already mounted at $mntdir"
        local actual_mntdir
        actual_mntdir=$(mount | grep "$from" | awk '{print $3}')
        echo_info "Using actual mount point: $actual_mntdir"
        set_from "$actual_mntdir"
        return 0
    fi
    local existing_mount
    existing_mount=$(mount | grep "$from" | awk '{print $3}' | head -n1)
    if [ -n "$existing_mount" ]; then
        echo_info "$from is already mounted at $existing_mount, using that mount point"
        set_from "$existing_mount"
        return 0
    fi
    echo_info "Mounting device $from at $mntdir"
    sudo mount "$from" "$mntdir" || print_error "Failed to mount $from at $mntdir"
    do_umount=1
    set_from "$mntdir"
}
mnt_init() {
    echo_info "Initializing mount system for source: $from"
    echo_info "Current mounts:"
    mount | grep -E '(^/dev/sd|^/media/pi)' || echo_info "No relevant mounts found"
    echo_info "Available block devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL 2>/dev/null || echo_info "lsblk failed or no devices found"
    if is_block_device "$from"; then
        echo_info "$from is a block device, proceeding with mount"
        mnt_mnt "$from"
        return 0
    fi
    if is_directory "$from"; then
        echo_info "$from is a directory, using directly"
        set_from "$from"
        return 0
    fi
    if echo "$from" | grep -q '\[[a-z]-[a-z]\]' || echo "$from" | grep -q '\[[0-9]-[0-9]\]'; then
        echo_info "Detected range pattern in: $from"
        local gotit=0
        shopt -s nullglob  # Ensure non-matching globs expand to nothing
        local matching_devices=("$from")
        shopt -u nullglob
        echo_info "Found ${#matching_devices[@]} potential matches for pattern $from"
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
        if [ "$gotit" -eq 0 ]; then
            print_error 1 "Failed to find any suitable block device matching pattern: $from"
        fi
    else
        echo_info "Path '$from' is not recognized as a block device or directory"
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
        if grep -q " $from " /proc/mounts 2>/dev/null; then
            echo_info "Found '$from' in /proc/mounts:"
            grep " $from " /proc/mounts
        else
            echo_info "Path '$from' not found in /proc/mounts"
        fi
        echo_info "Checking /media/pi/ for matching paths..."
        local found=0
        for media_path in /media/pi/*; do
            if [ -d "$media_path" ]; then
                echo_info "Found directory: $media_path"
                if mountpoint -q "$media_path" 2>/dev/null; then
                    echo_info "$media_path is a mountpoint"
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
create_copy4prepare_marker() {
    local marker_dir="$target/.mentor"
    local marker_file="copy4prepare.lab.marker"
    mkdir -p "$marker_dir" || {
        print_error "Failed to create directory for marker file";
    }
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local username
    username="$(whoami)"
    local hostname
    hostname="$(hostname)"
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
        echo_info "# user_level=$user"
        echo_info "# debug_level=$debug"
        echo_info "# "
        echo_info "# ---"
        } > "$marker_dir/$marker_file" || {
        echo_error $LINENO ""
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
        echo_error $LINENO ""
    fi
    parse "$@"
    print_parsed_arguments
    echo_info "Will clean previous mentor files..."
    if [ "$brestore" -eq 1 ]; then
        echo_info "Restoring configuration from backup files..."
        sudo find "/home/pi" -name "*.lab.bak" -exec sh -c '
            original_file="${1%.lab.bak}"
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
        restore_count=0
        fail_count=0
        sudo find "/home/pi" -name "*.lab.bak" -exec sh -c '
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
    for path in "$target/.mentor" "$target/.source4rpi" "$target/.config/Mentor" "$target/.prepare4lab.step"; do
        if [ -e "$path" ]; then
            echo_info "Removing $path"
            if ! rm -rf "$path"; then
                echo_stop "Failed to remove $path, continuing anyway"
            fi
        fi
    done
    echo_info "0" | sudo -u pi tee "$target"/.prepare4lab.step > /dev/null || {
        print_error "Failed to write to '$target'/.prepare4lab.step"
    }
    if ! cp -rf /etc/skel/.profile "$target/." ; then
        echo_error $LINENO ""
    fi
    mnt_init
    if [ "$nosync" -ne 1 ]; then
        run_rsync || { print_error "Failed to run rsync"; }
    fi
    un_un
    if [ "$norun" -ne 1 ]; then
        verify_prepare_script
        echo_stop "Running prepare script" "sudo $run ${prepare4lab_args[*]}"
        
        if [ "$dry" -ne 1 ]; then
            if ! sudo "$run" "${prepare4lab_args[@]}"; then
                echo_error $LINENO ""
            fi
        else
            echo_info "dry: Would run: sudo $run ${prepare4lab_args[*]}"
        fi
    else
        echo_info "Skipping script execution (--norun specified)"
    fi
    if [ "$dry" -eq 0 ]; then
        create_copy4prepare_marker
    else
        echo_info "--dry mode enabled. Skipping marker file creation."
    fi
    echo_info "Operation complete with $error_count errors and $warning_count warnings"
    return $status
}
parse() {
  if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
      show_help
      exit 0
  fi
  
  if [ $# -gt 0 ]; then
      case "$1" in
          prepare|install|setup)
              job="$1"
              shift
              ;;
          --*)
              echo_error $LINENO ""
              ;;
          *)
              echo_error $LINENO "$1"
              ;;
      esac
  else
      echo_error $LINENO ""
  fi
  
  copy4prepare_args=()
  prepare4lab_args=("$job")  # Start with job
  
  while [ $# -gt 0 ]; do
      case "$1" in
          --quick|--debug)
              prepare4lab_args+=("$1")
              if [ "$1" = "--quick" ]; then
                  quick=1
              elif [ "$1" = "--debug" ]; then
                  debug=1
              fi
              ;;
          --continue|--mic|--remote|--devel)
              prepare4lab_args+=("$1")
              ;;
          --student)
              prepare4lab_args+=("$1")
              shift
              if [ $# -gt 0 ]; then
                  prepare4lab_args+=("$1")  # student number
                  shift
                  if [ $# -gt 0 ]; then
                      prepare4lab_args+=("$1")  # student IP
                  else
                      echo_error $LINENO ""
                  fi
              else
                  echo_error $LINENO ""
              fi
              ;;
          --from)
              shift
              from="${1:-}"
              if [ -z "$from" ]; then
                  echo_error $LINENO ""
              fi
              copy4prepare_args+=("--from" "$from")
              ;;
          --mnt)
              shift
              mntdir="${1:-}"
              if [ -z "$mntdir" ]; then
                  echo_error $LINENO ""
              fi
              copy4prepare_args+=("--mnt" "$mntdir")
              ;;
          --target)
              shift
              target="${1:-}"
              if [ -z "$target" ]; then
                  echo_error $LINENO ""
              fi
              copy4prepare_args+=("--target" "$target")
              ;;
          --timeout)
              shift
              timeout="${1:-}"
              if [ -z "$timeout" ] || ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
                  echo_error $LINENO ""
              fi
              copy4prepare_args+=("--timeout" "$timeout")
              ;;
          --norun|--nosync|--dry|--brestore|--bclear|--nobackup)
              case "$1" in
                  --norun) norun=1 ;;
                  --nosync) nosync=1 ;;
                  --dry) dry=1 ;;
                  --brestore) brestore=1 ;;
                  --bclear) bclear=1 ;;
                  --nobackup) nobackup=1 ;;
              esac
              copy4prepare_args+=("$1")
              ;;
          *)
              echo_error $LINENO "$1"
              ;;
      esac
      shift
  done
  if [ -z "$job" ]; then
      echo_info "no job specified, using default: install --devel"
      job="install --devel"
  fi
  if [ -z "$from" ]; then
      echo_info "no source specified, using default: $from"
  fi
  if [ -z "$mntdir" ]; then
      echo_info "no mount directory specified, using default: $mntdir"
  fi
  if [ -z "$target" ]; then
      echo_info "no target directory specified, using default: $target"
  fi
  if [ "$brestore" -eq 1 ] && [ "$bclear" -eq 1 ]; then
      echo_error $LINENO ""
  fi
}
is_directory() {
    local path="$1"
    if [ -z "$path" ]; then
        echo_info "Empty path provided to is_directory"
        return 1
    fi
    if [ -d "$path" ]; then
        echo_info "$path is a standard directory (-d test succeeded)"
        return 0
    fi
    if mountpoint -q "$path" 2>/dev/null; then
        echo_info "$path is a mountpoint (mountpoint command succeeded)"
        return 0
    fi
    if grep -q " $path " /proc/mounts 2>/dev/null; then
        echo_info "$path found in /proc/mounts"
        return 0
    fi
    if cd "$path" >/dev/null 2>&1; then
        if ! cd - >/dev/null 2>&1; then
            print_error "Failed to return to previous directory"
        fi
        echo_info "$path is accessible via cd"
        return 0
    fi
    if [[ "$path" == /media/pi/* ]]; then
        for dir in /media/pi/*; do
            if [ -d "$dir" ]; then
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
last_is_file=0
is_file() {
    last_is_file=0
    local path="$1"
    if [ -z "$path" ]; then
        echo_error $LINENO ""
    fi
    if [ -f "$path" ]; then
        echo_info "$path is a standard file (-f test succeeded)"
        last_is_file=1
    fi
    if [ -L "$path" ] && [ -f "$(readlink -f "$path")" ]; then
        echo_info "$path is a symlink to a file"
        last_is_file=1
    fi
    if cat "$path" >/dev/null 2>&1; then
        echo_info "$path is accessible via cat"
        last_is_file=1
    fi
    echo_wait "$path is not a file (all tests failed)"
}
is_block_device() {
    local path="$1"
    if [ -z "$path" ]; then
        print_info "Empty path provided to is_block_device"
        return 1
    fi
    if [ -b "$path" ]; then
        echo_info "$path is a standard block device (-b test succeeded)"
        return 0
    fi
    local _target
    for disk_by in /dev/disk/by-id /dev/disk/by-uuid /dev/disk/by-label /dev/disk/by-path; do
        if [ -d "$disk_by" ]; then
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
    if grep -q "$(basename "$path")" /proc/partitions 2>/dev/null; then
        echo_info "$path found in /proc/partitions"
        return 0
    fi
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
        echo_into "Empty parameters provided to is_mounted"
        return 1
    fi
    local real_dev
    local real_mnt
    if [ -e "$dev" ]; then
        real_dev=$(readlink -f "$dev")
    else
        real_dev="$dev"  # Use as-is if it doesn't exist
    fi
    if [ -e "$mnt" ]; then
        real_mnt=$(readlink -f "$mnt")
    else
        real_mnt="$mnt"  # Use as-is if it doesn't exist
    fi
    if mount | grep -q "^$real_dev on $real_mnt "; then
        echo_info "$dev is mounted at $mnt (exact match in mount output)"
        return 0
    fi
    if grep -q "^$real_dev $real_mnt " /proc/mounts 2>/dev/null; then
        echo_info "$dev is mounted at $mnt (found in /proc/mounts)"
        return 0
    fi
    if is_block_device "$dev"; then
        local devname
        devname=$(basename "$real_dev")
        if grep -q " $real_mnt " /proc/mounts 2>/dev/null; then
            local mounted_dev
            mounted_dev=$(grep " $real_mnt " /proc/mounts | cut -d' ' -f1)
            echo_info "Mountpoint $mnt is used by device $mounted_dev"
            if [ "$mounted_dev" = "$real_dev" ] || readlink -f "$mounted_dev" 2>/dev/null | grep -q "$devname"; then
                echo_info "$dev is mounted at $mnt (device match by name)"
                return 0
            fi
        fi
    fi
    if [[ "$mnt" == /media/pi/* ]]; then
        for mounted in /media/pi/*; do
            if [ -d "$mounted" ] && mountpoint -q "$mounted" 2>/dev/null; then
                local auto_dev
                auto_dev=$(grep " $mounted " /proc/mounts 2>/dev/null | cut -d' ' -f1)
                if [ -n "$auto_dev" ]; then
                    echo_info "Found automounted device $auto_dev at $mounted"
                    if [ "$auto_dev" = "$real_dev" ] || [ "$auto_dev" = "$dev" ]; then
                        echo_info "$dev is automounted at $mounted (device match)"
                        return 0
                    fi
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
        echo_error $LINENO ""
    fi
    from="$1"
    echo_info "Source location set to: $from"
    if ! [ -e "$from" ]; then
        if [ "$quick" -eq 0 ]; then
            echo_info "Path diagnostics for non-existent path: $from"
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
        echo_error $LINENO "$from"
    else
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
            echo_error $LINENO "$from $home_dir"
        fi
    fi
    return 0
}
main "$@"
exit $?
