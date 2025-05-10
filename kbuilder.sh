#!/usr/bin/env bash
#
# Copyright (C) 2025~2026 UsiFX <xprjkts@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# Color definitions
BLUE='\e[1;34m'
CYAN='\e[1;36m'
RED='\e[1;31m'
YELLOW='\e[01;33m'
STOCK='\e[1;0m'

# Build configuration
BUILDER_VERSION=0.0.1
WORK_DIRECTORY=$(pwd)
DEFCONFIG=liquid-super_defconfig
ARCH="${ARCH:-}"  # Use ARCH from env if set, or empty

KBUILD_BUILD_HOST=kernelcompiler
KBUILD_BUILD_USER=liquid
KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

# Builder flags
CUSTOM_TC=""
DEFCONFIG_OVERRIDE=""
CLEAN_FLAG=false
USE_CCACHE=true

# Default toolchain flags
FLAGS=(
    LLVM=1
    LLVM_IAS=1
    CC=clang
    AR=llvm-ar
    LD=ld.lld
    NM=llvm-nm
    STRIP=llvm-strip
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    OBJSIZE=llvm-size
    HOSTCC=clang
    HOSTCXX=clang++
    HOSTAR=llvm-ar
    HOSTLD=ld.lld
)

printn() {
    case "$1" in
        "-n") printf "[${BLUE}*${STOCK}] %s\n" "$2" ;;
        "-e") 
            printf "[${RED}×${STOCK}] %s\n" "$2"
            exit 1
            ;;
        "-w") printf "[${YELLOW}!${STOCK}] %s\n" "$2" ;;
        "-i") printf "[${CYAN}i${STOCK}] %s\n" "$2" ;;
    esac
}

# Help function
__kbuild_help() {
    echo -e "
Usage: kbuilder [OPTION] (e.g. kbuilder build)

Commands:
 clean                  Clean work directory
 build                  Start kernel build process

Options:
 --no-ccache            Disable ccache validity and build without it
 --custom_tc=DIRECTORY  Use custom toolchain from specified directory
 --defconfig=FILENAME   Override default config file
 -v, --version          Show version information
 -h, --help             Show this help menu
"
}

check_kernel_source()
{
    # Check if we're in a likely Linux kernel source directory
    if ! [[ -f "Makefile" && -d "arch" && -d "scripts" && -f "Kconfig" ]]; then
        printn -e "This does not appear to be the Linux kernel source directory."
    fi
}

# Main script logic
if [[ $# -eq 0 ]]; then
    tty -s
    __kbuild_help
    exit 0
fi

for arg in "$@"; do
    case "${arg}" in
        "build") BUILD_FLAG=true ;;
        "--no-ccache") USE_CCACHE=false; printn -i "ccache explicitly disabled." ;;
        "--custom_tc="*) CUSTOM_TC="${arg#--custom_tc=}" ;;
        "--defconfig="*) DEFCONFIG_OVERRIDE="${arg#--defconfig=}" ;;
        "clean")
            CLEAN_FLAG=true
            printn -i "Cleaning build directory..."
        ;;
        "-v" | "--version")
            echo -e "Kernel Builder v${BUILDER_VERSION}
Copyright (C) 2025-2026 UsiFX <xprjkts@gmail.com>

License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law."
        ;;    
        *"?"* | "h"* | "-h" | "--help") __kbuild_help ;;
        *) 
            printn -e "Unknown option: $arg, try '--help'." ;;
    esac
done

# Handle clean first, then build if requested
if [[ $CLEAN_FLAG == true ]]; then
    make mrproper
fi

# Handle build if requested
if [[ $BUILD_FLAG == true ]]; then
    check_kernel_source

    printn -i "Starting kernel build process..."
    export KBUILD_BUILD_HOST KBUILD_BUILD_TIMESTAMP KBUILD_BUILD_USER

    # Apply custom toolchain if provided
    if [[ -n "$CUSTOM_TC" ]]; then
        printn -i "Using custom toolchain from $CUSTOM_TC"

        # Update toolchain variables with custom toolchain path
        FLAGS=(
            "LLVM=1"
            "LLVM_IAS=1"
            "CC=${CUSTOM_TC}/clang"
            "AR=${CUSTOM_TC}/llvm-ar"
            "LD=${CUSTOM_TC}/ld.lld"
            "NM=${CUSTOM_TC}/llvm-nm"
            "STRIP=${CUSTOM_TC}/llvm-strip"
            "OBJCOPY=${CUSTOM_TC}/llvm-objcopy"
            "OBJDUMP=${CUSTOM_TC}/llvm-objdump"
            "OBJSIZE=${CUSTOM_TC}/llvm-size"
            "HOSTCC=${CUSTOM_TC}/clang"
            "HOSTCXX=${CUSTOM_TC}/clang++"
            "HOSTAR=${CUSTOM_TC}/llvm-ar"
            "HOSTLD=${CUSTOM_TC}/ld.lld"
        )

        # Verify toolchain components
        for flag_availability in "${FLAGS[@]}"; do
            var_name="${flag_availability%%=*}"
            var_value="${flag_availability#*=}"
            if [[ -f "$var_value" ]]; then
                printn -i "$var_name: $var_value exists."
            else
                printn -e "$var_name: $var_value does not exist or is not a valid file."
            fi
        done
    else
        printn -i "Using default toolchain"
    fi

    # Apply defconfig override if provided
    if [[ -n "$DEFCONFIG_OVERRIDE" ]]; then
        DEFCONFIG="$DEFCONFIG_OVERRIDE"

        # Try to detect ARCH from path if not manually set
        if [[ -z "$ARCH" ]]; then
            DEFCONFIG_PATH=$(find "${WORK_DIRECTORY}/arch/" -path "*/configs/${DEFCONFIG}" 2>/dev/null | head -n 1)
            if [[ -n "$DEFCONFIG_PATH" ]]; then
                ARCH=$(echo "$DEFCONFIG_PATH" | awk -F'/' '{print $(NF-2)}')
                printn -i "Using ARCH=$ARCH of ${DEFCONFIG}."
            else
                printn -w "Could not detect ARCH from ${DEFCONFIG}. Using default: x86"
                ARCH="x86"
            fi
        else
            printn -i "Using manually specified ARCH=$ARCH"
        fi
    else
        if [[ -z "$ARCH" ]]; then
            ARCH="x86"  # default fallback
            printn -i "No defconfig or ARCH specified. Defaulting to ARCH=$ARCH"
        fi
    fi

    # Build kernel
    if [[ "$USE_CCACHE" == true ]] && command -v ccache &>/dev/null; then
        export CCACHE_CPP2=yes
        ccache --max-size=10G
        ccache --set-config compression=true
        for flag in "${!FLAGS[@]}"; do
            case "$flag" in
                CC=clang)           new_flags+="CC=ccache clang" ;;
                HOSTCC=clang)       new_flags+="HOSTCC=ccache clang" ;;
                HOSTCXX=clang++)    new_flags+="HOSTCXX=ccache clang++" ;;
                *)                  new_flags+=("$flags");;
            esac
        done
        FLAGS=("${new_flags[@]}")
        PATH="/usr/lib/ccache/bin:${PATH}" make "${DEFCONFIG}" all -j"$(nproc --all --ignore=2)" "${FLAGS[@]}"
    else
        make "${DEFCONFIG}" all -j"$(nproc --all --ignore=2)" "${FLAGS[@]}"
    fi
fi