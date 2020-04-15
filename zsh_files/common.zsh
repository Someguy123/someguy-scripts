#!/usr/bin/env zsh

# yesno [question]
# 
#   if yesno "Are you sure?"; then
#       echo "you said yes"
#   else
#       echo "you said no"
#   fi
#
yesno() {
    local answer="" question="$1"

    while true; do
        answer=""
        vared -p "$1 ${RESET}(y/n) " -c answer
        case "$answer" in
            y|Y|yes|YES|Yes|ye|YE)
                return 0
                ;;
            n|N|no|NO|No|nope|NOPE)
                return 1
                ;;
            *)
                msg yellow "\nPlease enter y, yes, n, or no\n"
                continue
                ;;
        esac
    done
}

