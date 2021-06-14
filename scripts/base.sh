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

export PATH="${HOME}/.local/bin:/snap/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH}"
: ${XDEBUG="0"}
export XDEBUG
if (( XDEBUG )); then
    # Extra debugging - Print bash commands and their arguments as they are executed.
    set -x
fi

find-cmd() {
    [[ -f "/usr/bin/$1" || -f "/bin/$1" || -f "/usr/sbin/$1" || -f "/sbin/$1" || -f "/usr/local/bin/$1" ]]
}

msg() {
    echo -e "$@"
}
msgerr() { >&2 msg "$@"; }
_debug() { (( SG_DEBUG )) && msgerr "$@" || true; }

instx() {
    local outx="/dev/stderr" needsudo=1
    [[ "$1" == "-q" ]] && outx="/dev/null" && shift
    [[ "$1" == "-u" ]] && needsudo=0 && shift
    [[ "$1" == "-q" ]] && outx="/dev/null" && shift

    if (( needsudo )); then
        sg-sudo cp "$1" "$2" &> "$outx"
        sg-sudo chmod +x "$2"  &> "$outx"
    else
        cp "$1" "$2" &> "$outx"
        chmod +x "$2"  &> "$outx"
    fi
}

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

has_command() { command -v "$1" > /dev/null; }
sg_has_binary() {
    local q="$1" wi
    if [[ -f "/usr/bin/findbin" ]]; then
        /usr/bin/findbin -q "$@"
        return $?
    elif [[ -f "/usr/local/bin/command" ]]; then
        /usr/local/bin/command "$@" &> /dev/null;
        return $?
    elif find-cmd command; then
        env -- command -v "$1" &> /dev/null;
        return $?
    elif [[ -f "/usr/local/bin/which" ]]; then
        /usr/local/bin/which "$@" &> /dev/null;
        return $?
    elif find-cmd which; then
        env -- which "$@" &> /dev/null;
        return $?
    elif find-cmd whereis; then
        wi="$(env -- whereis "$1" &> /dev/null)"
        [[ "$wi" != "${q}:" && "$wi" != "${q}: " &&  "$wi" != "${q}:\t" ]]
        return $?
    else
        command -v "$q" &> /dev/null;
        return $?
    fi
}
sg-has-binary() { sg_has_binary "$@"; }
has_binary() { sg_has_binary "$@"; }
has-binary() { sg_has_binary "$@"; }
export -f has_binary sg_has_binary has-binary sg-has-binary


