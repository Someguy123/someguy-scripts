#!/usr/bin/env zsh
######################################################
#                         ##   Designed for ZSH.     #
# Steem RPC Shell Helpers ##   Requires: curl, jq    #
#    by @someguy123       ##   May or may not work   #
# steemit.com/@someguy123 ##   with bash.            #
#                         ##   License: GNU AGPLv3   #
######################################################

_SDIR=${(%):-%N}
_STM_DIR="$( cd "$( dirname "${_SDIR}" )" && pwd )"

source "${_STM_DIR}/time.zsh"

# The default RPC node to use for rpc-rq
# hived.privex.io is a load balancer operated
# by @privex (Privex Inc.)
: ${DEFAULT_STM_RPC="https://hived.privex.io"}

export LAST_STM_NODE
# [ -z ${LAST_STM_NODE+x} ] && export LAST_STM_NODE="$DEFAULT_STM_RPC"
# : ${LAST_STM_NODE="$DEFAULT_STM_RPC"}

export RPC_HOST="$DEFAULT_STM_RPC" RPC_PARAMS="[]" RPC_METHOD=""

: ${RPC_VERBOSE=0}

# _verb_msg [is_verbose] [msg_args...]
# Calls 'msgerr' with msg_args if is_verbose is non-zero or 'y'
# which outputs a coloured message to stderr
_verb_msg() {
    local is_verbose="$1"
    shift
    if (( is_verbose )) || [[ "$is_verbose" == "y" ]]; then
        msgerr "$@"
    fi
}

