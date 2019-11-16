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
# This is the "full" provisioner, which does everything the "lite" provisioner does, but
# with more packages.
#
# Usage:
#
#    # With curl
#    curl -fsS https://cdn.privex.io/github/someguy-scripts/dist/full.sh | bash
#    # With wget
#    wget -q https://cdn.privex.io/github/someguy-scripts/dist/full.sh -O - | bash
#
# Using with a local someguy-scripts folder:
#
#     $ cd /whatever/someguy-scripts
#     $ export SKIP_CLONE='y' LIB_DIR="$PWD"
#     $ ./scripts/full.sh
#
# Environmental variables:
#
#   LIB_DIR          - Default: /tmp/??  Set this environment variable if you want to change where it clones Someguy123/someguy-scripts to.
#   SKIP_LOCALE      - Default: 'n'      Set to 'y' to disable locale configuration and generation
#   SKIP_INSTALL     - Default: 'n'      Set to 'y' to disable automatically installing the packages listed in INSTALL_PKGS
#   SKIP_GLOBAL      - Default: 'n'      Set to 'y' to disable installing config files / zsh files globally
#   SKIP_HARDEN      - Default: 'n'      Set to 'y' to disable server hardening (e.g. disable pass auth / change ssh port)
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


IS_FRESH='y'   # We set IS_FRESH to true to skip any prompts requiring user input.


sgs_provision


