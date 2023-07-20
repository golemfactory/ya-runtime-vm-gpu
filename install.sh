#!/bin/bash
# shellcheck shell=bash

set -u

YA_INSTALLER_RUNTIME_VER=${YA_INSTALLER_RUNTIME_VER:-__TAG_NAME__}
YA_INSTALLER_RUNTIME_REPO_NAME="ya-runtime-vm-nvidia"
YA_INSTALLER_RUNTIME_ID="vm-nvidia"
YA_INSTALLER_RUNTIME_DESCRIPTOR="${YA_INSTALLER_RUNTIME_REPO_NAME}.json"

YA_RUNTIME_VM_PCI_DEVICE=${YA_RUNTIME_VM_PCI_DEVICE:-NULL}

YA_INSTALLER_GLM_PER_HOUR=${YA_INSTALLER_YA_INSTALLER_GLM_PER_HOUR:-0.025}
YA_INSTALLER_INIT_PRICE=${YA_INSTALLER_INIT_PRICE:-0}

YA_INSTALLER_DATA=${YA_INSTALLER_DATA:-$HOME/.local/share/ya-installer}
YA_INSTALLER_LIB=${YA_INSTALLER_LIB:-$HOME/.local/lib/yagna}

YA_MINIMAL_GOLEM_VERSION=0.13.0-rc9 

# Runtime tools #######################################################################################################

download_vm_gpu() {
    local _ostype _url

    _ostype="$1"
    test -d "$YA_INSTALLER_DATA/bundles" || mkdir -p "$YA_INSTALLER_DATA/bundles"

    _url="https://github.com/golemfactory/${YA_INSTALLER_RUNTIME_REPO_NAME}/releases/download/${YA_INSTALLER_RUNTIME_VER}/${YA_INSTALLER_RUNTIME_REPO_NAME}-${_ostype}-${YA_INSTALLER_RUNTIME_VER}.tar.gz"
    _dl_start "ya-runtime-vm-nvidia" "$YA_INSTALLER_RUNTIME_VER"
    (downloader "$_url" - | tar -C "$YA_INSTALLER_DATA/bundles" -xz -f -) || err "failed to download $_url"
    _dl_end
    echo -n "$YA_INSTALLER_DATA/bundles/${YA_INSTALLER_RUNTIME_REPO_NAME}-${_ostype}-${YA_INSTALLER_RUNTIME_VER}"
}

