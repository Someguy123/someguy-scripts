#!/bin/bash
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
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Override where the dotfiles and zsh_files get copied to
# by using CONFIG_DIR=/where/you/want ./core.sh
: ${CONFIG_DIR="$HOME"}

. "$DIR/zsh_files/colors.zsh"  # Load terminal colors
. "$DIR/zsh_files/gnusafe.zsh" # GNU Tools Safety checker
# make sure we have gnu utilities, otherwise exit
gnusafe || return 1 2>/dev/null || exit 1

OMZSH_INSTALLED="n"
APT_UPDATED="n"
# set by 'fresh' function, bypasses overwrite confirmations etc.
IS_FRESH='n'

export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

finish() {
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
        env zsh -l
    fi
}

trap finish EXIT

pkg_not_found() {
    # check if a command is available
    # if not, install it from the package specified
    # Usage: pkg_not_found [cmd] [apt-package]
    # e.g. pkg_not_found git git
    if [[ $# -lt 2 ]]; then
        echo "${RED}ERR: pkg_not_found requires 2 arguments (cmd) (package)${NORMAL}"
        exit
    fi
    local cmd=$1
    local pkg=$2
    if ! [ -x "$(command -v $cmd)" ]; then
        echo "${YELLOW}WARNING: Command $cmd was not found. installing now...${NORMAL}"
        if [[ "$APT_UPDATED" == "n" ]]; then
            sudo apt update
            APT_UPDATED="y"
        fi
        sudo apt install -y "$pkg"
    fi
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
    TEST_CURRENT_SHELL=$(expr "$SHELL" : '.*/\(.*\)')
    if [ "$TEST_CURRENT_SHELL" != "zsh" ]; then
        if ! [ -x "$(command -v zsh)" ]; then
            echo "${RED}ERROR: zsh not found. not changing default shell.${NORMAL}"
            return 1
        fi
        # If this platform provides a "chsh" command (not Cygwin), do it, man!
        if hash chsh >/dev/null 2>&1; then
            printf "${BLUE}Time to change your default shell to zsh!${NORMAL}\n"
            sudo chsh -s $(grep /zsh$ /etc/shells | tail -1) $(whoami)
        # Else, suggest the user do so manually.
        else
            printf "I can't change your shell automatically because this system does not have chsh.\n"
            printf "${BLUE}Please manually change your default shell to zsh!${NORMAL}\n"
        fi
    fi
    OMZSH_INSTALLED="y"
}

######
# Install config files
#####
install_confs() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "Looks like oh-my-zsh isn't installed..."
        echo "Will now install it"
        install_omz
    fi
    # For safety, exit on non-zero
    set -e
    echo "${BLUE}Installing dotfiles...${RESET}"
    # first, see if there are any that will be overwritten and warn against it
    for file in $DIR/dotfiles/*; do
        [ -e "$file" ] || continue # protect against failed match returning glob
        # remove the path to the file so we can add a dot to the start
        filename=$(basename -- "$file")
        dotf=".$filename"
        f_install_loc="$CONFIG_DIR/$dotf"
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
    echo "${BLUE}Installing zsh_files...${RESET}"
    for file in $DIR/zsh_files/*; do
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
    if [[ -f /etc/zsh_command_not_found ]]; then
        echo "${YELLOW} -> Removing --no-failure-msg from /etc/zsh_command_not_found to prevent a blank message when a command is not found"
        sudo sed -i 's/--no-failure-msg //' /etc/zsh_command_not_found
    else
        echo "${YELLOW} !! Warning !! /etc/zsh_command_not_found was not found. You may want to edit it manually after zsh is launched."
        echo "           You should remove '--no-failure-msg' otherwise you will get a blank message when a command is not found${RESET}"
    fi
    echo "${GREEN}All config files installed.${RESET}"
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

# If INSTALL_PKGS is set from the environment, we should use that.
# If not, use our defaults.
if [ -z ${INSTALL_PKGS+x} ]; then 
    INSTALL_PKGS=(
        # General
        git curl wget
        # Session management
        tmux screen
        # Security
        iptables-persistent fail2ban
        # Network tools
        mtr-tiny iputils-ping nmap netcat dnsutils
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
    )
else 
    echo "${YELLOW}It looks like you've set INSTALL_PKGS in your environment."
    echo "We'll use the packages in there for our install_essential${RESET}"
    sleep 3
fi

install_essential() {
    echo "${BLUE}Installing various packages...${RESET}"
    if [[ "$APT_UPDATED" == "n" ]]; then
        sudo apt update
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
    sudo apt install -y $pk_list
    # Only upgrade pip if we know it was installed
    if [[ "$pipinst" == "y" ]]; then
        # Upgrade pip
        echo "${BLUE}Upgrading Python3 pip${RESET}"
        sudo -H pip3 install -U pip
    fi
}

fix_locale() {
    echo "${RED}This tool will remove /etc/default/locale, re-generate it with en_US.UTF-8, then generate the locale.${RESET}"
    [[ "$IS_FRESH" == "n" ]] && read -p "${YELLOW}Do you want to continue? (y/n)${RESET} > " fxloc
    if [[ "$fxloc" == "y" || $IS_FRESH == "y" ]]; then
        echo "${YELLOW} >> Removing /etc/default/locale${RESET}"
        sudo rm /etc/default/locale
        echo "${YELLOW} >> Generating /etc/default/locale${RESET}"
        cat << EOF | sudo tee /etc/default/locale
LANGUAGE=en_US.UTF-8
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
LC_CTYPE=en_US.UTF-8
EOF
        echo "${YELLOW} >> Re-generating en_US.UTF-8 locale files ${RESET}"
        sudo locale-gen en_US.UTF-8
        echo "${GREEN}Finished. Your locale should be corrected now.${RESET}"
        echo "You may wish to restart your shell, or set the below variables in your existing session:"
        cat /etc/default/locale
    else
        echo "${YELLOW} !! Cancelled.${RESET}"
    fi
}

install_global() {
    echo "${RED}This tool will install various dotfile configs globally, so they are used by default for all users.${RESET}"
    echo "Warnings will be given before overwriting the file."
    [[ $IS_FRESH == "n" ]] && read -p "${YELLOW}Do you want to continue? (y/n)${RESET} > " instglob
    if [[ "$instglob" == "y" || $IS_FRESH == "y" ]]; then
        if [[ $IS_FRESH == "y" ]]; then
            cp() { sudo cp -v "$@"; }
        else
            cp() { sudo cp -vi "$@"; }
        fi
        echo "${YELLOW} >> Installing /etc/vim/vimrc.local${RESET}"
        sudo mkdir /etc/vim > /dev/null
        cp "$DIR/dotfiles/vimrc" /etc/vim/vimrc.local

        echo "${YELLOW} >> Installing /etc/tmux.conf${RESET}"
        cp "$DIR/dotfiles/tmux.conf" /etc/tmux.conf
        owgit='y'
        if [[ -f /etc/gitconfig && $IS_FRESH == "n" ]]; then
            owgit='n'
            read -p "${YELLOW}/etc/gitconfig already exists... overwrite? (y/n)${RESET} > " owgit
        fi
        [[ "$owgit" == "y" ]] && cat << EOF | sudo tee /etc/gitconfig
[core]
	excludesfile = /etc/gitignore
EOF
        echo "${YELLOW} >> Installing /etc/gitignore${RESET}"
        cp "$DIR/dotfiles/gitignore" /etc/gitignore
        
        echo "${YELLOW} >> Installing /etc/zsh/zsh_sg${RESET}"
        sudo mkdir /etc/zsh > /dev/null
        cp "$DIR/dotfiles/zshrc" /etc/zsh/zsh_sg

        echo "${YELLOW} >> Adding source line to /etc/zsh/zshrc${RESET}"

        cat << "EOF" | sudo tee -a /etc/zsh/zshrc
# Load zshrc from @someguy123/someguy-scripts only if user has no .zshrc
if [[ ! -f "$HOME/.zshrc" ]]; then
    source /etc/zsh/zsh_sg
fi
EOF

        echo "${YELLOW} >> Installing folder /etc/zsh_files/${RESET}"
        sudo mkdir /etc/zsh_files > /dev/null
        cp -r "$DIR/zsh_files/*" /etc/zsh_files/
        
        echo "${YELLOW} >> Cloning oh-my-zsh into /etc/oh-my-zsh/${RESET}"        
        sudo git clone --depth=1 https://github.com/robbyrussell/oh-my-zsh.git /etc/oh-my-zsh

        echo "${GREEN}Finished. The configs should now work for all users${RESET}"
        echo "${RED}NOTE: If a user has a .zshrc, the global zshrc should be ignored."
        echo "      If it isn't, disable the global zshrc for a user by putting 'unset GLOBAL_RCS' into $$HOME/.zshenv${RESET}"
    else
        echo "${YELLOW} !! Cancelled.${RESET}"
    fi
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
        install_confs
        install_global
        harden
    else
        echo "${YELLOW} !! Cancelled.${RESET}"
    fi
}

while true; do
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
    ${GREEN}global${RESET} - Install dotfile configs globally
    ${GREEN}instconf${RESET} - Run inst, then conf after
    ${GREEN}hrd${RESET} - Harden the server (set SSH port, turn off password auth etc.)
    ${GREEN}fresh${RESET} - For fresh installs. Fix locale, install packages, configs, global configs, and harden
    ${GREEN}q${RESET} - Exit
"
    read -p "Menu > " menu_choice
    case $menu_choice in
        inst )
            install_essential;;
        conf )
            install_confs;;
        instconf )
            install_essential
            install_confs;;
        loc )
            fix_locale;;
        global )
            install_global;;
        fresh )
            fresh;;
        hrd )
            harden;;
        pk_list )
            echo "${GREEN}Packages that would be installed:${RESET}"
            for pk in "${INSTALL_PKGS[@]}"; do
                echo " - $pk"
            done
            echo;;
        [Qq] )
            exit;;
        * ) echo "${RED}Invalid menu option.${RESET}";;
    esac
done
