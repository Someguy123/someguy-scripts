#!/usr/bin/env zsh
#####
#
# Terminal colours such as $RED, $GREEN, $YELLOW
# Part of someguy-shell which is 
# written by @someguy123 (github.com/@someguy123)
#
# Borrowed from: github.com/robbyrussel/oh-my-zsh
# License: MIT (see bottom of file)
#####

# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if which tput >/dev/null 2>&1; then
    ncolors=$(tput colors)
fi

if [ -t 1 ]; then
    BOLD="$(tput bold)" RED="$(tput setaf 1)" GREEN="$(tput setaf 2)" YELLOW="$(tput setaf 3)" BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)" CYAN="$(tput setaf 6)" WHITE="$(tput setaf 7)" RESET="$(tput sgr0)" NORMAL="$(tput sgr0)"
else
    BOLD="" RED="" GREEN="" YELLOW="" BLUE=""
    MAGENTA="" CYAN="" WHITE="" RESET="" NORMAL=""
fi


#####
# Easy coloured messages function
# Written by @someguy123
# Usage:
#   # Prints "hello" and "world" across two lines in the default terminal color
#   msg "hello\nworld"
#
#   # Prints "    this is an example" in green text
#   msg green "\tthis" is an example
#
#   # Prints "An error has occurred" in bold red text
#   msg bold red "An error has occurred"
#
#####
function msg () {
    if [[ "$#" -eq 0 ]]; then echo ""; return; fi;
    if [[ "$#" -eq 1 ]]; then
        echo -e "$1"
        return
    fi
    [[ "$1" == "ts" ]] && shift && _msg="[$(date +'%Y-%m-%d %H:%M:%S %Z')] " || _msg=""
    if [[ "$#" -gt 2 ]] && [[ "$1" == "bold" ]]; then
        echo -n "${BOLD}"
        shift
    fi
    (($#==1)) && _msg+="$@" || _msg+="${@:2}"

    case "$1" in
        bold) echo -e "${BOLD}${_msg}${RESET}";;
        BLUE|blue) echo -e "${BLUE}${_msg}${RESET}";;
        YELLOW|yellow) echo -e "${YELLOW}${_msg}${RESET}";;
        RED|red) echo -e "${RED}${_msg}${RESET}";;
        GREEN|green) echo -e "${GREEN}${_msg}${RESET}";;
        CYAN|cyan) echo -e "${CYAN}${_msg}${RESET}";;
        MAGENTA|magenta|PURPLE|purple) echo -e "${MAGENTA}${_msg}${RESET}";;
        * ) echo -e "${_msg}";;
    esac
}

# Alias for 'msg' function with timestamp on the left.
function msgts () {
    msg ts "${@:1}"
}

function msgerr () {
    # Same as `msg` but outputs to stderr instead of stdout
    >&2 msg "$@"
}

# make msg + colors available to subshells
# use -f for msg if using bash
export msg RED GREEN YELLOW BLUE BOLD NORMAL RESET
#####
#
# This color code snippet was borrowed from oh-my-zsh's install script
# Please see OMZ_LICENSE.txt for a copy of the MIT license.
#####
