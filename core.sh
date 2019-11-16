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
# Features:
# - Interactive menu
# - Installs a wide range of packages from an easily editable array
# - Can list packages from the menu before installing
# - Installs zsh + oh-my-zsh, plus various helper zsh scripts
# - Changes default shell to zsh
# - Installs dotfiles for tmux, vimrc, and zshrc (warns before overwriting)
# - Can harden install (disables password auth, randomizes SSH port)
# ------------------------------

# Detect the PWD of this file, so we can appropriately find 
# the files needed, regardless of where it was ran from.
_CORE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load lib.sh which contains all of the functions and some initialisation code
. "${_CORE_DIR}/lib.sh"

# Remove any lines containing 'source xxxx.sh'
remove_sources() { sed -E "s/.*source \".*\.sh\".*//g" "$@"; }

# Compress instances of more than one blank line into a singular blank line
# Unlike "tr -s '\n'" this will only compact multiple blank lines into one, instead of
# removing blank lines entirely.
compress_newlines() { cat -s; }

# Remove any comments starting with '#'
remove_comments() { sed -E "s/^#.*//g" "$@" | sed -E "s/^[[:space:]]+#.*//g"; }

# Trim away any /usr/bin/* or /bin/* shebangs - either pipe in data, or pass filename as argument
remove_shebangs() { sed -E "s;^#!/usr/bin.*$;;" "$@" | sed -E "s;^#!/bin.*$;;"; }



