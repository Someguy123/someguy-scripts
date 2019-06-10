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

if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    BOLD="$(tput bold)"
    NORMAL="$(tput sgr0)"
    RESET="$(tput sgr0)"
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    NORMAL=""
    RESET=""
fi

# easy coloured messages function
# written by @someguy123
function msg () {
    # usage: msg [color] message
    if [[ "$#" -eq 0 ]]; then echo ""; return; fi;
    if [[ "$#" -eq 1 ]]; then
        echo "$1"
        return
    fi
    if [[ "$#" -gt 2 ]] && [[ "$1" == "bold" ]]; then
        echo -n "${BOLD}"
        shift
    fi
    case "$1" in
        bold) echo "${BOLD}${@:2}${RESET}";;
        [Bb]*) echo "${BLUE}${@:2}${RESET}";;
        [Yy]*) echo "${YELLOW}${@:2}${RESET}";;
        [Rr]*) echo "${RED}${@:2}${RESET}";;
        [Gg]*) echo "${GREEN}${@:2}${RESET}";;
        * ) echo "${@:2}";;
    esac
}
# make msg + colors available to subshells
# use -f for msg if using bash
export msg RED GREEN YELLOW BLUE BOLD NORMAL RESET
#####
#
# This color code snippet was borrowed from oh-my-zsh's install script
# Please see OMZ_LICENSE.txt for a copy of the MIT license.
#####
