#!/usr/bin/env zsh
#####
# SSH helper functions
# Two functions (await-ssh and ssh-reset) to make using
# ssh much easier.
# - await-ssh   A function to ssh into a server when it's back online.
# - ssh-reset   Quickly remove a host from your .ssh/known_hosts (with backup and removal count)
# See the block comments above them for more info
#
# Written by: @someguy123 (github.com/@someguy123)
# License: GNU AGPLv3
#####

#####
# $ await-ssh user@host [-p [port]]
# $ await-ssh host_in_sshconfig
# Wait for a server to come back online and then ssh into it.
# Uses the .ssh/config database to find saved info.
# Additional pararms such as -p can be specified and will be
# passed onto ssh
#####
function await-ssh {
    # Full user@host passed on the command line
    local host="$1";
    # Just the hostname
    local hostname;
    # Username extracted from ssh -G
    local user;
    # Port determined from ssh -G
    local port;

    # Alternative method of extracting user/host via GNU sed
    #   username=$(gsed -rn 's/([a-zA-Z0-9-]+)@?(.*)/\1/p' <<< "$1")
    #   pipe into wc -c; if > 1 then there's a host/user
    #   hostname=$(gsed -rn 's/([a-zA-Z0-9-]+)@?(.*)/\2/p' <<< "$1")

    # Check what username / host / port we would use
    local sdbo=$(ssh -G "$host")
    hostname=$(awk '/^hostname / { print $2 }' <<< "$sdbo")
    user=$(awk '/^user / { print $2 }' <<< "$sdbo")
    port=$(awk '/^port / { print $2 }' <<< "$sdbo")

    echo "Waiting for ${user}@${hostname} on port ${port} to come back online"
    # ping -o = exit after getting a reply
    ping -o "$hostname" > /dev/null
    echo "Host ${hostname} appears online. Waiting a few seconds before connecting"
    sleep 3
    # disable strict host key checking, in the event this is a server being re-installed
    # avoids stupid "host not trusted error"
    local extra_args=""
    extra_args+="-o UserKnownHostsFile=/dev/null "
    extra_args+="-o StrictHostKeyChecking=no "
    extra_args+="-o ConnectTimeout=3 "
    # pass any additional arguments to ssh, e.g. -p 1234
    ssh $extra_args "$host" ${@:2}
    if [[ "$?" -ne 0 ]]; then
        echo "SSH returned non-zero code. Re-trying"
        await-ssh "$@"
    fi
}

#####
# $ ssh-reset 127.0.0.1
# $ ssh-reset localhost
# Makes a backup copy and removes any lines matching
# the passed host from ~/.ssh/known_hosts
# Prints out how many lines were removed, so you can detect any
# errors and recover the backup file.
#####
function ssh-reset () {
    gnusafe || return 1 # Depends on GNU sed. Use GNU safety checker
    if [[ "$#" -lt 1 ]]; then
        echo "Usage: $0 [ip/hostname]"
        echo "ssh-reset removes a host from ~/.ssh/known_hosts, e.g. after a re-format"
        return
    fi
    local host="$1"
    local known_hosts="$HOME/.ssh/known_hosts"
    local orig_count=$(wc -l "$known_hosts" | awk '{ print $1 }')
    local backupfile="/tmp/known_hosts-$(date +'%Y-%m-%d_(%H-%M-%S)%z')"
    echo "Backuping up $known_hosts to $backupfile"
    cp -v "$known_hosts" "$backupfile"
    if [[ "$?" -ne 0 ]]; then
        echo "Backup failed... aborting!"
        return 255
    fi
    echo "Removing host $host"
    gsed -i "/$host/d" ~/.ssh/known_hosts
    local new_count=$(wc -l "$known_hosts" | awk '{ print $1 }')
    echo "Lines removed: $((orig_count-new_count))"
    echo "Backup file @ $backupfile"
}


