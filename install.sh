#!/bin/bash
# shellcheck shell=bash

set -u

YA_INSTALLER_RUNTIME_VER=${YA_INSTALLER_RUNTIME_VER:__TAG_NAME__}
YA_INSTALLER_RUNTIME_NAME="ya-runtime-vm-nvidia"
YA_INSTALLER_RUNTIME_ID="vm-nvidia"
YA_INSTALLER_RUNTIME_DESCRIPTOR="ya-runtime-vm-nvidia.json"

PCI_DEVICE=${PCI_DEVICE:-NULL}

GLM_PER_HOUR=${GLM_PER_HOUR:-0.025}
INIT_PRICE=${INIT_PRICE:-0}

YA_INSTALLER_DATA=${YA_INSTALLER_DATA:-$HOME/.local/share/ya-installer}
YA_INSTALLER_LIB=${YA_INSTALLER_LIB:-$HOME/.local/lib/yagna}

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

download_vm_gpu() {
    local _ostype _url

    _ostype="$1"
    test -d "$YA_INSTALLER_DATA/bundles" || mkdir -p "$YA_INSTALLER_DATA/bundles"

    _url="https://github.com/golemfactory/${YA_INSTALLER_RUNTIME_NAME}/releases/download/${YA_INSTALLER_RUNTIME_VER}/${YA_INSTALLER_RUNTIME_NAME}-${_ostype}-${YA_INSTALLER_RUNTIME_VER}.tar.gz"
    # _dl_start "vm runtime" "$YA_INSTALLER_RUNTIME_VER"
    # (downloader "$_url" - | tar -C "$YA_INSTALLER_DATA/bundles" -xz -f -) || err "failed to download $_url"
    # _dl_end
    echo -n "$YA_INSTALLER_DATA/bundles/${YA_INSTALLER_RUNTIME_NAME}-${_ostype}-${YA_INSTALLER_RUNTIME_VER}"
}

# Copies Runtime to plugins dir.
# Returns path to Runtime desccriptor.
install_vm_gpu() {
    local _src _plugins_dir

    _src="$1"
    _plugins_dir="$YA_INSTALLER_LIB/plugins"
    mkdir -p "$_plugins_dir"

    cd "$_plugins_dir"

    if [ $(runtime_exists) == "true" ]; then
        echo "Runtime with name \"$YA_INSTALLER_RUNTIME_ID\" already exists. Aborting.";
        exit 1;
    fi
    # TODO also check file names against name collision
    
    cp -r "$_src"/* "$_plugins_dir/"

    echo -n "$_plugins_dir/$YA_INSTALLER_RUNTIME_DESCRIPTOR";
}

runtime_exists() {
    provider_entry_exists "exe-unit"
}

preset_exists() {
    provider_entry_exists "preset"
}

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
    _add_extra_arg_query=".[0][\"extra-args\"] += [\"--runtime-arg=--pci-device=$PCI_DEVICE\"]";
    jq "$_add_extra_arg_query" $_descriptor_path > "$_descriptor_path.tmp" && mv "$_descriptor_path.tmp" "$_descriptor_path";
}

configure_preset() {
    local _duration_price _cpu_price _preset_cmd

    _duration_price=$(echo "$GLM_PER_HOUR / 3600.0 / 5.0" | bc -l);
    _cpu_price=$(echo "$GLM_PER_HOUR / 3600.0" | bc -l);

    if [ $(preset_exists) == "true" ]; then
        _preset_cmd="update --name $YA_INSTALLER_RUNTIME_ID";
    else
        _preset_cmd="create --preset-name $YA_INSTALLER_RUNTIME_ID";
    fi

    ya-provider preset $_preset_cmd \
        --no-interactive \
        --exe-unit $YA_INSTALLER_RUNTIME_ID \
        --pricing linear \
        --price Duration=$_duration_price CPU=$_cpu_price "Init price"=$INIT_PRICE;
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

main() {
    need_cmd ya-provider
    need_cmd uname
    need_cmd chmod
    need_cmd mkdir
    need_cmd mv
    need_cmd bc

    local _os_type _download_dir _runtime_descriptor _bin

    # Check OS
    _os_type="$(detect_dist)"
    if [ "$_os_type" != "linux" ]; then
        dialog --stdout --title "Error" --msgbox "\nIncompatible OS: $_os_type" 6 50
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
