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
GREEN='\e[1;32m'
PURPLE='\e[1;35m'
CYAN='\e[1;36m'
RED='\e[1;31m'
WHITE='\e[1;37m'
YELLOW='\e[01;33m'
STOCK='\e[1;0m'

# Build configuration
BUILDER_VERSION=0.0.1
WORK_DIRECTORY=$(pwd)
DEFCONFIG=liquid-super_defconfig
KBUILD_BUILD_HOST=kernelcompiler
KBUILD_BUILD_USER=liquid
KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

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

# Print functions
printn() {
    case "$1" in
        "-n") printf "[${BLUE}*${STOCK}] $2\n" ;;
        "-e") 
            printf "[${RED}×${STOCK}] $2\n"
            exit 1
            ;;
        "-w") printf "[${YELLOW}!${STOCK}] $2\n" ;;
        "-i") printf "[${CYAN}i${STOCK}] $2\n" ;;
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
 --custom_tc=DIRECTORY  Use custom toolchain from specified directory
 --defconfig=FILENAME   Override default config file
 -v, --version          Show version information
 -h, --help             Show this help menu
"
}

# Check if we're in a likely Linux kernel source directory
if ! [[ -f "Makefile" && -d "arch" && -d "scripts" && -f "Kconfig" ]]; then
    printn -e "This does not appear to be the Linux kernel source directory."
fi

# Main script logic
if [[ $# -eq 0 ]]; then
    tty -s
    __kbuild_help
    exit 0
fi

for arg in "$@"; do
    case "${arg}" in
        "clean")
            if [[ "$*" == "clean" ]]; then
                make mrproper
            else
                printn -e "clean should be the first argument!"
            fi
        ;;  
        "--custom_tc="*)
            customtc_path="${arg#--custom_tc=}"
            if [[ "${customtc_path}" == *bin* ]]; then
                FLAGS=(
                    LLVM=1
                    LLVM_IAS=1
                    CC=${customtc_path}/clang
                    AR=${customtc_path}/llvm-ar
                    LD=${customtc_path}/ld.lld
                    NM=${customtc_path}/llvm-nm
                    STRIP=${customtc_path}/llvm-strip
                    OBJCOPY=${customtc_path}/llvm-objcopy
                    OBJDUMP=${customtc_path}/llvm-objdump
                    OBJSIZE=${customtc_path}/llvm-size
                    HOSTCC=${customtc_path}/clang
                    HOSTCXX=${customtc_path}/clang++
                    HOSTAR=${customtc_path}/llvm-ar
                    HOSTLD=${customtc_path}/ld.lld
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
        ;;    
        "--defconfig="*)
            # Auto-detect ARCH from defconfig path if ARCH is not specified
            DEFCONFIG="${arg#--defconfig=}"

            DEFCONFIG_PATH=$(find "${WORK_DIRECTORY}/arch/" -path "*/configs/${DEFCONFIG}" | head -n 1)

            # If a specific ARCH is passed as an argument use it
            if [[ -n "$ARCH" ]]; then
                printn -i "Using manually specified ARCH=$ARCH"
            else
                if [[ -n "${DEFCONFIG_PATH}" ]]; then
                    ARCH=$(echo "$DEFCONFIG_PATH" | awk -F'/' '{print $(NF-2)}')
                    printn -i "Detected ARCH=$ARCH from defconfig ($DEFCONFIG)"
                else
                    printn -e "Config file not found: ${DEFCONFIG}"
                fi
            fi

            # Continue with the rest of the logic (e.g., using ARCH)
            printn -i "Using ARCH=$ARCH for further configuration"
        ;;
    
        "build")
            if [[ "${!#}" == "build" ]]; then
                if [[ ${ARCH} == "arm64" ]]; then
                    CROSS_COMPILE=aarch64-linux-gnu-
                elif [[ ${ARCH} == "arm" ]]; then
                    CROSS_COMPILE=arm-linux-gnueabi-
                fi

                # Full build
                if command -v ccache &> /dev/null; then
                    # Let clang preprocess the code
                    export CCACHE_CPP2=yes

                    # Wrap toolchain with ccache in array listing
                    for i in "${!FLAGS[@]}"; do
                        case "${FLAGS[$i]}" in
                            CC=clang) FLAGS[$i]="CC=ccache clang" ;;
                            HOSTCC=clang) FLAGS[$i]="HOSTCC=ccache clang" ;;
                            HOSTCXX=clang++) FLAGS[$i]="HOSTCXX=ccache clang++" ;;
                        esac
                    done
                    PATH="/usr/lib/ccache/bin:${PATH}" make "${DEFCONFIG}" all -j$(nproc --all --ignore=2) "${FLAGS[@]}"
                else
                    make "${DEFCONFIG}" all -j$(nproc --all --ignore=2) "${FLAGS[@]}"
                fi
            else
                printn -e "build should be the last argument!"
            fi
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