sg-sudo() {
    if (( EUID == 0 )); then
        _debug "EUID is 0 (root). Using eval to evaluate the passed arguments directly: $*"
        # Iterate over args and remove any switch/flag arguments for sudo, until the first
        # arg which doesn't start with a dash.
        while (( $# > 0 )); do
            if [[ "$1" == "sudo" || "$1" == "sg-sudo" ]]; then
                msgerr "Attempted to run sudo with sudo!!!!"
                return 2
            fi
            [[ "$1" == "--" ]] && break
            if grep -Eq '^\-' <<< "$1"; then
                shift
            else
                break
            fi
        done
        _debug "Running env: $*"
        
        env -- "$@"
        return $?
    else
        if sg-has-binary sudo; then
            _debug "User is not root, but found sudo. Running sudo with args: $*"
            if [[ -f "/usr/bin/findbin" ]]; then
                local sdbin="$(/usr/bin/findbin sudo)"
                _debug "Found direct path to sudo binary using findbin: $sdbin"
                "$sdbin" -- "$@"
                return $?
            else
                _debug "findbin not available. Using env to run sudo: env sudo -- $*"
                env sudo -- "$@"
                return $?
            fi
        elif sg-has-binary su; then
            _debug "sudo not available but su is. using su: su -c \"$(printf '%q ' "$@")\""
            # Iterate over args and remove any switch/flag arguments for sudo, until the first
            # arg which doesn't start with a dash.
            while (( $# > 0 )); do
                if [[ "$1" == "sudo" || "$1" == "sg-sudo" ]]; then
                    msgerr "Attempted to run sudo with sudo!!!!"
                    return 2
                fi
                [[ "$1" == "--" ]] && break
                if grep -Eq '^\-' <<< "$1"; then
                    shift
                else
                    break
                fi
            done
            su -c "$(printf '%q ' "$@")"
            return $?
        else
            msgerr " [!!!] ERROR: Neither sudo nor su are available, and you're not root. Cannot run: $*"
            return 9
        fi
    fi
}
xsudo() { sg-sudo "$@"; }
unalias sudo &> /dev/null
unset sudo &> /dev/null
sudo() { sg-sudo "$@"; }

export -f sg-sudo xsudo sudo


if find-cmd python3 && [[ -f /tmp/findbin.py ]]; then
    instx -q /tmp/findbin.py /usr/bin/findbin
    sg-sudo ln -s /usr/bin/findbin /usr/local/bin/findbin
    [[ ! -f /usr/local/bin/command ]] && sg-sudo ln -s /usr/bin/findbin /usr/local/bin/command
    [[ ! -f /usr/local/bin/which ]] && sg-sudo ln -s /usr/bin/findbin /usr/local/bin/which
fi


if ! find-cmd sudo && [ "$EUID" -eq 0 ]; then
    has_sudo() { return 0; }
else
    has_sudo() { sudo -n ls > /dev/null; }
fi


OS="$(uname -s)"
: ${BASE_OS=""}
: ${BASE_PKG_MGR=""}
: ${FB_PKG_MGR=""}

if [[ -n "$BASE_PKG_MGR" ]]; then
    : ${PKG_UPDATE="$BASE_PKG_MGR update -y"}
    : ${PKG_INSTALL="$BASE_PKG_MGR install -y"}
else
    PKG_UPDATE="" PKG_INSTALL=""
fi

PKG_MGR_UPDATED=0
: ${PKG_INSTALLED=""}

if [[ -z "$PKG_INSTALL" || -z "$BASE_OS" ]]; then
    [[ -f /etc/debian_version ]] && BASE_OS="debian"
    sg-has-binary apt-get && sg-has-binary dpkg && BASE_OS="debian"
    [[ -f /etc/redhat-release ]] && BASE_OS="rhel"
    [[ -f /etc/oracle-release ]] && BASE_OS="rhel"
    { sg-has-binary yum || sg-has-binary dnf; } && BASE_OS="rhel"
    [[ -f "/etc/arch-release" ]] && sg-has-binary pacman && BASE_OS="arch"
    [[ -f "/etc/gentoo-release" ]] && sg-has-binary emerge && BASE_OS="gentoo"
    [[ -f "/etc/alpine-release" ]] && sg-has-binary apk && BASE_OS="alpine"
fi

if [[ -z "$PKG_INSTALL" || -z "$PKG_UPDATE" ]]; then
    case "$BASE_OS" in
        debian|deb|ubuntu|Ubuntu|ubu|mint|Mint|Kali|"Kali Linux"|"Linux Mint"|"Ubuntu Linux")
            BASE_PKG_MGR="apt-get"  FB_PKG_MGR="apt"
            sg-has-binary "$BASE_PKG_MGR" || BASE_PKG_MGR="$FB_PKG_MGR"
            PKG_UPDATE="$BASE_PKG_MGR update -qy" PKG_INSTALL="$BASE_PKG_MGR install -qy" PKG_INSTALLED="dpkg -s"
            ;;
        rhel|rh|RHEL|RH|redhat|RedHat|oracle|Oracle|"Oracle Linux"fedora|centos|Fedora|CentOS|"RedHat Enterprise Linux")
            BASE_PKG_MGR="dnf" FB_PKG_MGR="yum"
            sg-has-binary "$BASE_PKG_MGR" || BASE_PKG_MGR="$FB_PKG_MGR"
            PKG_UPDATE="$BASE_PKG_MGR makecache -y" PKG_INSTALL="$BASE_PKG_MGR install -y" PKG_INSTALLED="rh-has-pkg"
            ;;
        arch|archlinux|Arch|ArchLinux|"Arch Linux"|"arch linux")
            BASE_PKG_MGR="pacman"
            PKG_UPDATE="$BASE_PKG_MGR -Sy" PKG_INSTALL="$BASE_PKG_MGR -S" PKG_INSTALLED="$BASE_PKG_MGR -Q"
            ;;
        alp|alpine|alpinelinux|"Alpine"|"Alpine Linux"|"alpine linux")
            BASE_PKG_MGR="apk"
            PKG_UPDATE="$BASE_PKG_MGR update" PKG_INSTALL="$BASE_PKG_MGR add -f" PKG_INSTALLED="apk-has-pkg"
            ;;
        gen|gentoo|Gentoo|"gentoo linux"|"Gentoo Linux")
            BASE_PKG_MGR="emerge"
            PKG_UPDATE="$BASE_PKG_MGR --sync" PKG_INSTALL="$BASE_PKG_MGR" PKG_INSTALLED="apk-has-pkg"
            ;;
    esac
