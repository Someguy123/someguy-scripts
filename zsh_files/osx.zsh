#!/usr/bin/env zsh
#####
# OSX Specific functions
# Protected behind a uname check, to avoid
# breaking linux systems (e.g. the ip function)
#
# Written by: @someguy123 (github.com/@someguy123)
# License: GNU AGPLv3
#####

#####
# Uses OSX's cksum with perl to get a hex
# crc32 sum, instead of decimal
# Original source: https://hints.macworld.com/article.php?story=20041227082911874
#
# Usage:
#   $ echo hello > test.txt
# Get hash, length (same as wc -c), filename:
#   $ crc32 test.txt
#   363a3020 6 test.txt
# Get just the hash by itself:
#   $ crc32 test.txt | awk '{ print $1 }'
#   363a3020
#
#####
function crc32 {
    cksum -o3 "$@"|perl -wane 'printf "%0x %d %s\n",@F';
}

#####
# Emulate the classic "service" command from Linux
# Depends on Homebrew (https://brew.sh) as it uses
# "brew services" to get service information
#
# No need to worry about which order, whether it's
# action or service first. This will figure it out
# automatically. (unless you're crazy enough to have
# a service called "start", "stop", "status" etc.)
# 
# Usage:
#     $ service start mysql
#     $ service mysql stop
#     $ service status
#     $ service mysql status
#     $ service restart mysql
#
#####
function service () {
    local service_name="$1"
    local service_action="$2"
    # handle "status" on either side
    if [[ "$1" == "status" || "$2" == "status" ]]; then
        brew services list
        return
    fi
    if [[ "$#" -lt 2 ]]; then
        brew services "$1"
        return
    fi
    # handle inverted "service start fail2ban"
    case "$service_name" in
        start) brew services "$service_name" "$service_action"; return;;
        restart) brew services "$service_name" "$service_action"; return;;
        stop) brew services "$service_name" "$service_action"; return;;
        # if there's no match, then the command was typed the other way around
    esac
    # handle normal "service fail2ban start"
    brew services "$service_action" "$service_name"
}


# For OSX only.
# Because I keep typing 'ip addr' like on linux
# might as well alias it (aliases don't work with ifconfig, thus the function)
#
# Don't expect this to do anything fancy, it just runs ifconfig when you
# type ip [anything], to deal with my habit of typing "ip addr" to get the
# network interface details.
ip () {
  ifconfig
}