# Copies Runtime to plugins dir.
# Returns path to Runtime desccriptor.
install_vm_gpu() {
    local _src _plugins_dir

    _src="$1"
    _plugins_dir="$YA_INSTALLER_LIB/plugins"
    mkdir -p "$_plugins_dir"

    # remove old descriptor and runtime binaries
    for _file in $(ls "$_src"); do
        echo "Removing: $_plugins_dir/$_file";
        rm -rf "$_plugins_dir/$_file"
    done

    if [ $(runtime_exists) == "true" ]; then
        echo "Runtime with name \"$YA_INSTALLER_RUNTIME_ID\" already exists. Aborting.";
        exit 1;
    fi
    
    cp -r "$_src"/* "$_plugins_dir/"

    echo -n "$_plugins_dir/$YA_INSTALLER_RUNTIME_DESCRIPTOR";
}

runtime_exists() {
    provider_entry_exists "exe-unit"
}

preset_exists() {
    provider_entry_exists "preset"
}

# Checks if provided entry (exe-unit or preset) with name $YA_INSTALLER_RUNTIME_ID exists.
provider_entry_exists() {
    local _provider_cmd _new_runtime

    _provider_cmd=$1
    _new_entry=$YA_INSTALLER_RUNTIME_ID

    for old_entry in $(ya-provider $_provider_cmd list --json | jq '.[] | {name} | join(" ")'); do
        if [ "$old_entry" = "\"$_new_entry\"" ]; then
            echo -n "true";
            return 0;
        fi
    done;

    echo -n "false"
}

configure_runtime() {
    local _descriptor_path _set_name_query _add_extra_arg_query

    _descriptor_path="$1"
    _set_name_query=".[0].name = \"$YA_INSTALLER_RUNTIME_ID\"";
    jq "$_set_name_query" $_descriptor_path > "$_descriptor_path.tmp" && mv "$_descriptor_path.tmp" "$_descriptor_path";
    _add_extra_arg_query=".[0][\"extra-args\"] += [\"--runtime-arg=--pci-device=$YA_RUNTIME_VM_PCI_DEVICE\"]";
    jq "$_add_extra_arg_query" $_descriptor_path > "$_descriptor_path.tmp" && mv "$_descriptor_path.tmp" "$_descriptor_path";
}

configure_preset() {
    local _duration_price _cpu_price _preset_cmd

    _duration_price=$(echo "$YA_INSTALLER_GLM_PER_HOUR / 3600.0 / 5.0" | bc -l);
    _cpu_price=$(echo "$YA_INSTALLER_GLM_PER_HOUR / 3600.0" | bc -l);

    if [ $(preset_exists) == "true" ]; then
        _preset_cmd="update --name $YA_INSTALLER_RUNTIME_ID";
    else
        _preset_cmd="create --preset-name $YA_INSTALLER_RUNTIME_ID";
    fi

    ya-provider preset $_preset_cmd \
        --no-interactive \
        --exe-unit $YA_INSTALLER_RUNTIME_ID \
        --pricing linear \
        --price Duration=$_duration_price CPU=$_cpu_price "Init price"=$YA_INSTALLER_INIT_PRICE;
}

download_jq() {
    local _jq_version _bin _url
    _bin=$1

    version=$(jq --version 2>&1)
    if [[ $version == *"jq-1.6"* ]]; then
        return 0;
    fi;
    _jq_version="1.6"
    _url="https://github.com/jqlang/jq/releases/download/jq-$_jq_version/jq-linux64"
    _dl_start "jq" $_jq_version
    (downloader $_url $_bin/jq) || err "Failed to download $_url"
    _dl_end
    chmod +x $_bin/jq
}

# IOMMU ###############################################################################################################

get_iommu_groups()
{
    ls -v /sys/kernel/iommu_groups
}

test_iommu_enabled()
{
    count_iommu_groups=$(get_iommu_groups | wc -l)
    if [ $count_iommu_groups -gt 0 ]; then
        echo enabled
    else
        echo disabled
    fi
}

get_iommu_group_devices()
{
    ls /sys/kernel/iommu_groups/$iommu_group/devices
}

# PCI #################################################################################################################

get_pid_vid_from_slot()
{
    lspci -n -s $1 | awk -F" " '{print $3}'
}

get_pci_full_string_description_from_slot()
{
    lspci -s $1
}

get_pci_short_string_description_from_slot()
{
    get_pci_full_string_description_from_slot $1 | awk -F": " '{print $2}'
}

list_pci_devices_in_iommu_group()
{
    ret="IOMMU Group "$1
    ret="$ret\n##############"
    for device in $2; do
        ret="$ret\n$(get_pci_full_string_description_from_slot $device)"
    done;
    echo $ret
}

test_pci_slot_as_vga()
{
    lspci -d ::0300 -s $1
}

test_pci_slot_as_audio()
{
    lspci -d ::0403 -s $1
}

# vfio ################################################################################################################

get_gpu_list_as_menu()
{
    menu=""
    gpu_list_size=$(expr ${#gpu_list[@]} / 3)
    for ((i=0; i<$gpu_list_size; i++));    do
        if [ "$menu" == "" ]; then
            menu="$i%${gpu_list[$i,0]}"
        else
            menu="$menu%$i%${gpu_list[$i,0]}"
        fi
    done;
    echo $menu
}

select_gpu_compatible()
{
    least_one_gpu_compatible=0
    declare -A gpu_list
    gpu_count=0

    iommu_groups=$(get_iommu_groups);
    for iommu_group in $iommu_groups; do

        devices=$(get_iommu_group_devices)
        devices_count=$(echo $devices | wc -w)

        for device in $devices; do
            gpu_vga=$(test_pci_slot_as_vga $device)

            if [ ! -z "$gpu_vga" ]; then
                gpu_vga_slot=$(echo $gpu_vga | awk -F" " '{print $1}')

                if [ $devices_count -gt 2 ]; then
                    display_bad_isolation $iommu_group "$devices"
                elif [ $devices_count -eq 2 ]; then

                    second_device=$(echo $devices | awk -F" " '{print $2}')
                    gpu_audio=$(test_pci_slot_as_audio $second_device)

                    if [ ! -z "$gpu_audio" ]; then

                        least_one_gpu_compatible=1

                        gpu_audio_slot=$(echo $gpu_audio | awk -F" " '{print $1}')

                        gpu_vga_pid_vid=$(get_pid_vid_from_slot $gpu_vga_slot)
                        gpu_audio_pid_vid=$(get_pid_vid_from_slot $gpu_audio_slot)
                        vfio=$gpu_vga_pid_vid","$gpu_audio_pid_vid

                        gpu_list[$gpu_count,0]=$(get_pci_short_string_description_from_slot $gpu_vga)
                        gpu_list[$gpu_count,1]=$vfio
                        gpu_list[$gpu_count,2]=$gpu_vga_slot
                        ((gpu_count+=1))

                    else
                        display_bad_isolation $iommu_group "$devices"
                    fi
                else

                    least_one_gpu_compatible=1

                    gpu_vga_pid_vid=$(get_pid_vid_from_slot $gpu_vga_slot)
                    vfio=$gpu_vga_pid_vid

                    gpu_list[$gpu_count,0]=$(get_pci_short_string_description_from_slot $device)
                    gpu_list[$gpu_count,1]=$vfio
                    gpu_list[$gpu_count,2]=$gpu_vga_slot
                    ((gpu_count+=1))
                fi
            fi
        done;
    done;

    if [ $least_one_gpu_compatible -eq 0 ]; then
        dialog --stdout --title "Error" --msgbox "\nNo compatible GPU available." 6 50
        exit 1
    else
        menu=$(get_gpu_list_as_menu $gpu_list)
        IFS=$'%'
        gpu_index=$(dialog --stdout --menu "Select GPU to share" 0 0 0 $menu)
        unset IFS
        if [ "$gpu_index" == "" ]; then
            dialog --stdout --title "Cancel" --msgbox "\nInstallation canceled." 6 30
            exit 2
        else
            gpu_vfio=${gpu_list[$gpu_index,1]}
            gpu_slot=${gpu_list[$gpu_index,2]}
            echo "$gpu_vfio $gpu_slot"
        fi
    fi
}

# Tools ###############################################################################################################

_dl_head() {
    local _sep
    _sep="-----"
    _sep="$_sep$_sep$_sep$_sep"
    printf "%-20s %25s\n" " Component " " Version" >&2
    printf "%-20s %25s\n" "-----------" "$_sep" >&2
}

_dl_start() {
    printf "%-20s %25s " "$1" "$(version_name "$2")" >&2
}

_dl_end() {
    printf "[done]\n" >&2
}

detect_dist() {
    local _ostype _cputype

    _ostype="$(uname -s)"
    _cputype="$(uname -m)"

    if [ "$_ostype" = Darwin ]; then
        if [ "$_cputype" = i386 ]; then
            # Darwin `uname -m` lies
            if sysctl hw.optional.x86_64 | grep -q ': 1'; then
                _cputype=x86_64
            fi
        fi
        case "$_cputype" in arm64 | aarch64)
            _cputype=x86_64
            ;;
        esac
    fi


    case "$_cputype" in
        x86_64 | x86-64 | x64 | amd64)
            _cputype=x86_64
            ;;
        *)
            err "invalid cputype: $_cputype"
            ;;
    esac
    case "$_ostype" in
        Linux)
            _ostype=linux
            ;;
        Darwin)
            _ostype=osx
            ;;
        MINGW* | MSYS* | CYGWIN*)
            _ostype=windows
            ;;
        *)
            err "invalid os type: $_ostype"
    esac
    echo -n "$_ostype"
}

downloader() {
    local _dld
    if check_cmd curl; then
        _dld=curl
    elif check_cmd wget; then
        _dld=wget
    else
        _dld='curl or wget' # to be used in error message of need_cmd
    fi

    if [ "$1" = --check ]; then
        need_cmd "$_dld"
    elif [ "$_dld" = curl ]; then
        curl --proto '=https' --silent --show-error --fail --location "$1" --output "$2"
    elif [ "$_dld" = wget ]; then
        wget -O "$2" --https-only "$1"
    else
        err "Unknown downloader"   # should not reach here
    fi
}

version_name() {
    local name

    name=${1#pre-rel-}
    printf "%s" "${name#v}"
}

say() {
    printf 'golem-installer: %s\n' "$1"
}

err() {
    say "$1" >&2
    exit 1
}

need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

clear_exit() {
    clear;
    exit 1
}

display_error()
{
	dialog --title "$1" --msgbox "\n$2" $3 $4
	clear
	exit
}

display_bad_isolation()
{
	msg=$(list_pci_devices_in_iommu_group $1 "$2")
	dialog --stdout --title "GPU bad isolation" --msgbox "\n$msg\n\nTry changing your GPU PCIe slot." 13 130
}

compare_numeric_versions() {
    local _version_1 _version_2
    _version_1="$1"
    _version_2="$2"
    if (( _version_1 > _version_2 )); then
        return 0  # True (greater)
    elif (( _version_1 < _version_2 )); then
        return 1  # False (less)
    else
        return 2  # Equal
    fi
}

compare_semver() {
    local _version_1 _version_2
    _version_1="$1"
    _version_2="$2"

    local _major_1 _minor_1 _patch_1
    local _major_2 _minor_2 _patch_2
    _major_1=$(echo "$_version_1" | cut -d '.' -f 1)

    _major_2=$(echo "$_version_2" | cut -d '.' -f 1)

    compare_numeric_versions "$_major_1" "$_major_2"
    local major_result=$?
    if [ "$major_result" -eq 0 ]; then
        return 0 # (greater)
    elif [ "$major_result" -eq 1 ]; then
        return 1  # (less)
    fi

    _minor_1=$(echo "$_version_1" | cut -d '.' -f 2)
    _minor_2=$(echo "$_version_2" | cut -d '.' -f 2)

    compare_numeric_versions "$_minor_1" "$_minor_2"
    local minor_result=$?
    if [ "$minor_result" -eq 0 ]; then
        return 0 # (greater)
    elif [ "$minor_result" -eq 1 ]; then
        return 1 # (less)
    fi

    _patch_1=$(echo "$_version_1" | cut -d '.' -f 3)
    _patch_2=$(echo "$_version_2" | cut -d '.' -f 3)

    compare_numeric_versions "$_patch_1" "$_patch_2"
    local patch_result=$?
    if [ "$patch_result" -eq 0 ]; then
        return 0 # (greater)
    elif [ "$patch_result" -eq 1 ]; then
        return 1 # (less)
    fi

    local _rc_1 _rc_2
    _rc_1=""
    if [[ "$_version_1" =~ (.*)-(.*) ]]; then
        _version_1="${BASH_REMATCH[1]}"
        _rc_1="${BASH_REMATCH[2]}"
    fi

    _rc_2=""
    if [[ "$_version_2" =~ (.*)-(.*) ]]; then
        _version_2="${BASH_REMATCH[1]}"
        _rc_2="${BASH_REMATCH[2]}"
    fi

    if [ -n "$_rc_1" ] && [ -z "$_rc_2" ]; then
        return 0  # (greater)
    elif [ -z "$_rc_1" ] && [ -n "$_rc_2" ]; then
        return 1  # (less)
    elif [ -n "$_rc_1" ] && [ -n "$_rc_2" ]; then
        if [[ "$_rc_1" < "$_rc_2" ]]; then
            return 1 # (less)
        elif [[ "$_rc_1" > "$_rc_2" ]]; then
            return 0 # (greater)
        fi
    fi

    return 2 # (equal)
}

golem_version() {
    echo "$(ya-provider --version | cut -d ' ' -f 2)"
}

# Main ################################################################################################################

main() {
    need_cmd ya-provider
    need_cmd ya-provider
    need_cmd uname
    need_cmd chmod
    need_cmd mkdir
    need_cmd mv
    need_cmd bc

    local _os_type _download_dir _runtime_descriptor _bin _gpu _golem_version

    _golem_version=$(golem_version);
    if [ $(compare_semver $YA_MINIMAL_GOLEM_VERSION $_golem_version) == 0 ]; then
        dialog --stderr --title "Error" --msgbox "Unsupported Golem version $_golem_version.\nSupported $YA_MINIMAL_GOLEM_VERSION or later." 6 50
        clear_exit;
    fi

    # Check OS
    _os_type="$(detect_dist)"
    if [ "$_os_type" != "linux" ]; then
        dialog --stderr --title "Error" --msgbox "Incompatible OS: $_os_type" 6 50
        clear_exit;
    fi

    # Warning dialog
    dialog --stdout --title "Warning" \
    --backtitle "Experimental Feature" \
    --yesno "Yagna runtime with GPU support is an experimental feature.\n\nDo you want to continue?" 8 60
    warning_dialog_status=$?
    if [ "$warning_dialog_status" -eq 1 ]; then
        clear_exit;
    fi

    # Select GPU
    if [ "$YA_RUNTIME_VM_PCI_DEVICE" == "NULL" ]; then
        YA_RUNTIME_VM_PCI_DEVICE=$(select_gpu_compatible)
    fi
    
    # Init PATH
    _bin="$YA_INSTALLER_DATA/bin"
    test -d "$_bin" || mkdir -p "$_bin";
    export PATH=$_bin:$PATH
    
    download_jq $_bin

    # Download runtime
    _download_dir=$(download_vm_gpu "$_os_type") || exit 1

    # Install runtime
    _runtime_descriptor=$(install_vm_gpu "$_download_dir") || err "Failed to install $_runtime_descriptor"

    configure_runtime "$_runtime_descriptor"

    configure_preset
}

main "$@" || exit 1