_rpc-rq-argparse() {
    RPC_HOST="$DEFAULT_STM_RPC"
    RPC_PARAMS="[]"
    _verb_msg "$vrb" blue " [DEBUG] _rpc-rq-argparse arguments: $*"
    if [[ "$#" -eq 1 ]]; then
        RPC_METHOD="$1"
        _verb_msg "$vrb" blue " [DEBUG] One argument detected. Using DEFAULT_STM_RPC (${RPC_HOST}) as HOST, " \
                              "default parameters '${RPC_PARAMS}', and 1st argument '${RPC_METHOD}' as the RPC method. "
    # if 2 arg, check if first param is a url
    elif [[ "$#" -eq 2 ]]; then
        # if url, then 1 = host, 2 = method, params = default
        if egrep -q "http(s)?://" <<< "$1"; then
            RPC_HOST="$1" RPC_METHOD="$2"
            _verb_msg "$vrb" blue " [DEBUG] Two arguments detected. First argument is valid URL - using 1st arg as host '${RPC_HOST}'. " \
                                  "Using 2nd argument '${RPC_METHOD}' as the RPC method. Using default parameters '${RPC_PARAMS}'"
        # if not a url, then 1 = method, 2 = params, host = default
        else
            RPC_METHOD="$1" RPC_PARAMS="$2"
            _verb_msg "$vrb" blue " [DEBUG] Two arguments detected. First argument not a valid URL - using DEFAULT_STM_RPC as host '${RPC_HOST}'. " \
                                  "Using 1st arg '${RPC_METHOD}' as the RPC method. Using 2nd arg for parameters '${RPC_PARAMS}'"
        fi
    # if all 3 args, 1 = host, 2 = method, 3 = params
    elif [[ "$#" -eq 3 ]]; then
        RPC_HOST="$1" RPC_METHOD="$2" RPC_PARAMS="$3"
        _verb_msg "$vrb" blue " [DEBUG] Three arguments detected. Not using any defaults - only user args."
        _verb_msg "$vrb" blue " [DEBUG] Using 1st as host '${RPC_HOST}'. Using 2nd arg '${RPC_METHOD}' as the RPC method. Using 3rd arg for parameters '${RPC_PARAMS}'"
    fi
    export LAST_STM_NODE="$HOST"
    echo "$RPC_HOST"
    echo "$RPC_METHOD"
    echo "$RPC_PARAMS"
}

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
    local vrb=0
    (( RPC_VERBOSE )) && vrb=1
    if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
        vrb=1
        shift
    fi

    if [[ "$#" -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        echo "
=== USAGE ===
 Current default RPC: $DEFAULT_STM_RPC
 $ rpc-rq get_dynamic_global_properties
 Single arg: host=default, method=\$1, params=[]

 $ rpc-rq https://hived.privex.io get_dynamic_global_properties
 $ rpc-rq get_dynamic_global_properties '[]'
 Two args: Detects if first arg is host.
   If host: host=\$1, method=\$2, params=[]
   If not:  host=default, method=\$1, params=\$2
 
 $ rpc-rq https://hived.privex.io get_dynamic_global_properties '[]'
 Three args: host=\$1 method=\$2 params=\$3
"
        return 1
    fi

    _rpc-rq-argparse "$@" > /dev/null
    local HOST="$RPC_HOST" METHOD="$RPC_METHOD" PARAMS="$RPC_PARAMS"
    local data="{\"jsonrpc\": \"2.0\", \"method\": \"$METHOD\", \"params\": $PARAMS, \"id\": 1 }"
    export LAST_STM_NODE="$HOST"
    # export LAST_STM_NODE
    _verb_msg "$vrb" yellow "Querying RPC node ${HOST} using method '${METHOD}' and parameters '${PARAMS}'"
    _verb_msg "$vrb" cyan "POST data: ${BOLD}${data}"
    # s = silent, S = show errors when silent, f = fail silently and return error code 22 on error
    if (( vrb )); then
        curl -v --data "$data" "$HOST"
        return $?
    else
        curl -s -S -f --data "$data" "$HOST"
        return $?
    fi
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

    if (( $# > 0 )) && { [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; }; then
        msgerr cyan "Usage: $0 (host)\n"
        msgerr yellow "    Returns the head block for a given RPC node."
        msgerr yellow "    If 'host' isn't specified, it will fallback to DEFAULT_STM_RPC (current value: '${DEFAULT_STM_RPC}')"
        msgerr
        return 1
    fi

    (( $# > 0 )) && [[ "$1" == "-v" || "$1" == "--verbose" ]] && RPC_VERBOSE=1
    local q_cmd="condenser_api.get_dynamic_global_properties" ret
    _rpc-cmd-wrapper "$q_cmd" '[]' '.result.time' "$@"
    ret="$?"
    RPC_VERBOSE=0
    return $ret
}


#####
# rpc-get-block (host)
#   Queries an RPC server for the last block number.
#   Useful for checking if a node is out of sync
#
# rpc-get-block (host) [block_num]
#   Retrieves the contents of 'block_num'. 
#
# $ rpc-get-block
#    26549337
# $ rpc-get-block https://steemd.privex.io
#    26549337
# $ rpc-get-block 12341234
#    {
#       "previous": "00bc4ff1e4700955d3fcf14fff15bbb63a6ab76e",
#       "timestamp": "2017-05-29T02:46:30", "witness": "anyx",
#       "transaction_merkle_root": "6615362495dfd5018ea8999840557248f3118380",
#       "extensions": [], "witness_signature": "1f62ea225501b4a9...",
#       "transactions": [
#           { "ref_block_num": 20464, ... },
#        ]
#    }
#
# $ rpc-get-block https://hived.hive-engine.com 12341234
#    (same as previous, but gets the block contents from RPC node https://hived.hive-engine.com instead of DEFAULT_STM_RPC)
#
#####
rpc-get-block() {
    local c ret q_cmd="condenser_api.get_dynamic_global_properties" j_query=".result.head_block_number"
    local q_host="${DEFAULT_STM_RPC}"

    if (( $# > 0 )) && { [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; }; then
        msgerr cyan "Usage: $0 (host)\n"
        msgerr yellow "    Returns the head block for a given RPC node."
        msgerr yellow "    If 'host' isn't specified, it will fallback to DEFAULT_STM_RPC (current value: '${DEFAULT_STM_RPC}')\n"
        msgerr bold magenta "Examples\n"
        msgerr magenta "    $ rpc-get-block https://steemd.privex.io"
        msgerr magenta "    43282919"
        msgerr magenta "    $ rpc-get-block https://hived.privex.io"
        msgerr magenta "    43309827\n"

        msgerr cyan "Usage: $0 (host) [block_num]\n"
        msgerr yellow  "    Retrieves the contents of 'block_num'. Optionally specify an RPC node URL before the block number"
        msgerr yellow  "    to call get_block against that RPC node instead of DEFAULT_STM_RPC"
        msgerr 
        msgerr bold magenta "Examples\n"
        msgerr magenta '    $ rpc-get-block 12341234'
        msgerr magenta '    {'
        msgerr magenta '        "previous": "00bc4ff1e4700955d3fcf14fff15bbb63a6ab76e",'
        msgerr magenta '        "timestamp": "2017-05-29T02:46:30", "witness": "anyx",'
        msgerr magenta '        "transaction_merkle_root": "6615362495dfd5018ea8999840557248f3118380",'
        msgerr magenta '        "extensions": [], "witness_signature": "1f62ea225501b4a9...",'
        msgerr magenta '        "transactions": ['
        msgerr magenta '            { "ref_block_num": 20464, ... },'
        msgerr magenta '        ]'
        msgerr magenta "    }\n"
        msgerr magenta '    $ rpc-get-block https://hived.hive-engine.com 12341234'
        msgerr magenta '    (same as previous, but gets the block contents from RPC node https://hived.hive-engine.com instead of DEFAULT_STM_RPC)'
        msgerr
        return 1
    fi

    (( $# > 0 )) && [[ "$1" == "-v" || "$1" == "--verbose" ]] && RPC_VERBOSE=1 && shift
    _args=("$@")
    for i in {1..$#_args}; do
        _verb_msg "$RPC_VERBOSE" yellow " [rpc-get-block] Arg ${i}: ${_args[$i]}"
    done
    local params="[]"

    if (( ${#_args} > 0 )); then
        if ! egrep -q '^http' <<< "${_args[1]}" && (( $((_args[1])) > 0 )); then
            params="[${_args[1]}]" q_cmd="condenser_api.get_block" j_query=".result"
            _verb_msg "$RPC_VERBOSE" yellow " [rpc-get-block] Argument 1 > 0: ${_args[1]}"
        else
            q_host="${_args[1]}"
            if (( ${#_args} > 1 )) && ! egrep -q '^http' <<< "${_args[2]}" && (( $((_args[2])) > 0 )); then
                _verb_msg "$RPC_VERBOSE" yellow " [rpc-get-block] Argument 2 > 0: ${_args[2]}"
                params="[${_args[2]}]" q_cmd="condenser_api.get_block" j_query=".result"
            fi
        fi
    fi
    _verb_msg "$RPC_VERBOSE" yellow " [rpc-get-block] Host: ${q_host} Params: ${params} CMD: ${q_cmd} Query: ${j_query}"

    _rpc-cmd-wrapper "$q_cmd" "$params" "$j_query" "$q_host"
    ret=$?
    RPC_VERBOSE=0
    return $ret
}

: ${USE_JQ_RAW=1}

[ -z ${JQ_PARAMS+x} ] && JQ_PARAMS=()
[ -z ${_JQ_PARAMS+x} ] && _JQ_PARAMS=()

# hasElement [element] [array_name]
#
#   $ myray=(hello world)
#   $ hasElement hello myray && echo "true" || echo "false"
#   true
#   $ hasElement orange myray && echo "true" || echo "false"
#   false
#   $ hasElement world myray && echo "true" || echo "false"
#   true
#
# orig source: https://unix.stackexchange.com/a/411307/166253
hasElement() {
    local param_el="$1" array_name="$2" _arr
    # Lookup variable with name '$array_name', obtain it's contents, and re-create the array
    # into the local _arr variable for sanity.
    _arr=("${(P)${array_name}[@]}")
    # Check if our local _arr array contains the element $param_el
    [[ ${_arr[(ie)$param_el]} -le ${#_arr} ]]
}

# _jq-hasparam [item]
# Returns truthy if JQ_PARAMS contains $1
#   $ JQ_PARAMS=('-r')
#   $ _jq-hasparam '-r' && echo "true" || echo "false"
#   true
#   $ _jq-hasparam '-k' && echo "true" || echo "false"
#   false
#
_jq-hasparam() {
    local param_el="$1" array_name="JQ_PARAMS"
    (( $# > 1 )) && array_name="$2"
    hasElement "$param_el" "$array_name"
}

_jq-call() {
    _JQ_PARAMS=("${JQ_PARAMS[@]}")

    if (( USE_JQ_RAW )); then
        _verb_msg "$RPC_VERBOSE" bold cyan " [-jq_call] USE_JQ_RAW is enabled"

        _jq-hasparam -r _JQ_PARAMS || _JQ_PARAMS+=(-r)
    fi
    if (( $# < 1 )); then
        msgerr red " [!!!] _jq-call expects at least 1 param!"
        return 1
    fi

    local jqr="." data=""
    (( $# > 0 )) && jqr="$1"
    (( $# > 1 )) && data="$2"
    _JQ_PARAMS+=("$jqr")

    _verb_msg "$RPC_VERBOSE" bold cyan " [-jq_call] _JQ_PARAMS = ${_JQ_PARAMS[*]}"
    if [[ -z "$data" ]]; then
        _verb_msg "$RPC_VERBOSE" bold cyan " [-jq_call] \$data was empty. calling jq without feeding data (use pipe?)"
        jq "${_JQ_PARAMS[@]}"
        ret=$?
    else
        _verb_msg "$RPC_VERBOSE" bold cyan " [-jq_call] \$data is not empty. feeding in JSON data: $data"
        jq "${_JQ_PARAMS[@]}" <<< "$data"
        ret=$?
    fi
    
    _JQ_PARAMS=()
    return $ret
}

# _rpc-cmd-wrapper rpc_method rpc_params jq_query [rpc-rq params...]
# example:
#   _rpc-cmd-wrapper condenser_api.get_version '[]' '.result.blockchain_version' https://hived.privex.io
_rpc-cmd-wrapper() {
    local rpcverbose=0
    (( $# > 0 )) && [[ "$1" == "-v" || "$1" == "--verbose" ]] && rpcverbose=1 && RPC_VERBOSE=1 && shift
    local q_cmd="$1" q_params="$2" jq_query="$3"
    shift; shift; shift;

    (( $# > 0 )) && [[ "$1" == "-v" || "$1" == "--verbose" ]] && rpcverbose=1 && RPC_VERBOSE=1

    _rpc-rq-argparse "$@" "$q_cmd" "$q_params" &> /dev/null
    c=$(rpc-rq "$@" "$q_cmd" "$q_params")
    ret=$?
    if (( ret )); then
        msgerr bold red "\nGot non-zero return code from cURL (code: $ret). RPC node '${LAST_STM_NODE}' is dead?\n"
        msgerr red "Error result from server:\n"
        echo "$c"
        return $ret
    else
        err_msg=$(jq -r ".error.message" <<< "$c")
        if [[ "$err_msg" != "null" && "$err_msg" != "false" ]]; then
            msgerr bold red " [!!!] The server '${LAST_STM_NODE}' returned an error while querying method '${q_cmd}'!"
            msgerr bold red " [!!!] The RPC node ${LAST_STM_NODE} may be malfunctioning, or an invalid method / parameters were specified.\n"
            msgerr yellow "Error message from server:\n"
            msgerr "\t${err_msg}\n\n"
            return 1
        fi
        _verb_msg "$rpcverbose" bold cyan "Extracted ${jq_query} from ${q_cmd} (via '${LAST_STM_NODE}'):"
        _jq-call "$jq_query" "$c"
        ret="$?"

        if (( ret )); then
            msgerr bold red "\n [!!!] Got non-zero return code from jq (code: $ret). Failed to decode JSON?"
            msgerr bold red " [!!!] The RPC node ${LAST_STM_NODE} may be malfunctioning, or an invalid method / parameters were specified.\n"
            # return $ret
        fi
    fi
    return $ret
}

rpc-get-version() {
    _rpc-cmd-wrapper condenser_api.get_version '[]' '.result.blockchain_version' "$@"
    RPC_VERBOSE=0
}

#####
# Queries an RPC server for all dynamic properties
# If node not specified, uses DEFAULT_STM_RPC
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
    (( $# > 0 )) && [[ "$1" == "-v" || "$1" == "--verbose" ]] && RPC_VERBOSE=1
    local c ret q_cmd="condenser_api.get_dynamic_global_properties"

    _rpc-cmd-wrapper condenser_api.get_dynamic_global_properties '[]' '.result' "$@"
    RPC_VERBOSE=0
}

rpc-health() {
    local q_host="$DEFAULT_STM_RPC"
    (( $# > 0 )) && [[ "$1" == "-v" || "$1" == "--verbose" ]] && RPC_VERBOSE=1 && shift

    (( $# > 0 )) && q_host="$1"

    local h_ver h_time h_block h_time_compare h_time_secs t_now

    h_ver=$(rpc-get-version "$q_host")
    h_time=$(rpc-get-time "$q_host")
    h_block=$(rpc-get-block "$q_host")
    t_now="$(rfc_datetime)"
    h_time_secs=$(compare-dates "$t_now" "$h_time")
    h_time_compare="$(human-seconds "$h_time_secs")"
    {
        msg cyan "Host:\t${BOLD}${q_host}"
        msg cyan "Version:\t${BOLD}${h_ver}"
        msg cyan "Block:\t${BOLD}${h_block}"
        msg cyan "Time:\t${BOLD}${h_time}\t(${h_time_compare} ago)\t(${h_time_secs} seconds)"
    } | column -t -s $'\t'
    msg
}

