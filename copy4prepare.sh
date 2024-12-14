#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
		echo "Bez sudo!"
		exit 1
fi

device="/dev/sda1"
mount_point="/mnt/.copy4prepare"
do_umount=0

path_from=""
path_to="/home/$USER/.mentor"
file="installer4lab.sh"
tmp_dir="/tmp/.copy4prepare"
inner_script_args=""

show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --from <device>       Specify the device to copy from (default: /dev/sda1)"
    echo "  --mnt <mount_point>   Specify the mount point (default: /mnt/.copy4prepare)"
    echo "  --file <file>         Specify the file to copy (default: installer4lab.sh)"
    echo "  --target <path>       Specify the target path (default: /home/\$USER/.mentor)"
    echo "  --cmd <args>          Specify the arguments to pass to the command"
    echo "  --help                Show this help message"
}

main() {
    parse "$@"

    if ! mkdir -p "$path_to" || [ ! -w "$path_to" ]; then
        echo "Blad zapisu do $path_to"
        exit 1
    fi

    if ! mkdir -p "$tmp_dir" || [ ! -w "$tmp_dir" ]; then
        echo "Blad zapisu $tmp_dir"
        exit 1
    fi

    input_path="${device}"
    device=""

    if is_block_device "$input_path"; then
        device=$input_path
        if is_mounted "$input_path"; then
            mount_point=$(mount | grep "$input_path" | awk '{print $3}')
            set_path_from "$mount_point"
        else
            if ! mkdir -p "$mount_point" || ! rmdir "$mount_point" 2>/dev/null; then
                print_error "mount point $mount_point jest zajety lub nie masz uprawnien do zapisu"
            fi
            do_umount=1
            mount_device "$input_path"
            set_path_from "$mount_point"
        fi
    elif is_directory "$input_path"; then
        mount_point=""
        set_path_from "$input_path"
    else
        print_error "Niewlasciwa sciezka: $input_path"
    fi

    echo "Kopiuje plik z: $path_from"

    if ! sudo cp -fr "$path_from/$file" "$tmp_dir"; then
        print_error "Nie udalo sie skopiowac do /tmp"
    fi

    if ! cmp -s "$path_from/$file" "$tmp_dir/$file"; then
        print_error "Kopiowanie z bledem"
    fi

    if [ "$do_umount" -eq 1 ]; then
        if ! sudo umount "$mount_point"; then
            print_error "Nie udalo sie umount $mount_point"
        fi
    fi

		echo "Naprawiam endls..."
		
    dos2unix "$tmp_dir/$file" &&

    if ! bash -n "$tmp_dir/$file"; then
        print_error "Plik nie jest poprawnym skryptem bash"
    fi  &&

    if ! sudo cp "$tmp_dir/$file" "$path_to/$file"; then
        print_error "Nie udalo sie skopiowac pliku do $path_to"
    fi &&
    
    echo "Plik skopiowany do $path_to" &&

    sudo chown "$USER:$USER" "$path_to/$file" &&
    sudo chmod +x "$path_to/$file" &&
    
    echo "Uruchamiam:"
    echo "$path_to/$file $inner_script_args" &&

    "$path_to/$file" "$inner_script_args" &
}

parse() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --from)
                device="$2"
                shift 2
                ;;
            --mnt)
                mount_point="$2"
                shift 2
                ;;
            --file)
                file="$2"
                shift 2
                ;;
            --target)
                path_to="$2"
                shift 2
                ;;
            --cmd)
                shift
                inner_script_args="$*"
                break
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
    sudo mount | grep -q "on $1 "
}

mount_device() {
    if ! sudo mount "$1" "$mount_point"; then
        print_error "Failed to mount $1 at $mount_point"
    fi
}

set_path_from() {
    path_from="$1"
}

main "$@"