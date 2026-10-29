#!/bin/bash

# Clear Screen
tput reset 2>/dev/null || clear

# Colours (or Colors in en_US)
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
NORMAL='\033[0m'

# Abort Function
function abort(){
    [ ! -z "$@" ] && echo -e ${RED}"${@}"${NORMAL}
    exit 1
}

# Banner
function __bannerTop() {
	echo -e \
	${GREEN}"
	██████╗░██╗░░░██╗███╗░░░███╗██████╗░██████╗░██╗░░██╗
	██╔══██╗██║░░░██║████╗░████║██╔══██╗██╔══██╗╚██╗██╔╝
	██║░░██║██║░░░██║██╔████╔██║██████╔╝██████╔╝░╚███╔╝░
	██║░░██║██║░░░██║██║╚██╔╝██║██╔═══╝░██╔══██╗░██╔██╗░
	██████╔╝╚██████╔╝██║░╚═╝░██║██║░░░░░██║░░██║██╔╝╚██╗
	╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝╚═╝░░░░░╚═╝░░╚═╝╚═╝░░╚═╝
	"${NORMAL}
}

# Welcome Banner
printf "\e[32m" && __bannerTop && printf "\e[0m"

# Minor Sleep
sleep 1

# Package Helpers
# Package names drift between distro releases (Ubuntu 26.04 dropped 'p7zip-full',
# 'p7zip-rar' and 'liblz4-tool'), so a hardcoded list aborts the whole setup.
# Resolve every requirement against what this system's package database provides.

# Success when the package has a real installable candidate.
function pkg_known() {
    case "${PKG_MANAGER}" in
        apt)     apt-cache madison "$1" 2> /dev/null | grep -q . ;;
        dnf)     dnf info -q "$1" > /dev/null 2>&1 ;;
        pacman)  pacman -Si "$1" > /dev/null 2>&1 ;;
        brew)    brew info "$1" > /dev/null 2>&1 ;;
        *)       return 1 ;;
    esac
}

# Add the first name in the list this system knows about.
function pkg_add() {
    local candidate
    for candidate in "$@"; do
        if pkg_known "${candidate}"; then
            INSTALL_PKGS+=("${candidate}")
            return 0
        fi
    done
    SKIPPED_PKGS+=("$1")
    return 0
}

INSTALL_PKGS=()
SKIPPED_PKGS=()

