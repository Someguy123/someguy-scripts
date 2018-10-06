#!/usr/bin/env zsh
#####
#
# A ZSH hook to warn you if you've edited .zshrc
# so you can decide whether to reload or not
#
# Written by @someguy123 (github.com/@someguy123)
# License: GNU AGPLv3
#
#####

autoload -Uz add-zsh-hook

rldzsh () {
    source ~/.zshrc
    echo "re-loaded .zshrc"
}

# store the last command globally, so z-need-reload
# can check it when the comamnd has finished
function log-last-cmd () {
    Z_LAST_CMD="${(qqq)1}"
}
# prompt to reload zsh if editing a .zshrc
function z-need-reload () {
    if egrep -q "(^zshrc$)|(vim .*(\.zshrc|\.zsh_files))" <<< "$Z_LAST_CMD"; then
        echo
        echo "${RED}$LINE"
        echo
        echo "   !!! You just edited a zsh file !!!"
        echo
        echo "$LINE${RESET}"
        echo
        read "yn?Reload .zshrc? (y/n)> "
        case $yn in
            [Yy]* )
                rldzsh
                ;;
            [Nn]* )
                echo "${YELLOW}Not reloading zshrc${RESET}"
                ;;
            * ) 
                echo "${RED}Invalid input. not reloading...${RESET}"
                ;;
        esac
    fi
}

add-zsh-hook precmd z-need-reload
add-zsh-hook preexec log-last-cmd