fi

PKG_MGR_UPDATE="$PKG_UPDATE" PKG_MGR_INSTALL="$PKG_INSTALL" PKG_MGR_INSTALLED="$PKG_INSTALLED"

export DEBIAN_FRONTEND=noninteractive


rh-has-pkg() {
    rpm -qa | grep -qi "$1"
}

apk-has-pkg() {
    lct="$(apk version "$1" | wc -l)"
    (( lct >= 2 )) || false
}

is-rhel() { [[ "$BASE_OS" == "rhel" ]] || [[ -f /etc/redhat-release ]] || [[ -f /etc/oracle-release ]]; }

has-rhel-equiv() {
    [[ -v RHEL_EQUIV[$1] ]];
}

get-rhel-equiv() {
    local pname="$1" sedmatched=0
    if grep -Eq -- '^python3\.' <<< "$pname"; then
        pname="$(sed -E 's/^python3\./python3/' <<< "$pname")"
        sedmatched=1
    fi
    if grep -Eq -- '^(python3-venv|python3(\.[0-9]+)-venv)$' <<< "$pname"; then
        pname="$(sed -E 's/\-venv$/-virtualenv/' <<< "$pname")"
        sedmatched=1
    fi
    if grep -Eq -- '-dev$' <<< "$pname"; then
        pname="$(sed -E 's/\-dev$/-devel/' <<< "$pname")"
        sedmatched=1
    fi
    if (( sedmatched )); then
        _debug yellow " [get-rhel-equiv] sedmatched is true, djusted name: $pname"
        #echo "$pname"; 
        #return 0; 
    else
        _debug yellow " [get-rhel-equiv] sedmatched is false, finding equiv for: $pname"
    fi

    case "$pname" in
        dnsutils) echo "bind-utils";;
        iputils-ping) echo "iputils";;
        liblz4-tool) echo "lz4";;
        "build-essential") echo "gcc gcc-c++ make cmake automake autoconf bison libtool awk glibc-devel glibc-headers libcurl-devel";;
        thin-provisioning-tools) echo "lvm2";;
        *) echo "$pname";;
    esac
    # has-rhel-equiv "$pname" && echo "${RHEL_EQUIV["${pname}"]}" || echo "$pname"
}


pkg-installed() {
    sg-sudo "$PKG_INSTALLED" "$@" &> /dev/null
}

install-pkg() {
    local pkglst
    pkglst=("$@")
    _debug yellow " [install-pkg] BASE_OS: '$BASE_OS' | BASE_PKG_MGR: $BASE_PKG_MGR | PKG_INSTALL: $PKG_INSTALL | PKG_UPDATE: $PKG_UPDATE | pkglst: ${pkglst[*]}"
    msg cyan " >>> Installing packages: ${pkglst[*]} ..."
    if [[ "$BASE_OS" == "debian" && "$APT_UPDATED" == "n" ]]; then
        _debug yellow " [install-pkg] Running debian package manager update command: sudo $BASE_PKG_MGR update -qy"
        msg bold blue "     > Updating apt repository data, please wait..."
        sg-sudo "$BASE_PKG_MGR" update -qy &> /dev/null
        APT_UPDATED="y" PKG_MGR_UPDATED=1
    elif (( PKG_MGR_UPDATED == 0 )) && [[ -n "$PKG_UPDATE" ]]; then
        _debug yellow " [install-pkg] Running OS '$BASE_OS' package manager update command: sudo $PKG_UPDATE"
        sg-sudo $PKG_UPDATE
        PKG_MGR_UPDATED=1
    fi
    if is-rhel; then
        _new_pkgs=()
        for p in "${pkglst[@]}"; do
            _new_pkg=($(get-rhel-equiv "$p"))
            _debug yellow " --> Found Redhat-based equivalent package for '${p}'. Replacing package name with: ${_new_pkg[*]}"
            _new_pkgs+=("${_new_pkg[@]}")
        done
        pkglst=("${_new_pkgs[@]}")
        _debug yellow " ---> Updated package list is: ${_new_pkgs[*]}"
    fi
    if [[ -n "$PKG_INSTALLED" ]]; then
        _new_pkgs=()
        _debug yellow " ---> Stripping any packages that are already installed using command: $PKG_INSTALLED"
        for p in "${pkglst[@]}"; do
            pkg-installed "$p" && _debug yellow " ------> Package '$p' is already installed. removing from list." continue
            _debug yellow " ------> Package '$p' not installed. adding to list."
            _new_pkgs+=("$p")
        done
        pkglst=("${_new_pkgs[@]}")
    fi

    msg bold blue "     > Installing various packages, please wait..."
    if [[ "$BASE_OS" == "debian" ]]; then
        _DEB_EX_ARGS=("-o" "Dpkg::Options::='--force-confold'" "-o" "Dpkg::Use-Pty=0" "--force-yes" "install" "-qq" "-y")
        _debug yellow " [install-pkg] OS appears to be debian, using $BASE_PKG_MGR - sudo $BASE_PKG_MGR ${_DEB_EX_ARGS[*]} ${pkglst[*]}"
        DEBIAN_FRONTEND=noninteractive sg-sudo "$BASE_PKG_MGR" "${_DEB_EX_ARGS[@]}" "${pkglst[@]}" &>/dev/null
    elif [[ -n "$PKG_INSTALL" ]]; then
        _debug yellow " [install-pkg] Running package manager install command: sudo $PKG_INSTALL ${pkglst[*]}"
        if ! sg-sudo $PKG_INSTALL "${pkglst[@]}" ; then
            if [[ -n "$PKG_INSTALLED" ]]; then
                _new_pkgs=()
                _debug yellow " ---> Stripping any packages that are already installed using command: $PKG_INSTALLED"
                for p in "${pkglst[@]}"; do
                    pkg-installed "$p" && continue
                    _new_pkgs+=("$p")
                done
                pkglst=("${_new_pkgs[@]}")
            fi
            for pk in "${pkglst[@]}"; do
                _debug yellow " [install-pkg] Installing individual package $pk - running package manager install command: sudo $PKG_INSTALL ${pk}"
                sg-sudo $PKG_INSTALL "$pk"
            done
        fi
    fi
}