if [[ "$OSTYPE" == "linux-gnu" ]]; then

    if command -v apt-get > /dev/null 2>&1; then

        PKG_MANAGER=apt

        DISTRO_NAME="Ubuntu/Debian Based Distro"
        if [[ -r /etc/os-release ]]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            DISTRO_NAME="${PRETTY_NAME:-${DISTRO_NAME}}"
        fi

        echo -e ${PURPLE}"${DISTRO_NAME} Detected"${NORMAL}
        sleep 1

        echo -e ${BLUE}">> Updating apt repos..."${NORMAL}
        sleep 1
        sudo apt-get -y update || abort "Setup Failed!"

        sleep 1
        echo -e ${BLUE}">> Resolving packages for this release..."${NORMAL}
        for p in unace unrar zip unzip sharutils rar uudeview mpack arj \
                 cabextract device-tree-compiler liblzma-dev brotli axel \
                 gawk aria2 detox cpio rename liblz4-dev jq git-lfs \
                 file curl xz-utils; do
            pkg_add "${p}"
        done

        # '7zip' replaces the removed 'p7zip-full' (dropped after 24.04) and
        # ships the '7z'/'7za' binaries plus the codec plugin loader.
        # The RAR codec comes from '7zip-rar' (previously 'p7zip-rar').
        # NOTE: do not add '7zip-standalone' - it installs a '7zz' into PATH that
        # shadows utils/bin/7zz and has no RAR codec, which dumper.sh relies on.
        pkg_add 7zip p7zip-full
        pkg_add 7zip-rar p7zip-rar

        # 'liblz4-tool' was merged into 'lz4'; both names are tried so older
        # releases keep working.
        pkg_add lz4 liblz4-tool

        if [[ ${#SKIPPED_PKGS[@]} -gt 0 ]]; then
            sleep 1
            echo -e ${PURPLE}">> Not available on this release, skipping: ${SKIPPED_PKGS[*]}"${NORMAL}
        fi

        sleep 1
        echo -e ${BLUE}">> Installing Required Packages..."${NORMAL}
        sleep 1
        if [[ ${#INSTALL_PKGS[@]} -gt 0 ]]; then
            sudo apt-get install -y "${INSTALL_PKGS[@]}" || abort "Setup Failed!"
        fi

    elif command -v dnf > /dev/null 2>&1; then

        PKG_MANAGER=dnf

        echo -e ${PURPLE}"Fedora Based Distro Detected"${NORMAL}
        sleep 1

        # "dnf" automatically updates repos before installing packages
        for p in unace unrar zip unzip sharutils uudeview arj cabextract \
                 file-roller dtc brotli axel aria2 detox cpio lz4 xz-devel \
                 p7zip p7zip-plugins git-lfs jq file curl xz; do
            pkg_add "${p}"
        done

        if [[ ${#SKIPPED_PKGS[@]} -gt 0 ]]; then
            sleep 1
            echo -e ${PURPLE}">> Not available on this release, skipping: ${SKIPPED_PKGS[*]}"${NORMAL}
        fi

        sleep 1
        echo -e ${BLUE}">> Installing Required Packages..."${NORMAL}
        sleep 1
        if [[ ${#INSTALL_PKGS[@]} -gt 0 ]]; then
            sudo dnf install -y "${INSTALL_PKGS[@]}" || abort "Setup Failed!"
        fi

    elif command -v pacman > /dev/null 2>&1; then

        PKG_MANAGER=pacman

        echo -e ${PURPLE}"Arch or Arch Based Distro Detected"${NORMAL}
        sleep 1

        for p in unace unrar p7zip sharutils uudeview arj cabextract \
                 file-roller dtc brotli axel gawk aria2 detox cpio lz4 jq \
                 git-lfs file curl xz; do
            pkg_add "${p}"
        done

        sleep 1
        echo -e ${BLUE}">> Updating package database..."${NORMAL}
        sleep 1
        sudo pacman -Syyu --needed --noconfirm > /dev/null || abort "Setup Failed!"

        if [[ ${#SKIPPED_PKGS[@]} -gt 0 ]]; then
            sleep 1
            echo -e ${PURPLE}">> Not available on this release, skipping: ${SKIPPED_PKGS[*]}"${NORMAL}
        fi

        sleep 1
        echo -e ${BLUE}">> Installing Required Packages..."${NORMAL}
        sleep 1
        if [[ ${#INSTALL_PKGS[@]} -gt 0 ]]; then
            sudo pacman -Sy --needed --noconfirm "${INSTALL_PKGS[@]}" || abort "Setup Failed!"
        fi

    fi

elif [[ "$OSTYPE" == "darwin"* ]]; then

    PKG_MANAGER=brew

    echo -e ${PURPLE}"macOS Detected"${NORMAL}
    sleep 1

    for p in protobuf xz brotli lz4 aria2 detox coreutils p7zip gawk git-lfs jq; do
        pkg_add "${p}"
    done

    if [[ ${#SKIPPED_PKGS[@]} -gt 0 ]]; then
        sleep 1
        echo -e ${PURPLE}">> Not available on this release, skipping: ${SKIPPED_PKGS[*]}"${NORMAL}
    fi

    sleep 1
    echo -e ${BLUE}">> Installing Required Packages..."${NORMAL}
    sleep 1
    if [[ ${#INSTALL_PKGS[@]} -gt 0 ]]; then
        brew install "${INSTALL_PKGS[@]}" || abort "Setup Failed!"
    fi

fi

sleep 1

# Install `uv`
if ! command -v uv > /dev/null ; then
    echo -e ${BLUE}">> Installing uv for python packages..."${NORMAL}
    sleep 1
    bash -c "$(curl -sL https://astral.sh/uv/install.sh)" || abort "Setup Failed!"
fi

# Done!
echo -e ${GREEN}"Setup Complete!"${NORMAL}

# Exit
exit 0

