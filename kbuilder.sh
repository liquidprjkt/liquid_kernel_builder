#!/usr/bin/env bash
#
# Copyright (C) 2025~2026 UsiFX <xprjkts@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License
#
# This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#

# \e colors
BLUE='\e[1;34m'
GREEN='\e[1;32m'
PURPLE='\e[1;35m'
CYAN='\e[1;36m'
RED='\e[1;31m'
WHITE='\e[1;37m'
YELLOW='\e[01;33m'
STOCK='\e[1;0m'

BUILDER_VERSION=0.0.1

export WORK_DIRECTORY=$(pwd)
export DEFCONFIG=liquid-super_defconfig
export ARCH=x86
export KBUILD_BUILD_HOST=kernelcompiler
export KBUILD_BUILD_USER=liquid
export KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

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


# printn <argument> text
printn() {
	[[ "$1" == "-n" ]] && printf "[${BLUE}*${STOCK}] $2\n"

	[[ "$1" == "-e" ]] && {
		printf "[${RED}×${STOCK}] $2\n"
		exit 1
	}

	[[ "$1" == "-w" ]] && printf "[${YELLOW}!${STOCK}] $2\n"

	[[ "$1" == "-i" ]] && printf "[${CYAN}i${STOCK}] $2\n"
}

__kbuild_help() {
	echo "
Usage: kbuilder [OPTION] (e.g. kbuilder build)

Commands:
 clean                  cleans work directory
 build                  starts make in work directory

Options:
 --custom_tc=DIRECTORY  changes default toolchain to custom one
 --defconfig=FILENAME   overwrite default config file
 -v, --version          prints license and version
 -h, --help             shows this help menu
"
}

if [[ $# -eq "0" ]]; then
	tty -s
    __kbuild_help
else
    for arg in "$@"
    do
            case "${arg}" in
            "clean")
                if [ "clean" == "$*" ]; then
                    make mrproper
                else
                    printn -e "clean should be the first supply, hanging!"
                fi
            ;;
            "--custom_tc="*)
                customtc_path="${arg#--custom_tc=}"
                if [ ${customtc_path} == *bin* ]; then
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
                    printn -i "using default toolchain"
                fi
            ;;
            "--defconfig="*)
                DEFCONFIG="${arg#--defconfig=}"
                if [ -f ${WORK_DIRECTORY}/arch/$ARCH/configs/${DEFCONFIG} ]; then
                    printn -i "using $DEFCONFIG as default config"
                else
                    printn -e "please check for correct config!, hanging."
                fi
            ;;
            "build")
                if [[ "${!#}" == "build" ]]; then
                    make ${FLAGS[@]} ${DEFCONFIG}

                    if ! command -v ccache &> /dev/null; then
                        make ${DEFCONFIG} all -j$(nproc --all) ${FLAGS[@]}
                    else
                        PATH="/usr/lib/ccache/bin:${PATH}" make ${DEFCONFIG} all -j$(nproc --all) ${FLAGS[@]}
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
There is NO WARRANTY, to the extent permitted by law.."
            ;;
            *"?"* | "h"* | "-h" | "--help") __kbuild_help ;;
            *) printn -e "unknown option $*, try '--help'." ;;
            esac
    done
fi