############
# By default, _sgs_compile includes both the compiled version of Privex ShellCore,
# plus scripts/base.sh
# Anything else you want to include, should be specified on the command line.
# 
# Usage:
#
#    # Compile ShellCore, scripts/base.sh, scripts/my_helpers.sh, and scripts/lite.sh
#    # then output the compiled script to stdout.
#    $ _sgs_compile scripts/my_helpers.sh scripts/lite.sh
#
#    # By specifying 'output' before a file path, the function will output the compiled
#    # script to dist/lite.sh instead of stdout.
#    $ _sgs_compile scripts/lite.sh output dist/lite.sh
#
_sgs_compile() {
    local _PWD="$PWD"
    _CORE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    # msgerr "Unsetting variables..."
    unset SRCED_COLORS &>/dev/null || true
    unset SRCED_IDENT_SH &>/dev/null || true
    unset SRCED_010HLP &>/dev/null || true
    export SG_DIR="${_CORE_DIR}/scripts/shell-core"
    local use_file=0 out_file has_midfiles=0 midfiles=()

    # msgerr "Parsing arguments..."
    while (($#>0)); do
        if [[ "$1" == "output" ]]; then
            shift
            use_file=1 && out_file="$1"
            msgerr green " [+] Outputting compiled file to '$out_file'"
            shift
            continue
        fi
        msgerr green " [+] Adding file '$1' to middle files for compilation"
        midfiles+=("$1")
        has_midfiles=1
        shift
    done
    # msgerr "Making temp file..."

    (($use_file==1)) || out_file="$(mktemp)"

    local _out_dir=$(dirname $out_file)
    [[ "$_out_dir" == '.' ]] && out_file="${_PWD}/${out_file}" || { 
        [[ ! -d "$_out_dir" ]] && out_file="${_PWD}/${out_file}" && >&2 mkdir -pv "$(dirname "${_PWD}/${out_file}")"
    }

    : ${SHEBANG_LINE='#!/usr/bin/env bash'}

    # msgerr "Making copyright..."

    __CMP_NOW=$(date)        
    local _ver="$SG_SCRIPTS_VERSION"
    _sgs_copyright="############################################################
###                                                      ###
###   Someguy Scripts - (C) 2019 github.com/Someguy123   ###
###   Released as open source under the GNU AGPL v3      ###
###                  Someguy Scripts Version: $_ver      ###
###                                                      ###
###       github.com/Someguy123/someguy-scripts          ###
###                                                      ###
### This minified script was compiled at:                ###
### $__CMP_NOW                         ###
###                                                      ###
############################################################
"

    # msgerr "Entering folder: $SG_DIR"

    cd "$SG_DIR"

    {
        msg "$SHEBANG_LINE"
        echo -n "$_sgs_copyright"
        # msgerr "Compiling ShellCore..."
        # Trim away any /usr/bin/* or /bin/* shebangs from the ShellCore compilation
        ./run.sh compile | remove_shebangs | compress_newlines
        # msgerr "Compiled."
        msg "$_sgs_copyright"
        msg "\n### --------------------------------------"
        msg "### Someguy123/someguy-scripts/scripts/base.sh"
        msg "### --------------------------------------"
        # msgerr "Cleaning ${_CORE_DIR}/scripts/base.sh"
        cat "${_CORE_DIR}/scripts/base.sh" | remove_sources | remove_comments | tr -s '\n\n'
        for f in "${midfiles[@]}"; do
            # If a passed file path doesn't exist, check if it exists in the same folder as core.sh
            # or inside of the scripts folder.
            [[ ! -f "$f" ]] && [[ -f "${_CORE_DIR}/${f}" ]] && f="${_CORE_DIR}/${f}"
            [[ ! -f "$f" ]] && [[ -f "${_CORE_DIR}/scripts/${f}" ]] && f="${_CORE_DIR}/scripts/${f}"
            rel_f=""
            if grep -q "${_CORE_DIR}" <<< "$f"; then
                rel_f=$(sed -E "s#${_CORE_DIR}/?##" <<< "$f")
            fi
            msg "\n### --------------------------------------"
            [[ "$rel_f" == "" ]] && msg "### $f" || msg "### Someguy123/someguy-scripts/${rel_f}"
            # msg "### Someguy123/someguy-scripts/scripts/base.sh"
            msg "### --------------------------------------"
            cat "$f" | remove_sources | remove_comments | tr -s '\n'
        done
    } > "$out_file"

    (($use_file==1)) && msg green " -> Compiled someguy-scripts into file '$out_file'" || \
        { cat "$out_file"; rm -f "$out_file"; }
}

_sgs_help() {
    echo
    echo "
===============================
      ${BLUE}Someguy123's Server${RESET}
         ${GREEN}Setup Helper${RESET}
===============================
To avoid mistakes, the menu is 
controlled by letter choices
    ${GREEN}inst${RESET} - Install various useful packages
    ${GREEN}pk_list${RESET} - List the packages that 'inst' would install
    ${GREEN}conf${RESET} - Install dotfile configs + oh-my-zsh
    ${GREEN}loc${RESET} - Fix locale problems - set locale to en_US.UTF-8 and re-gen locales
    ${GREEN}zsh${RESET} - Update the global /etc/zsh/zsh_sg with the current version in this repo
    ${GREEN}global${RESET} - Install dotfile configs globally
    ${GREEN}instconf${RESET} - Run inst, then conf after
    ${GREEN}hrd${RESET} - Harden the server (set SSH port, turn off password auth etc.)
    ${GREEN}fresh${RESET} - For fresh installs. Fix locale, install packages, configs, global configs, and harden
    ${GREEN}q${RESET} - Exit
"
}

handle_menu() {
    case $1 in
        instconf*|installconf* )
            install_essential
            install_confs;;
        inst* )
            install_essential;;
        conf* )
            install_confs;;
        loc )
            fix_locale;;
        zsh*|update_zsh*)
            update_zshrc;;
        global )
            install_global;;
        fresh )
            fresh;;
        hrd|hard* )
            harden;;
        pk_list|pkg* )
            msg green "Packages that would be installed:"
            for pk in "${INSTALL_PKGS[@]}"; do
                msg cyan " - ${BOLD}${pk}"
            done
            echo;;
        compi*)
            _sgs_compile "${@:2}";;
        [Qq]|exit|quit )
            exit;;
        hel*)
            _sgs_help;;
        * ) msg red "Invalid menu option. Try './core.sh help' or typing 'help' at the menu.";;
    esac
}

if (($#>0)); then
    handle_menu "$@"
    exit
fi

while true; do
    _sgs_help
    read -p "Menu > " menu_choice
    handle_menu "$menu_choice"
done
