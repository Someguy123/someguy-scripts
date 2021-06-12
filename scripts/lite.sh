#!/usr/bin/env bash
################################
#                              #
#  Someguy's Linux Provisioner #
#        by @someguy123        #
#     github.com/@someguy123   #
#                              #
#          GNU AGPLv3          #
#                              #
################################
# ------------------------------
#
# Auto provisioner for Someguy-Scripts on Debian based systems
# This is the "lite" provisioner, which only corrects locale issues, installs "essential" 
# utilities, installs global configuration files, and changes the shell for both "ubuntu" 
# and "root" to /usr/bin/zsh (assuming it exists).
#
# Usage:
#
#    # With curl
#    curl -fsS https://cdn.privex.io/github/someguy-scripts/dist/lite.sh | bash
#    # With wget
#    wget -q https://cdn.privex.io/github/someguy-scripts/dist/lite.sh -O - | bash
#
# Using with a local someguy-scripts folder:
#
#     $ cd /whatever/someguy-scripts
#     $ export SKIP_CLONE='y' LIB_DIR="$PWD"
#     $ ./scripts/lite.sh
#
# Environmental variables:
#
#   LIB_DIR          - Default: /tmp/??  Set this environment variable if you want to change where it clones Someguy123/someguy-scripts to.
#   SKIP_LOCALE      - Default: 'n'      Set to 'y' to disable locale configuration and generation
#   SKIP_INSTALL     - Default: 'n'      Set to 'y' to disable automatically installing the packages listed in INSTALL_PKGS
#   SKIP_GLOBAL      - Default: 'n'      Set to 'y' to disable installing config files / zsh files globally
#   SKIP_HARDEN      - Default: 'y'      Set to 'y' to disable server hardening (e.g. disable pass auth / change ssh port)
#   SKIP_CLONE       - Default: 'n'      Set to 'y' to disable automatic cloning of someguy-scripts into LIB_DIR 
#                                        (If SKIP_CLONE='y', make sure to set LIB_DIR to point to a local copy of someguy-scripts)
#
# ------------------------------

_LN="\n==========================================================================\n"

echo -e "\n${_LN}"

echo " ############################################################"
echo " ###                                                      ###"
echo " ###   Someguy Scripts - (C) 2019 github.com/Someguy123   ###"
echo " ###   Released as open source under the GNU AGPL v3      ###"
echo " ###                                                      ###"
echo " ############################################################"
echo -e "${_LN}"
sleep 1

SGLITE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

: ${SKIP_HARDEN='y'}         # Do not run server hardening


[ ! -z ${SGBASE_LOADED+x} ] || source "${SGLITE_DIR}/base.sh" || { &2> echo "!!! ERROR !!! Could not load base.sh. Cannot continue."; exit 1; }

sg_copyright

##############################
# --- NOTE About Packages ---
# 
# As this is the "lite" auto installer, some sacrifices were made to reduce dependencies.
#
#  - iptables-persistent is not included as it generally just has a lot of library dependencies
#  - fail2ban is not included as it has a lot of dependencies, including python3
#  - command-not-found is not included as it has a lot of dependencies, including python3
#  - Various other packages may not be present compared to the standard install.
#
if [ -z ${INSTALL_PKGS+x} ]; then 
    msg cyan " >>> Using default lite.sh INSTALL_PKGS as wasn't set in environment."
    INSTALL_PKGS=(
        # General
        git curl wget pv bash-completion
        # Session management
        tmux screen
        # Network tools
        mtr-tiny iputils-ping netcat dnsutils net-tools
        # Development
        vim nano zsh
        # Server stats
        htop
        # Compression/Decompression
        zip unzip xz-utils liblz4-tool lbzip2 pigz p7zip lzip
        # Other
        thin-provisioning-tools
    )
else
    msg cyan " >>> Using custom INSTALL_PKGS which was set in environment..."
    msg cyan " >>> Content of INSTALL_PKGS: ${INSTALL_PKGS[@]}\n"
fi


IS_FRESH='y'   # We set IS_FRESH to true to skip any prompts requiring user input.


sgs_provision


