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
# Essential functions + initialisation for someguy-scripts.
# ------------------------------

# As base.sh may be compiled into a singular script, it's best to set default variables only when a main
# function (i.e. sgs_provision) requires them. This ensures scripts appended after base.sh can set their
# preferred defaults.
sgs_var_defaults() {
    # Set these to 'y' in your environment before running lite.sh if you want to disable a certain
    # part of the lite installer.
    : ${SKIP_CLONE='n'}          # Do not git clone. Trust that LIB_DIR contains someguy-scripts already.
    : ${SKIP_LOCALE='n'}         # Do not configure/generate locales
    : ${SKIP_INSTALL='n'}        # Do not install packages listed in INSTALL_PKGS
    : ${SKIP_GLOBAL='n'}         # Do not install configurations and zsh files globally
    : ${SKIP_HARDEN='n'}         # Do not run server hardening

    : ${LIB_DIR="$(mktemp -d)"}  # Destination to clone someguy-scripts into (or existing location of someguy-scripts if SKIP_CLONE)
}

SGBASE_LOADED='y'

has_binary() { /usr/bin/env which "$1" > /dev/null; }

# If we don't have sudo, but the user is root, then just create a pass-thru 
# sudo function that simply runs the passed commands via env.
if ! has_binary sudo && [ "$EUID" -eq 0 ]; then
    sudo() { env "$@"; }
    has_sudo() { return 0; }
else
    has_sudo() { sudo -n ls > /dev/null; }
fi

echo
if ! has_binary curl; then
    if ! has_sudo; then
        echo
        echo " !!! CRITICAL ERROR: The package 'curl' is not installed, and you do not have passwordless sudo available."
        echo " !!! Due to a lack of passwordless sudo, we cannot auto-install curl for you."
        echo " !!! To be able to run lite.sh you must first run 'sudo apt install -y curl' and enter your password."
        echo
        exit 1
    else
        echo " >>> Missing 'curl' application. Attempting to install curl for you now."
        echo "       > Updating apt..."
        apt-get update -qy &> /dev/null
        APT_UPDATED="y"
        echo "       > Installing curl..."
        apt-get -o Dpkg::Options::='--force-confold' --force-yes install -qy curl &> /dev/null
        echo -e " [+++] Installed curl."
        echo -e "${_LN}"
    fi
fi

