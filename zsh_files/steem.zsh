#!/usr/bin/env zsh
######################################################
#                         ##   Designed for ZSH.     #
# Steem RPC Shell Helpers ##   Requires: curl, jq    #
#    by @someguy123       ##   May or may not work   #
# steemit.com/@someguy123 ##   with bash.            #
#                         ##   License: GNU AGPLv3   #
######################################################


# The default RPC node to use for rpc-rq
# steemd.privex.io is a load balancer operated
# by @privex (Privex Inc.)
: ${DEFAULT_STM_RPC="https://steemd.privex.io"}

#####
# Helper function to perform a query against a STEEM RPC (see https://www.steem.io)
# Used by all of the other functions, e.g. rpc-get-time, rpc-get-block
# As this is used by the other functions, it's recommended to pipe into jq if using alone
# 
# === USAGE ===
#
# $ rpc-rq get_dynamic_global_properties
# Single arg: host=default, method=$1, params=[]
#
# $ rpc-rq https://steemd.privex.io get_dynamic_global_properties
# $ rpc-rq get_dynamic_global_properties '[]'
# Two args: Detects if first arg is host.
#   If host: host=$1, method=$2, params=[]
#   If not:  host=default, method=$1, params=$2
# 
# $ rpc-rq https://steemd.privex.io get_dynamic_global_properties '[]'
# Three args: host=$1 method=$2 params=$3
#
#####
rpc-rq() {
    local PARAMS="[]"
    # if 1 arg, 1 = method, params = default, host = default
    if [[ "$#" -eq 1 ]]; then
        local HOST="$DEFAULT_STM_RPC"
        local METHOD="$1"
    # if 2 arg, check if first param is a url
    elif [[ "$#" -eq 2 ]]; then
        # if url, then 1 = host, 2 = method, params = default
        if egrep -q "http(s)?://" <<< "$1"; then
            local HOST="$1"
            local METHOD="$2"
        # if not a url, then 1 = method, 2 = params, host = default
        else
            local HOST="$DEFAULT_STM_RPC"
            local METHOD="$1"
            local PARAMS="$2"
        fi
    # if all 3 args, 1 = host, 2 = method, 3 = params
    elif [[ "$#" -eq 3 ]]; then
        local HOST="$1"
        local METHOD="$2"
        local PARAMS="$3"
    fi
    local data="{\"jsonrpc\": \"2.0\", \"method\": \"$METHOD\", \"params\": $PARAMS, \"id\": 1 }"
    curl -s -S -f --data "$data" "$HOST"
    return $?
}

#####
# Queries an RPC server for the last block time.
# Useful for checking if a node is out of sync
#
# $ rpc-get-time https://steemd.privex.io
#    "2018-10-05T19:07:03"
#
#####
rpc-get-time() {
    local c;
    c=$(rpc-rq "$1" condenser_api.get_dynamic_global_properties)
    if [[ "$?" -ne 0 ]]; then
        echo "RPC NODE IS DEAD?"
        echo "$c"
    else
        jq ".result.time" <<< "$c"
    fi
}
#####
# Queries an RPC server for the last block number.
# Useful for checking if a node is out of sync
#
# $ rpc-get-block https://steemd.privex.io
#    26549337
#
#####
rpc-get-block() {
    local c;
    c=$(rpc-rq "$1" condenser_api.get_dynamic_global_properties)
    if [[ "$?" -ne 0 ]]; then
        echo "RPC NODE IS DEAD?"
        echo "$c"
    else
        echo "success?"
        jq .result.head_block_number <<< "$c"
    fi
}

#####
# Queries an RPC server for all dynamic properties
#
# $ rpc-get-all-dynamic https://steemd.privex.io
# {
#  "head_block_number": 26549358,
#  "head_block_id": "01951c6e21f05808c1180ff05783a4890372f934",
#  "time": "2018-10-05T19:09:24",
#  "current_witness": "someguy123",
#  "total_pow": 514415,
#  ...
# }
#
#####
rpc-get-all-dynamic() {
    local c;
    c=$(rpc-rq "$1" condenser_api.get_dynamic_global_properties)
    if [[ "$?" -ne 0 ]]; then
        echo "RPC NODE IS DEAD?"
        echo "$c"
    else
        echo "success?"
        jq .result <<< "$c"
    fi
}

