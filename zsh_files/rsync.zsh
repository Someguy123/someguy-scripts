#!/usr/bin/env zsh
#####
# Rsync helper function
# Because I'm tired of typing "-av --progress"
# and even more tired of the clunky "--rsh 'ssh -p 12345'"
#
# Written by: @someguy123 (github.com/@someguy123)
# License: GNU AGPLv3
#####

#####
# brsync - Better RSync
#
# $ brsync root@1.2.3.4:/myfolder localfolder
# Equivalent to: 
#     rsync --rsh="ssh -p 22" -av --progress root@1.2.3.4:/myfolder localfolder
#
# $ brsync port 1234 root@1.2.3.4:/myfolder localfolder
# Equivelant to:
#     rsync --rsh="ssh -p 1234" -av --progress root@1.2.3.4:/myfolder localfolder
#####

brsync() {
    local ARGS;
    local PORT="22";
    if [[ "$#" -lt 2 ]]; then
        echo "
${RED}Error:${RESET} Invalid usage.
${GREEN}Usage:${RESET} $0 [port 1234] from to

${GREEN}Remote Example: ${RESET}
    brsync root@1.2.3.4:/myfolder/ localfolder
${BLUE}Runs: ${RESET}
    rsync --rsh=\"ssh -p 22\" -av --progress root@1.2.3.4:/myfolder/ localfolder

${GREEN}Local Example: ${RESET}
    brsync /home/myuser/ /backup/myuserbackup
${BLUE}Runs:${RESET}
    rsync -av --progress /home/myuser/ /backup/myuserbackup

${GREEN}Remote Example (with port): ${RESET}
    brsync port 1234 root@1.2.3.4:/myfolder/ localfolder
${BLUE}Runs: ${RESET}
    rsync --rsh=\"ssh -p 1234\" -av --progress root@1.2.3.4:/myfolder/ localfolder
"

        return
    fi
    if [[ "$1" == "port" ]]; then
        PORT="$2"
        ARGS="${@:3}"
    else
        ARGS="${@:1}"
    fi
    ARGS="-av --progress $ARGS"
    # Regex to determine if something matches user@host:/files
    # so we can decide if something is local or remote
    local IS_HOST="([a-zA-Z0-9-]+)@([a-zA-Z0-9-]+):.*"
    if egrep -q "$IS_HOST" <<< "$ARGS"; then
        eval "rsync --rsh=\"ssh -p $PORT\" $ARGS"
    else
        eval "rsync $ARGS"
    fi
}