# Install and/or load Privex ShellCore if it isn't already loaded.
if [ -z ${S_CORE_VER+x} ]; then
    echo "Checking if Privex ShellCore is installed / Downloading it..."
    _sc_fail() { >&2 echo "Failed to load or install Privex ShellCore..." && exit 1; }  # Error handling function for Privex ShellCore
    # If `load.sh` isn't found in the user install / global install, then download and run the auto-installer from Privex's CDN.
    [[ -f "${HOME}/.pv-shcore/load.sh" ]] || [[ -f "/usr/local/share/pv-shcore/load.sh" ]] || \
        { curl -fsS https://cdn.privex.io/github/shell-core/install.sh | bash >/dev/null; } || _sc_fail
    echo "Loading Privex ShellCore..."
    # Attempt to load the local install of ShellCore first, then fallback to global install if it's not found.
    [[ -d "${HOME}/.pv-shcore" ]] && . "${HOME}/.pv-shcore/load.sh" || . "/usr/local/share/pv-shcore/load.sh" || _sc_fail
fi

sg_copyright() {
    msg "${_LN}"
    msg bold green " ############################################################"
    msg bold green " ###                                                      ###"
    msg bold green " ###   Someguy Scripts - (C) 2019 github.com/Someguy123   ###"
    msg bold green " ###   Released as open source under the GNU AGPL v3      ###"
    msg bold green " ###                                                      ###"
    msg bold green " ############################################################"
    msg "${_LN}"
    sleep 2
}

sgs_clone() {
    if [[ "$SKIP_CLONE" != "y" ]]; then
        msg cyan " >>> Cloning 'github.com/Someguy123/someguy-scripts.git' into temp folder: $LIB_DIR"
        git clone --recurse-submodules -q https://github.com/Someguy123/someguy-scripts.git "$LIB_DIR"
        msg green " [+] Done.\n"
    else
        if [[ ! -d "${LIB_DIR}" ]]; then
            msg bold red " [!!!] Critical Error. SKIP_CLONE is 'y' but the LIB_DIR folder doesn't exist: $LIB_DIR "
            msg bold red " [!!!] Cannot continue without LIB_DIR pointing to a valid someguy-scripts installation\n"
            return 1
        elif [[ ! -f "${LIB_DIR}/lib.sh" ]]; then
            msg bold red " [!!!] Critical Error. SKIP_CLONE is 'y' but the file '${LIB_DIR}/lib.sh' does not exist."
            msg bold red " [!!!] Cannot continue without LIB_DIR pointing to a valid someguy-scripts installation\n"
            return 1
        fi
        msg yellow " [-] Skipping clone as SKIP_CLONE is 'y'. Using someguy-scripts in folder: $LIB_DIR"
    fi
    return 0
}

# If ZSH_USERS isn't set in the environment, then use these defaults.
[ -z ${ZSH_USERS+x} ] && ZSH_USERS=(root ubuntu chris privex user)


sgs_provision() {
    local u uh
    sgs_var_defaults
    msg
    msg cyan " >>> Checking both 'git' and 'curl' are available, otherwise installing them..."
    pkg_not_found git git
    pkg_not_found curl curl
    msg green " [+] Done.\n"
    if [ -z ${SGLIB_LOADED+x} ]; then
        sgs_clone
        msg "${_LN}"
        msg cyan " >>> Importing library file: ${LIB_DIR}/lib.sh"
        cd "$LIB_DIR"
        . "lib.sh" || { >&2 echo "!!! ERROR !!! Could not load lib.sh. Cannot continue."; exit 1; }
        msg green " [+] Done.\n"        
    fi
    msg "${_LN}"

    [[ "$SKIP_LOCALE" == "y" ]] || { msg cyan " >>> Preventing locale issues..."; fix_locale; msg green " [+] Done.\n"; }
    msg "${_LN}"
    [[ "$SKIP_INSTALL" == "y" ]] || { install_essential; msg green " [+] Done.\n"; }
    msg "${_LN}"
    [[ "$SKIP_GLOBAL" == "y" ]] || { msg cyan " >>> Installing global configs and zsh files..."; install_global; msg green " [+] Done.\n"; }
    msg "${_LN}"
    [[ "$SKIP_HARDEN" == "y" ]] || { harden; msg green " [+] Done.\n"; }
    msg "${_LN}"
    
    msg cyan " >>> Setting zsh as the default shell for ZSH_USERS: ${ZSH_USERS[@]}"
    for u in "${ZSH_USERS[@]}"; do
        # Check if the user exists via 'getent' - if they do, then make sure their shell is set to zsh.
        if ! getent passwd "$u" > /dev/null; then 
            msg yellow "     [!] User '$u' doesn't exist. Skipping.\n"
            continue
        fi

        msg green "     [+] Setting ZSH as the default shell for user '$u'"
        change_shell "$u" > /dev/null

        msg green "     [+] Checking if user '$u' has a .zshrc file"
        local uh=$(get_home "$u")
        if (($(len "$uh")<3)); then
            msg yellow "     [!] User home folder too short (< 3 chars)... Skipping for safety. Folder was: ${BOLD}$uh"
            continue
        fi

        _copy_zshrc "$uh" > /dev/null && msg green "     [+] User '$u' has .zshrc file, or one was installed successfully.\n" && \
                  OMZSH_INSTALLED='y' || msg red   "     [!] Error while attempting to install .zshrc file into '$uh'...\n"

    done
    msg green " [+] Done.\n";
    msg bold green " [+++] Finished running Someguy-Scripts lite auto-provisioner.\n"
    sg_copyright
}

