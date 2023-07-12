#!/bin/bash
# shellcheck shell=bash

set -u

YA_INSTALLER_GPU_VER=${YA_INSTALLER_GPU_VER:-pre-rel-v0.1.0-rc23}
YA_INSTALLER_DATA=${YA_INSTALLER_DATA:-$HOME/.local/share/ya-installer}
YA_INSTALLER_LIB=${YA_INSTALLER_LIB:-$HOME/.local/lib/yagna}
YA_INSTALLER_GPU_NAME=${YA_INSTALLER_GPU_NAME:ya-runtime-vm-nvidia}

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

    _url="https://github.com/golemfactory/${YA_INSTALLER_GPU_NAME}/releases/download/${YA_INSTALLER_GPU_VER}/${YA_INSTALLER_GPU_NAME}-${_ostype}-${YA_INSTALLER_GPU_VER}.tar.gz"
    _dl_start "vm runtime" "$YA_INSTALLER_GPU_VER"
    (downloader "$_url" - | tar -C "$YA_INSTALLER_DATA/bundles" -xz -f -) || err "failed to download $_url"
    _dl_end
    echo -n "$YA_INSTALLER_DATA/bundles/${YA_INSTALLER_GPU_NAME}-${_ostype}-${YA_INSTALLER_GPU_VER}"
}

version_name() {
	local name

	name=${1#pre-rel-}
	printf "%s" "${name#v}"
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

clear_exit() {
    clear;
    exit 1
}

##############

local _os_type

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

# Download runtime

echo "WIP"
