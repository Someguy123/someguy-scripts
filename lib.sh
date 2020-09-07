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
# This file contains the various functions used by someguy-scripts/core.sh allowing them
# to be sourced by other scripts for auto-install etc.
# ------------------------------

export SG_SCRIPTS_VERSION='2.0.0'

echo
# Detect the PWD of this file, so we can appropriately find 
# the files needed, regardless of where it was ran from.
if [ -z ${LIB_DIR+x} ]; then 
    LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
else
    echo " [-] \$LIB_DIR was set from environment. Using the following folder as someguy-scripts base: $LIB_DIR"
fi

echo " [...] Initialising / updating Git submodules using: git submodule update --recursive --remote --init ${LIB_DIR}"

git submodule update --recursive --remote --init "${LIB_DIR}"

_lcl_shc="${LIB_DIR}/scripts/shell-core/load.sh" _hm_shc="${HOME}/.pv-shcore/load.sh" _glb_shc="/usr/local/share/pv-shcore/load.sh"
echo
# Install and/or load Privex ShellCore if it isn't already loaded.
if [ -z ${S_CORE_VER+x} ]; then
    echo "Checking if Privex ShellCore is installed / Downloading it..."
    _sc_fail() { >&2 echo "Failed to load or install Privex ShellCore..." && exit 1; }  # Error handling function for Privex ShellCore
    # If `load.sh` isn't found in the user install / global install, then download and run the auto-installer from Privex's CDN.
    [[ -f "${_lcl_shc}" ]] || [[ -f "$_hm_shc" ]] || [[ -f "$_glb_shc" ]] || { 
        curl -fsS https://cdn.privex.io/github/shell-core/install.sh | bash >/dev/null; } || _sc_fail
    
    echo "Loading Privex ShellCore..."
    # Attempt to load the local install of ShellCore first, then fallback to global install if it's not found.
    [[ -f "${_lcl_shc}" ]] && source "${_lcl_shc}" || source "$_hm_shc" || source "$_glb_shc" || _sc_fail
fi
echo
echo

export PATH="${PATH}:${LIB_DIR}/scripts/privex-utils/bin"

OS="$(uname -s)"

# Override where the dotfiles and zsh_files get copied to
# by using CONFIG_DIR=/where/you/want ./core.sh
: ${CONFIG_DIR="$HOME"}

if [ -z ${INSTALL_USERS+x} ]; then
    INSTALL_USERS=(
        ubuntu
        debian
        centos
        fedora
        user
        chris
        privex
        kale
        someguy
        someguy123
        root
    )
fi

SGLIB_LOADED='y'

# List of locales to generate, will uncomment all locales starting with the given string
# e.g. en_GB will cover en_GB.UTF-8 as well as en_GB.ISO-8859-1 etc.
[ -z ${ENABLE_LOCALES+x} ] && ENABLE_LOCALES=('en_GB' 'en_US')

. "$LIB_DIR/zsh_files/colors.zsh"  # Load terminal colors
. "$LIB_DIR/zsh_files/gnusafe.zsh" # GNU Tools Safety checker
# make sure we have gnu utilities, otherwise exit
gnusafe || return 1 2>/dev/null || exit 1

: ${OMZSH_INSTALLED="n"}
: ${APT_UPDATED="n"}
# set by 'fresh' function, bypasses overwrite confirmations etc.
: ${IS_FRESH='n'}

# We set the locale variables all to C as it should be present on all systems reliably.
{
    export LANGUAGE="C" || export LANGUAGE="en_US.UTF-8";
    export LANG="C"  || export LANG="en_US.UTF-8";
    export LC_ALL="C"  || export LC_ALL="en_US.UTF-8";
    export LC_CTYPE="C"  || export LC_CTYPE="en_US.UTF-8";
} &> /dev/null

# If INSTALL_PKGS is set from the environment, we should use that.
# If not, use our defaults.
if [ -z ${INSTALL_PKGS+x} ]; then 
    INSTALL_PKGS=(
        # General
        git curl wget
        # Session management
        tmux screen
        # Security
        fail2ban
        # Network tools
        mtr-tiny iputils-ping nmap netcat dnsutils net-tools
        # Development
        build-essential vim nano zsh
        # Server debugging/stats
        htop sysstat # sysstat = iotop
        # Compression/Decompression
        liblz4-tool # lz4 for fast compress/decompress
        zip unzip xz-utils
        # Python3 for various things
        python3 python3-pip python3-venv
        # Command-not-found, to tell you where to find a command in apt
        command-not-found
        # Other
        thin-provisioning-tools
    )
else 
    echo "${YELLOW}It looks like you've set INSTALL_PKGS in your environment."
    echo "We'll use the packages in there for our install_essential${RESET}"
    echo -e "\n\n"
    sleep 3
fi

# If we don't have sudo, but the user is root, then just create a pass-thru 
# sudo function that simply runs the passed commands via env.
if ! has_binary sudo && [ "$EUID" -eq 0 ]; then
    sudo() { env "$@"; }
    has_sudo() { return 0; }
else
    has_sudo() { sudo -n ls > /dev/null; }
fi

###########
# Install the skeleton .zshrc into either a passed destination folder (1st argument),
# or if no folder was passed, defaults to $HOME
# If zsh_sg or skel/.zshrc are missing, the return code '1' will be returned.
# If the 'zsh' binary cannot be found, the return code '2' will be returned.
# Otherwise, standard '0' for success.
###########
_copy_zshrc() {
    local dest_fld
    (($#>0)) && dest_fld="$1" || dest_fld="$HOME"
    # If the 'zsh' binary exists, and the dest folder contains a .zshrc then we don't need to do anything.
    if has_binary zsh && [[ -f "$dest_fld/.zshrc" ]]; then return 0; fi
    msg
    if ! has_binary zsh; then
        msgerr yellow " [!!!] WARNING: Cannot find 'zsh' binary. Not installing skeleton zshrc file.\n"
        return 2
    fi

    if [[ -f "/etc/zsh/zsh_sg" && -f "/etc/skel/.zshrc" ]]; then
        msg cyan  " >>> ZSH has been installed / setup, but $dest_fld/.zshrc does not exist."
        msg green "     [+] Copying skeleton file from /etc/skel/.zshrc -> $dest_fld/.zshrc"
        if can_write "$dest_fld" > /dev/null; then
            cp -nv /etc/skel/.zshrc "$dest_fld/.zshrc"
        elif has_sudo; then
            msgerr yellow " [?] We don't seem to have write permission to '$dest_fld'... Trying sudo."
            sudo cp -nv /etc/skel/.zshrc "$dest_fld/.zshrc"
        else
            msgerr red " [!!!] ERROR. Cannot write to folder '$dest_fld' and sudo is not installed / not passwordless."
            return 3
        fi
        msg green " [+++] Done.\n"
        return 0
    fi

    msgerr yellow " [!!!] WARNING: The global files '/etc/zsh/zsh_sg' and/or '/etc/skel/.zshrc' are missing."
    msgerr yellow " [!!!] Cannot install template zshrc into '$dest_fld'\n"
    return 1
}

finish() {
    # ensure the current user has a .zshrc
    _copy_zshrc || true
    # start ZSH if it was installed
    if [[ "$OMZSH_INSTALLED" == "y" && -f "$HOME/.zshrc" ]]; then
        printf "${GREEN}"
        echo '         __                                     __   '
        echo '  ____  / /_     ____ ___  __  __   ____  _____/ /_  '
        echo ' / __ \/ __ \   / __ `__ \/ / / /  /_  / / ___/ __ \ '
        echo '/ /_/ / / / /  / / / / / / /_/ /    / /_(__  ) / / / '
        echo '\____/_/ /_/  /_/ /_/ /_/\__, /    /___/____/_/ /_/  '
        echo '                        /____/                       ....is now installed!'
        echo
        printf "${NORMAL}"
        export SHELL="$(which zsh)"
        env zsh -l
    fi
}

trap finish EXIT

###########
# Get the home folder of a given user
#
# Example:    
#     $ john_home=$(get_home john)
#     $ echo "$john_home"
#     /mnt/homes/john
#
###########
get_home() {
    local home_user passwd_line
    (($#>0)) && home_user="$1" || home_user="$(whoami)"
    if ! getent passwd "$home_user" > /dev/null; then
        msgerr red " [!!!] Error running 'get_home'. User '$home_user' does not appear to exist!\n"
        return 1
    fi
    _IFS="$IFS"
    IFS=":"
    passwd_line=($(getent passwd "$home_user"))
    echo "${passwd_line[5]}"
    IFS="$_IFS"
}

#####
# Change a user's shell to zsh
# Usage:
#
#     change_shell [username]
#
# If a username isn't specified, it defaults to the current user (returned from 'whoami')
#####
change_shell() {
    local sh_user TEST_CURRENT_SHELL

    if ! has_binary zsh; then
        msgerr bold red "ERROR! Cannot change shell as 'zsh' was not found.\n"
        return 1
    fi

    if (($#<1)); then
        sh_user=$(whoami)
        msgerr yellow "WARNING: change_shell received no arguments. Changing shell for current user: '${sh_user}'"
    else
        sh_user="$1"
    fi

    # If this user's login shell is already "zsh", then don't attempt to switch.
    TEST_CURRENT_SHELL=$(expr "$SHELL" : '.*/\(.*\)')
    if [ "$TEST_CURRENT_SHELL" == "zsh" ]; then
        msg green " [+++] The shell for user '$sh_user' is already zsh. Not changing shells.\n"
        return 0
    fi

    if hash chsh >/dev/null 2>&1; then
        msg cyan " >> Changing shell for user ${BOLD}'${sh_user}'${RESET}${CYAN} to zsh"
        sudo chsh -s $(grep /zsh$ /etc/shells | tail -1) "$sh_user"
        msg green " +++ Done."
    # Else, suggest the user do so manually.
    else
        msgerr yellow " !!! I can't change your shell automatically because this system does not have chsh."
        msgerr cyan   " !!! Please manually change your default shell to zsh!\n"
        return 1
    fi
    echo
}

######
# Install oh-my-zsh
# Some parts borrowed from the official install.sh.
# Official install.sh not used because it messes with the configs
# and auto starts zsh in middle of our script
#####
install_omz() {
    # to be able to install oh-my-zsh we need git, curl and zsh
    pkg_not_found git git
    pkg_not_found curl curl
    pkg_not_found zsh zsh

    # sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    git clone --depth=1 https://github.com/robbyrussell/oh-my-zsh.git "$HOME/.oh-my-zsh"
    # If this user's login shell is not already "zsh", attempt to switch.
    change_shell "$(whoami)"
    OMZSH_INSTALLED="y"
}

install_omz_themes() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        msg cyan " >>> Installing extra oh-my-zsh themes into $HOME/.oh-my-zsh"
        sexy-copy -r "${LIB_DIR}/omz_themes/" "${HOME}/.oh-my-zsh/custom/themes/"
    fi
    if [ -d "/etc/oh-my-zsh" ]; then
        msg cyan " >>> Installing extra oh-my-zsh themes into /etc/oh-my-zsh"
        sudo sexy-copy -r "${LIB_DIR}/omz_themes/" "/etc/oh-my-zsh/custom/themes/"
    fi
}



######
# Install config files
#####
install_confs() {
    pkg_not_found rsync rsync
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        msg yellow " >>> Looks like oh-my-zsh isn't installed..."
        msg yellow "     [+] Will now install it...\n"
        install_omz
    fi
    # For safety, exit on non-zero
    set -e
    
    msg cyan " >>> Installing zsh skeleton file into ${CONFIG_DIR}/.zshrc"
    if [[ $IS_FRESH == "y" ]]; then
        cp -v "${LIB_DIR}/extras/zsh_skel" "${CONFIG_DIR}/.zshrc"
    else
        cp -iv "${LIB_DIR}/extras/zsh_skel" "${CONFIG_DIR}/.zshrc"
    fi
    install_omz_themes
    msg
    msg cyan " >>> Installing dotfiles..."
    if [[ -d "${CONFIG_DIR}/.tmux" ]]; then
        msg yellow " [!!!] Folder ${CONFIG_DIR}/.tmux already exists. Not cloning github.com/gpakosz/.tmux"
    else
        msg green " >>> Cloning github.com/gpakosz/.tmux into ${CONFIG_DIR}/.tmux"
        git clone https://github.com/gpakosz/.tmux "${CONFIG_DIR}/.tmux"
    fi

    # first, see if there are any that will be overwritten and warn against it
    for file in $LIB_DIR/dotfiles/*; do
        [ -e "$file" ] || continue # protect against failed match returning glob
        # remove the path to the file so we can add a dot to the start
        filename=$(basename -- "$file")
        dotf=".$filename"
        f_install_loc="$CONFIG_DIR/$dotf"
        # if the file already exists, ask user if we should overwrite
        if [[ -f "$f_install_loc" && $IS_FRESH == "n" ]]; then
            while true; do
                msgerr yellow "WARNING: The file $f_install_loc already exists..."
                backupdir=$(dirname "$f_install_loc")
                origname=$(basename "$f_install_loc")
                backupname="backup-$(date +%Y-%m-%d).${origname}"
                backuppath="${backupdir}/${backupname}"
                msg yellow "Do you want to replace this file? (we'll back it up to '${backuppath}')"
                read -p " (y)es/(n)o/(v)iew existing > " yn
                case $yn in
                    [Yy]* )
                        echo "${YELLOW} -> Backing up $f_install_loc to $backuppath ${RESET}"
                        mv -v "$f_install_loc" "$backuppath"
                        if [[ -f "$f_install_loc" ]]; then
                            msgerr bold red "ERROR: Something must've went wrong renaming this file, as $f_install_loc still exists"
                            msgerr red "For your safety, we'll just skip this file."
                            continue
                        else
                            msg green " [+] Copying from $file to $f_install_loc";
                            cp -v "$file" "$f_install_loc"
                        fi
                        break;;
                    [Vv]* ) cat "$f_install_loc";;
                    [Nn]* )
                        break;;
                    * ) msgerr red " !! Please answer yes (y), view existing (v) or no (n).";;
                esac
            done
            continue
        else
            # the file doesn't exist, so it should be safe to copy to
            # for safety, use cp -i, just incase something is wrong with the overwrite check above
            if [[ $IS_FRESH == "y" ]]; then
                cp() { env cp -v "$@"; }
            else
                cp() { env cp -vi "$@"; }
            fi
            cp "$file" "$f_install_loc"
            unset -f cp
        fi
    done
    echo "${BLUE}Installing zsh_files...${RESET}"
    for file in $LIB_DIR/zsh_files/*; do
        [ -e "$file" ] || continue # protect against failed match returning glob

        # remove the path to the file so we can add a dot to the start
        filename=$(basename -- "$file")
        f_install_loc="$CONFIG_DIR/.zsh_files/$filename"
        if ! [[ -d "$CONFIG_DIR/.zsh_files" ]]; then
            mkdir -p "$CONFIG_DIR/.zsh_files"
        fi
        # if the file already exists, ask user if we should overwrite
        if [[ -f "$f_install_loc" && $IS_FRESH == "n" ]]; then
            while true; do
                echo "${YELLOW}WARNING: The file $f_install_loc already exists...${RESET}"
                backupdir=$(dirname "$f_install_loc")
                origname=$(basename "$f_install_loc")
                backupname="backup-$(date +%Y-%m-%d).${origname}"
                backuppath="${backupdir}/${backupname}"
                echo "${YELLOW}Do you want to replace this file? (we'll back it up to '${backuppath}')${RESET}"
                read -p " (y)es/(n)o/(v)iew existing > " yn
                case $yn in
                    [Yy]* )
                        echo "${YELLOW} -> Backing up $f_install_loc to $backuppath ${RESET}"
                        mv -v "$f_install_loc" "$backuppath"
                        if [[ -f "$f_install_loc" ]]; then
                            echo "${RED}${BOLD}ERROR: Something must've went wrong renaming this file, as $f_install_loc still exists${RESET}"
                            echo "${RED}For your safety, we'll just skip this file.${RESET}"
                            continue
                        else
                            echo "Copying from $file to $f_install_loc";
                            cp -v "$file" "$f_install_loc"
                        fi
                        break;;
                    [Vv]* ) cat "$f_install_loc";;
                    [Nn]* )
                        break;;
                    * ) echo "${RED} !! Please answer yes (y), view existing (v) or no (n).${RESET}";;
                esac
            done
            continue
        else
            # the file doesn't exist, so it should be safe to copy to
            # for safety, use cp -i, just incase something is wrong with the overwrite check above
            if [[ $IS_FRESH == "y" ]]; then
                cp() { env cp -v "$@"; }
            else
                cp() { env cp -vi "$@"; }
            fi
            cp "$file" "$f_install_loc"
            unset -f cp
        fi
        
    done
    msg
    msg cyan " >>> Installing extra vim files e.g. syntax highlighting (will make backups for overwritten files in ~/.backups/vim)"
    rsync --backup --suffix="-$(date +%Y-%m-%d)" --backup-dir "$HOME/.backups/vim/" -av "$LIB_DIR/extras/vim/" "$HOME/.vim/"
    if [[ -f /etc/zsh_command_not_found ]]; then
        echo "${YELLOW} -> Removing --no-failure-msg from /etc/zsh_command_not_found to prevent a blank message when a command is not found"
        sudo sed -i 's/--no-failure-msg //' /etc/zsh_command_not_found
    else
        echo "${YELLOW} !! Warning !! /etc/zsh_command_not_found was not found. You may want to edit it manually after zsh is launched."
        echo "           You should remove '--no-failure-msg' otherwise you will get a blank message when a command is not found${RESET}"
    fi
    echo "${GREEN} [+++] All config files installed.${RESET}"
    # Remove exit on error
    set +e
}

harden() {
    echo "${BLUE}Current SSH port:${RESET}"
    grep -E "Port [0-9]+" /etc/ssh/sshd_config
    read -p "${BLUE}Do you want to randomize the SSH port? (y/n)${RESET} > " chport
    if [[ "$chport" == "y" ]]; then
        export SSH_PORT=$(( ( RANDOM % 16383 )  + 49152 )) # random port for ssh
        sudo sed -i "/Port 22/c\Port ${SSH_PORT}" /etc/ssh/sshd_config
        echo SSH PORT: $SSH_PORT
    fi
    read -p "${BLUE}Do you want to turn off password auth? (y/n)${RESET} > " nopass
    if [[ "$nopass" == "y" ]]; then
        sudo sed -i "/PasswordAuthentication yes/c\PasswordAuthentication no" /etc/ssh/sshd_config
        echo "${YELLOW}Password authentication disabled. Please make sure you have a key in ~/.ssh/authorized_keys${RESET}"
    fi
    echo "Here are your currently installed SSH keys:"
    echo "=============================="
    echo "${BLUE}${BOLD} $HOME/.ssh/authorized_keys:${RESET}"
    cat ~/.ssh/authorized_keys
    echo "${BLUE}${BOLD} /root/.ssh/authorized_keys:${RESET}"
    sudo cat /root/.ssh/authorized_keys
    read -p "${BLUE}Do you want to restart SSH? (y/n)${RESET} > " rstssh
    if [[ "$rstssh" == "y" ]]; then
        echo "${YELLOW}Restarting SSH...${RESET}"
        sudo systemctl restart ssh
        echo "${GREEN}Done! Please make sure you can log in on port ${SSH_PORT} ${RESET}"
    fi

}


install_essential() {
    msg cyan " >>> Installing essential packages listed in INSTALL_PKGS..."
    if [[ "$APT_UPDATED" == "n" ]]; then
        msg bold blue "     > Updating apt repository data, please wait..."
        sudo apt update -qy &> /dev/null
        APT_UPDATED="y"
    fi
    # convert the array of packages into a flat string
    # so they can be passed as arguments to apt
    local pk_list=""
    local pipinst="n"
    for pk in "${INSTALL_PKGS[@]}"; do 
        if [[ "$pk" == "python3-pip" ]]; then
            pipinst="y"
        fi
        pk_list+=" $pk"; 
    done

    msg bold blue "     > Installing various packages, please wait..."
    DEBIAN_FRONTEND=noninteractive sudo apt-get -o Dpkg::Options::='--force-confold' -o Dpkg::Use-Pty=0 --force-yes install -qq -y $pk_list &>/dev/null
    # Only upgrade pip if we know it was installed
    if [[ "$pipinst" == "y" ]]; then
        # Upgrade pip
        msg blue "     > Upgrading Python3 pip..."
        sudo -H pip3 install -U pip
    fi
    msg bold green " [+++] Finished installing / updating essential packages.\n\n"

}

fix_locale() {
    echo
    echo "${RED} !! This tool will remove /etc/default/locale, re-generate it with en_US.UTF-8, then generate the locale.${RESET}"
    [[ "$IS_FRESH" == "n" ]] && read -p "${YELLOW}Do you want to continue? (y/n)${RESET} > " fxloc
    if [[ "$fxloc" == "y" || $IS_FRESH == "y" ]]; then
        echo "${CYAN} >> Making sure the 'locales' package is installed...${RESET}"
        apt-get install -qy locales &>/dev/null
        echo "${CYAN} >> Removing /etc/default/locale${RESET}"
        sudo rm /etc/default/locale
        echo "${CYAN} >> Generating /etc/default/locale${RESET}"
        cat << EOF | sudo tee /etc/default/locale
LANGUAGE=en_US.UTF-8
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
LC_CTYPE=en_US.UTF-8
EOF
        
        echo "${CYAN} >> Enabling locales in /etc/locale.gen specified in ENABLE_LOCALES  ${RESET}"
        for l in "${ENABLE_LOCALES[@]}"; do
            echo "${CYAN}     ... Uncommenting locales starting with $l ${RESET}"
            sudo sed -i "/^#.* ${l}.*/s/^# //g" /etc/locale.gen
        done
        echo "${CYAN} >> Re-generating locale files ${RESET}"
        sudo locale-gen
        source /etc/default/locale   # Load the locale file to correct the current locale env vars.
        echo "${GREEN}${BOLD}Finished. Your locale should be corrected now.${RESET}"
        echo "You may wish to restart your shell, or set the below variables in your existing session:"
        cat /etc/default/locale
    else
        echo "${YELLOW} !! Cancelled.${RESET}"
    fi
    echo
}

install_global() {
    local instovr="n" instglob="n" owgit='y'
    pkg_not_found rsync rsync
    pkg_not_found git git
    pkg_not_found zsh zsh
    pkg_not_found tmux tmux

    if ! has_command cpu-usage || ! has_command ram-usage; then
        msg yellow "Missing 'cpu-usage' or 'ram-usage' utility for custom tmux config."
        msg cyan "Calling install_utils to install them now..."
        install_utils
    fi

    echo
    msg red "This tool will install various dotfile configs globally, so they are used by default for all users."
    echo "Warnings will be given before overwriting the file."
    [[ $IS_FRESH == "n" ]] && read -p "${YELLOW}Do you want to continue? (y/N)${RESET} > " instglob
    if [[ "$instglob" == "y" || $IS_FRESH == "y" ]]; then
        [[ $IS_FRESH == "n" ]] && read -p "${YELLOW}Skip all warnings and overwrite WITHOUT asking? (y/N)${RESET} > " instovr
        [[ "$instovr" == "y" ]] && IS_FRESH='y'
        if [[ $IS_FRESH == "y" ]]; then
            cp() { sudo cp -v "$@"; }
        else
            cp() { sudo cp -vi "$@"; }
        fi
        mkdir -p "$HOME/.backups/vim" &> /dev/null

        msg yellow " >> Installing /etc/vim/vimrc.local"
        sudo mkdir /etc/vim &> /dev/null
        cp "$LIB_DIR/dotfiles/vimrc" /etc/vim/vimrc.local
        msg yellow " >> Installing extra vim files e.g. syntax highlighting (will make backups for overwritten files in ~/.backups/vim)"
        sudo rsync --backup --suffix="-$(date +%Y-%m-%d)" --backup-dir "$HOME/.backups/vim/" -av "$LIB_DIR/extras/vim/" /etc/vim/

        if [[ -d "/etc/.tmux" ]]; then
            msg yellow " [!!!] Folder /etc/.tmux already exists. Not cloning github.com/gpakosz/.tmux"
        else
            msg green " >>> Cloning github.com/gpakosz/.tmux into /etc/tmux"
            sudo git clone https://github.com/gpakosz/.tmux "/etc/tmux"
        fi

        msg yellow " >> Installing /etc/tmux.conf"
        cp "$LIB_DIR/extras/tmux.conf" /etc/tmux.conf

        msg yellow " >> Installing /etc/tmux.conf.local"
        cp "$LIB_DIR/dotfiles/tmux.conf.local" /etc/tmux.conf.local

        for u in "${INSTALL_USERS[@]}"; do
            [[ "$u" == "root" ]] && home_dir="/root" || home_dir="/home/${u}"
            if [[ ! -d "$home_dir" ]]; then
                msg yellow "        [...] User ${u} not found ( non-existent home folder '${home_dir}' ) - skipping"
                continue
            fi
            msg cyan "        [...] Linking /etc/tmux to ${home_dir}/.tmux"
            sudo ln -svi "/etc/tmux" "${home_dir}/.tmux"

            msg cyan "        [...] Linking /etc/tmux/.tmux.conf to ${home_dir}/.tmux.conf"
            sudo ln -svi "/etc/tmux/.tmux.conf" "${home_dir}/.tmux.conf"

            msg cyan "        [...] Copying $LIB_DIR/dotfiles/tmux.conf.local to ${home_dir}/.tmux.conf.local"
            sudo cp -vi "$LIB_DIR/dotfiles/tmux.conf.local" "${home_dir}/.tmux.conf.local"

            msg cyan "        [...] Fixing ownership of ${home_dir}/.tmux.conf.local"
            sudo chown "${u}:${u}" "${home_dir}/.tmux.conf.local"
        done

        if [[ -f /etc/gitconfig && $IS_FRESH == "n" ]]; then
            owgit='n'
            read -p "${YELLOW}/etc/gitconfig already exists... overwrite? (y/n)${RESET} > " owgit
        fi
        [[ "$owgit" == "y" ]] && cat << EOF | sudo tee /etc/gitconfig >/dev/null
[core]
	excludesfile = /etc/gitignore
EOF
        msg yellow " >> Installing /etc/gitignore"
        cp "$LIB_DIR/dotfiles/gitignore" /etc/gitignore
        
        msg yellow " >> Installing /etc/zsh/zsh_sg and /etc/skel/.zshrc"
        sudo mkdir /etc/zsh &> /dev/null
        cp "$LIB_DIR/extras/zshrc" /etc/zsh/zsh_sg
        cp "$LIB_DIR/extras/zsh_skel" /etc/skel/.zshrc


        msg yellow " >> Adding source line to /etc/zsh/zshrc"

        if grep -q "source /etc/zsh/zsh_sg" /etc/zsh/zshrc; then
            msg yellow " ... Skipping adding source line to /etc/zsh/zshrc as it's already there"
        else
            cat << "EOF" | sudo tee -a /etc/zsh/zshrc >/dev/null
# Load zshrc from @someguy123/someguy-scripts only if user has no .zshrc
if [[ ! -f "$HOME/.zshrc" ]]; then
    source /etc/zsh/zsh_sg
fi
EOF
        fi

        msg yellow " >> Installing folder /etc/zsh_files/"
        sudo mkdir /etc/zsh_files &> /dev/null
        cp -r "$LIB_DIR/zsh_files/"* /etc/zsh_files/
        
        if [[ -d "/etc/oh-my-zsh" ]]; then
            msg yellow " ... Skipping oh-my-zsh clone as /etc/oh-my-zsh already exists"
        else
            msg yellow " >> Cloning oh-my-zsh into /etc/oh-my-zsh/"
            sudo git clone --depth=1 https://github.com/robbyrussell/oh-my-zsh.git /etc/oh-my-zsh
        fi
        
        install_omz_themes

        msg bold green "Finished. The configs should now work for all users"
        msg red "NOTE: If a user has a .zshrc, the global zshrc should be ignored."
        msg red "      If it isn't, disable the global zshrc for a user by putting 'unset GLOBAL_RCS' into \$HOME/.zshenv"
    else
        msg bold yellow " !! Cancelled."
    fi
    [[ "$instovr" == "y" ]] && IS_FRESH='n'
    echo
}

fresh() {
    echo "${BLUE}Fresh install helper${RESET}"
    echo "${BOLD}${RED}WARNING! Various warnings such as overwrite confirmations will be disabled${RESET}"
    echo "This option will:
    - Fix locale problems (set the system locale to en_US.UTF-8)
    - Install useful packages
    - Install dotfiles / oh-my-zsh, while automatically overwriting on conflict
    - Install dotfiles / oh-my-zsh globally, again skipping conflict warnings
    - Harden the server (this will still confirm port change + ssh keys for safety)
    "
    read -p "${YELLOW}Do you want to continue? (y/n)${RESET} > " should_fresh
    if [[ "$should_fresh" == "y" ]]; then
        IS_FRESH="y"
        fix_locale
        install_essential
        install_global
        install_confs
        harden
    else
        echo "${YELLOW} !! Cancelled.${RESET}"
    fi
}

update_zshrc() {
    backupdst="${HOME}/.backups/zsh_sg-$(date +%Y-%m-%d)"
    msg bold yellow "Backing up the current zsh_sg into '${backupdst}' ..."
    msg
    mkdir -p "${HOME}/.backups" &> /dev/null
    cp -vi /etc/zsh/zsh_sg "$backupdst"
    msg
    msg yellow "Updating your global zshrc at '/etc/zsh/zsh_sg' by replacing it with '$LIB_DIR/extras/zshrc'..."
    msg
    sudo cp -v "$LIB_DIR/extras/zshrc" /etc/zsh/zsh_sg
    msg
    msg bold green "(+) Finished."
}

update_zshfiles() {
    local backup_dir="$HOME/.backups/etc/zsh_files/" out_dir="/etc/zsh_files/"
    if (( EUID != 0 )); then
        msg yellow " >> Detected non-root user. Updating local zsh_files instead of global zsh_files."
        msg yellow " >> If you want to update global zsh_files, run core.sh as root\n"
        sleep 2
        backup_dir="${HOME}/.backups/zsh_files/" out_dir="${HOME}/.zsh_files/"
    fi

    msg yellow " >> Updating folder $out_dir (replaced files will be backed up in ${backup_dir} before copying)"
    [[ ! -d "$out_dir" ]] && mkdir -v "$out_dir" || true
    [[ ! -d "$backup_dir" ]] && mkdir -pv "$backup_dir" || true
    rsync -avh --backup --suffix="-$(date +%Y-%m-%d)" --backup-dir "$backup_dir" --progress "$LIB_DIR/zsh_files/" "$out_dir"
    msg
    install_omz_themes
    msg bold green "(+) Finished."
}

install_utils() {
    local out_dir="/usr/local/bin"
    pkg_not_found bc bc

    if can_write "$out_dir"; then
        msg green " [+++] Detected global binary output folder '$out_dir' is writable by current user"
    else
        msg bold yellow " [!!!] Binary output folder '$out_dir' is not writable by current user."
        if has_sudo; then
            msg bold green " [+++] Detecting passwordless working sudo. Will install into $out_dir using sudo."
            install() { sudo install "$@"; }
        else
            msg bold yellow " [!!!] Sudo not available (or requires password)"
            msg bold yellow " [!!!] Will install binary utilities into ${HOME}/.local/bin instead."
            out_dir="${HOME}/.local/bin"
        fi
    fi

    if [[ ! -d "$out_dir" ]]; then
        msg yellow " [...] Folder $out_dir doesn't exist. Creating it..."
        mkdir -pv "$out_dir"
        msg yellow " [+++] Created folder $out_dir"
    fi
    msg green " >>> Installing binaries from ${LIB_DIR}/extras/utils into $out_dir "
    install -v "${LIB_DIR}/extras/utils"/* "$out_dir"
    msg green " >>> Installing privex-utils from ${LIB_DIR}/scripts/privex-utils"
    pkg_not_found python3 python3
    pkg_not_found pip3 python3-pip
    cd "${LIB_DIR}/scripts/privex-utils"
    sudo ./install.sh
    cd - &>/dev/null
    msg bold green " [+++] Finished\n"
}