pkg_not_found() {
    if (( $# < 2 )); then
        msg red "ERR: pkg_not_found requires 2 arguments (cmd) (package)"
        return 9
    fi
    local cmd="$1" pkg="$2" _new_pkg=""
    _debug yellow " [pkg_not_found] Checking if we have binary: $cmd (pkg: ${pkg})"
    if ! sg-has-binary "$cmd"; then
        _debug yellow " [pkg_not_found] Got falsey from has_binary '$cmd'"
        msg yellow "WARNING: Command $cmd was not found. installing now..."
        install-pkg "$pkg"
    else
        _debug green " [pkg_not_found] We appear to already have the binary: '$cmd'"
    fi
}

pkg-not-found() { pkg_not_found "$@"; }

autopkg() {
    local cmdlist missingpkgs
    missingpkgs=() cmdlist=("$@")
    
    for xc in "${cmdlist[@]}"; do
        if ! sg-has-binary "$xc"; then
            msg yellow "WARNING: Command $xc was not found. Adding to package installation queue ..."
            missingpkgs+=("$xc")
        else
            _debug green " [autopkg] We appear to already have the binary: '$xc'"
        fi
    done
    if (( ${#missingpkgs[@]} < 1 )); then
        _debug green " [autopkg] All commands passed to autopkg already seem to exist. Not installing package for any of these cmds: ${missingpkgs[*]}"
    else
        msg cyan " >>> Installing same-named package for commands: ${missingpkgs[*]}"
        install-pkg "${missingpkgs[@]}"
    fi   
}

autopkg git curl wget rsync python3
pkg-not-found pip3 python3-pip


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

sg-has-binary() { sg_has_binary "$@"; }
has_binary() { sg_has_binary "$@"; }
has-binary() { sg_has_binary "$@"; }
export -f has_binary sg_has_binary has-binary sg-has-binary
if ! sg-has-binary sudo && [ "$EUID" -eq 0 ]; then
    # sudo() { env -- "$@"; }
    has_sudo() { return 0; }
else
    has_sudo() { sudo -n ls > /dev/null; }
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
[ -z ${ZSH_USERS+x} ] && ZSH_USERS=(root ubuntu debian centos oracle redhat admin linux fedora user chris privex kale someguy someguy123)


sgs_provision() {
    local u uh
    sgs_var_defaults
    msg
    msg cyan " >>> Checking both 'git' and 'curl' are available, otherwise installing them..."
    autopkg git curl
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
    
    msg cyan " >>> Setting zsh as the default shell for ZSH_USERS: ${ZSH_USERS[*]}"
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

