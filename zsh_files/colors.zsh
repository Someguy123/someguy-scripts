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

BOLD="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE="" RESET="" NORMAL=""
if [ -t 1 ]; then
    if command -v tput &>/dev/null; then
        BOLD="$(tput bold)" RED="$(tput setaf 1)" GREEN="$(tput setaf 2)" YELLOW="$(tput setaf 3)" BLUE="$(tput setaf 4)"
        PURPLE="$(tput setaf 5)" MAGENTA="$(tput setaf 5)" CYAN="$(tput setaf 6)" WHITE="$(tput setaf 7)"
        RESET="$(tput sgr0)" NORMAL="$(tput sgr0)"  
    else
        BOLD='\033[1m' RED='\033[00;31m' GREEN='\033[00;32m' YELLOW='\033[00;33m' BLUE='\033[00;34m'
        PURPLE='\033[00;35m' MAGENTA='\033[00;35m' CYAN='\033[00;36m' WHITE='\033[01;37m'
        RESET='\033[0m' NORMAL='\033[0m'
    fi
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
    local _color="" _dt="" _msg="" _bold=""
    if [[ "$#" -eq 0 ]]; then echo ""; return; fi;
    [[ "$1" == "ts" ]] && shift && _dt="[$(date +'%Y-%m-%d %H:%M:%S %Z')] " || _dt=""
    if [[ "$#" -gt 1 ]] && [[ "$1" == "bold" ]]; then
        _bold="${BOLD}"
        shift
    fi
    (($#==1)) || _msg="${@:2}"

    case "$1" in
        bold) _color="${BOLD}";;
        BLUE|blue) _color="${BLUE}";;
        YELLOW|yellow) _color="${YELLOW}";;
        RED|red) _color="${RED}";;
        GREEN|green) _color="${GREEN}";;
        CYAN|cyan) _color="${CYAN}";;
        MAGENTA|magenta|PURPLE|purple) _color="${MAGENTA}";;
        * ) _msg="$1 ${_msg}";;
    esac

    (($#==1)) && _msg="${_dt}$1" || _msg="${_color}${_bold}${_dt}${_msg}"
    echo -e "$_msg${RESET}"
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
export msg msgts msgerr RED GREEN YELLOW BLUE BOLD NORMAL RESET
#####
#
# This color code snippet was borrowed from oh-my-zsh's install script
# Please see OMZ_LICENSE.txt for a copy of the MIT license.
#####
