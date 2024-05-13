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

# remove-subnet [subnet]
# remove-subnet
# Removes the /?? subnet mask from a subnet passed either via first arg,
# or via pipe with no args. Works for v4 + v6
# Example:
#   $ echo "23.45.67.89/24" | remove-subnet
#   23.45.67.89
#   $ remove-subnet '2a07:e00::1/64'
#   2a07:e00::1
#
remove-subnet() {
    local rx='s/(.*)(\/[0-9]+)/\1/g'
    if (( $# > 0 )); then
        sed -E "$rx" <<< "$1"
    else
        sed -E "$rx"
    fi
}

# var-remove-subnet [remove=1]
# var-remove-subnet [subnet] [remove=1]
# Example 1:
#   $ _var-remove-subnet 1.2.3.4/24 1
#   1.2.3.4
# Example 2:
#   $ echo '2a07:e00::1/32' | var-remove-subnet 1
#   2a07:e00::1
# Example 3:
#   $ echo '34.56.78.32/8' | var-remove-subnet 0
#   34.56.78.32/8
var-remove-subnet() {
    if (( $# == 0 )); then
        msgerr bold red " [!!!] var-remove-subnet requires at least 1 argument"
        msgerr red " USAGE:"
        msgerr red "     This function removes a subnet mask from a v4/v6 IP address based off a boolean 0 or 1,"
        msgerr red "     if the boolean arg is 0 (no) - then it'll output the original input with no modifications,"
        msgerr red "     if the boolean arg is 1 (yes) - then it'll pass the input to remove-subnet() to remove the"
        msgerr red "     subnet mask, and output it to stdout.\n"

        msgerr red "     Passing subnet via argument usage:\n        var-remove-subnet IP_SUBNET SHOULD_REMOVE\n"
        msgerr red "     Passing subnet via pipe usage:\n        var-remove-subnet SHOULD_REMOVE\n"

        msgerr red "     Example 1: var-remove-subnet 1.2.3.4/24 1"
        msgerr red "     Example 2: echo '2a07:e00::1/32' | var-remove-subnet 1"
        msgerr
        return 2
    fi

    # If there's only 1 arg, then remove-subnet is getting piped into, and the first arg
    # is a boolean 0 (no) or 1 (yes) for whether to remove the subnet mask or not
    if (( $# < 2 )); then
        if (( $1 )); then
            remove-subnet
        else
            tee
        fi
    # If there's 2 args, then first arg is the subnet, 2nd arg is whether to remove the subnet
    else
        if (( $2 )); then
            remove-subnet "$1"
        else
            echo "$1"
        fi
    fi
}

# ip-is-v6 [ip_or_subnet] [remove_subnet=1]
# Returns success code (0) if the given IP is an IPv6 address
# By default, will strip the subnet mask before checking, so that subnets count as valid,
# but if you don't want subnets to be counted as a valid ipv6 address, you can pass 0 (false/no)
# as the second argument to disable subnet stripping
# Example:
#   $ ip-is-v6 '2a07:e00::1' && echo "yes - valid v6" || echo "not a valid v6"
#   yes - valid v6
# 
#   $ ip-is-v6 '185.130.44.1' && echo "yes - valid v6" || echo "not a valid v6"
#   not a valid v6
# 
#   $ ip-is-v6 '2a07:e00::1/64' && echo "yes - valid v6" || echo "not a valid v6"
#   yes - valid v6
#
#   # If we set remove_subnet to 0, then subnets will not be considered valid
#   $ ip-is-v6 '2a07:e00::1/64' 0 && echo "yes - valid v6" || echo "not a valid v6"
#   not a valid v6
#
ip-is-v6 () {
	local chkv6="^\([0-9a-fA-F]\{0,4\}:\)\{1,7\}[0-9a-fA-F]\{0,4\}$"
    local should_remove="1"
    (( $# > 1 )) && should_remove="$2"
    echo "$1" | var-remove-subnet "$should_remove" | grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} -q "$chkv6"
	return $?
}

# ip-is-v4 [ip_or_subnet] [remove_subnet=1]
# Returns success code (0) if the given IP is an IPv4 address
# By default, will strip the subnet mask before checking, so that subnets count as valid,
# but if you don't want subnets to be counted as a valid ipv4 address, you can pass 0 (false/no)
# as the second argument to disable subnet stripping
# Example:
#   $ ip-is-v4 '185.130.44.1' && echo "yes - valid v4" || echo "not a valid v4"
#   yes - valid v4
# 
#   $ ip-is-v4 '2a07:e00::1' && echo "yes - valid v4" || echo "not a valid v4"
#   not a valid v4
# 
#   $ ip-is-v4 '185.130.44.1/24' && echo "yes - valid v4" || echo "not a valid v4"
#   yes - valid v4
#
#   # If we set remove_subnet to 0, then subnets will not be considered valid
#   $ ip-is-v4 '185.130.44.1/24' 0 && echo "yes - valid v4" || echo "not a valid v4"
#   not a valid v4
#
ip-is-v4 () {
	local chkv4='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
    local should_remove="1"
    (( $# > 1 )) && should_remove="$2"
	echo "$1" | var-remove-subnet "$should_remove" | grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} -E --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} -q "$chkv4"
	return $?
}

: ${IPBAN_AUTO_MODE="0"}
: ${IPBAN_QUIET="0"}

# _save-ipt [ip] [ipt4_dst] [ipt6_dst] [mode_auto]
_save-ipt() {
    local ipa="$1"
    local ipt4_dst="$2" ipt6_dst="$3" mode_auto="$4"
    #local xrule="-I INPUT -s ${ipa} -j DROP"
    qzmsg green " [+++] DETECTED iptables persistent"
    if (( mode_auto == 0 )); then
        if ! yesno " [?] WARN: Do you want to save all current in-memory iptables rules to /etc/iptables/rules.v4 / rules.v6? (y/n) > "; then
        #if [[ "$cont_save" == "n" || "$cont_save" == "N" || "$cont_save" == "no" || "$cont_save" == "NO" ]]; then
            qzmsg red " [!!!] Aborting - you entered NO - not saving iptables rules to disk"
            return 4
        fi
    fi
    qzmsg yellow " [...] Saving all IPv4 rules to disk at $ipt4_dst"
    sudo iptables-save | sudo tee "$ipt4_dst"
    qzmsg yellow " [...] Saving all IPv6 rules to disk at $ipt6_dst"
    sudo ip6tables-save | sudo tee "$ipt6_dst"
}

# _save-pyre [ip] [pyre_dst] [pyre_action=drop]
_save-pyre() {
    local ipa="$1" pyre_dst="$2" pyre_action="drop"
    (( $# > 2 )) && pyre_action="$3"
    local xrule="$pyre_action from ${ipa}"
    qzmsg green " [+++] Persisting to Privex PyreWall"
    qzmsg yellow " [...] Adding '${xrule}' to end of $pyre_dst"
    echo -e "\n${xrule}\n" | sudo tee -a "$pyre_dst"
    qzmsg green " [+++] Updated pyrewall rules at $pyre_dst"
}

_remove-pyre() {
    local xrule="$1"
    local pyre_dst="$2"
    qzmsg yellow " [...] Finding and removing line '$xrule' from $pyre_dst"
    if [[ -f "$pyre_dst" ]]; then
        sudo sed -i "/${xrule}/d" "$pyre_dst"
    else
        qzmsg red " [!!!] ERROR: File $pyre_dst not found"
        return 5
    fi
}

ipban() {
    local mode_auto="$IPBAN_AUTO_MODE"
    xquiet="$IPBAN_QUIET"
    local use_ipt=0 use_pyre=0 should_persist=1
    local pyre_dst="/etc/pyrewall/rules.pyre"
    local ipt4_dst="/etc/iptables/rules.v4" ipt6_dst="/etc/iptables/rules.v6"
    for v in "$@"; do
        case "$v" in
            -a|--auto)
                mode_auto=1
                shift;;
            -q|--quiet)
                xquiet=1
                shift;;
            -i|-ipt|--ipt|--iptables-persist)
                use_ipt=1
                shift
                ;;
            -p|-pyre|--pyre|--pyrewall|--pyrewall-persist)
                use_pyre=1
                shift
                ;;
            --pyre-file)
                shift
                pyre_dst="$1"
                shift
                ;;
            -m|--memory|-np|--no-persist)
                should_persist=0
                shift
                ;;
            -h|--help|-?)
                msg yellow "Usage: ipban [-q|-a|-h|-m|-np|-i|-p|--help]"
                msg "    -a|--auto)    Auto mode - don't warn about saving iptables to rules.v4/v6"
                msg "    -q|--quiet)    Quiet mode - Don't output any progress messages"
                msg "    -i|-ipt|--ipt|--iptables-persist)    Force persisting to iptables rules.v4/v6 even if pyrewall is detected"
                msg "    -p|-pyre|--pyre|--pyrewall|--pyrewall-persist)    Force persisting to pyrewall's rules.pyre even if pyrewall is not detected"
                msg "    --pyre-file [file])    Write to a different pyrewall rules file instead of /etc/pyrewall/rules.pyre"
                msg "    -m|-np|--memory|--no-persist)    Memory only mode - Don't persist the ban to pyrewall or iptables"
                msg
                msg "Examples:"
                msg "    # Standard IP Ban with automatic persistence detection"
                msg "    $ ipban 2.3.4.5"
                msg "    # Don't prompt before saving to rules.v4/v6 for iptables-persistent"
                msg "    $ ipban -a '2a07:e03:2::1'"
                msg "    # Quiet mode - don't output any progress messages"
                msg "    $ ipban -q '2a07:e05::/32'"
                msg "    # Ban an entire /24 subnet and do not persist to pyrewall/iptables-persistent - only store in iptables memory"
                msg "    $ ipban -m 4.5.6.0/24"
                msg "    # Force persisting to pyrewall even if not detected, and use a custom pyrewall rules file"
                msg "    $ ipban -p --pyre-file '/root/custom.pyre' '2a07:e03:2::1'"

                return 1
                ;;
        esac

    done
    qzmsg() {
        (( xquiet )) || msg "$@"
    }
    local ipa="$1"
    
    if ip-is-v4 "$ipa"; then
        qzmsg yellow " [...] Banning IPv4 address/subnet '${ipa}' via iptables"
        sudo iptables -I INPUT -s "$ipa" -j DROP
    elif ip-is-v6 "$ipa"; then
        qzmsg yellow " [...] Banning IPv4 address/subnet '${ipa}' via iptables"
        sudo ip6tables -I INPUT -s "$ipa" -j DROP
    else
        qzmsg red " [!!!] INVALID IP ADDRESS $ipa"
        return 8
    fi
    if (( should_persist )); then
        if (( use_ipt == 0 )) && [[ -f "$pyre_dst" ]] || (( use_pyre )); then
            _save-pyre "$ipa" "$pyre_dst" "drop"
        elif (( use_ipt )) || [[ -f "$ipt4_dst" ]]; then
            _save-ipt "$ipa" "$ipt4_dst" "$ipt6_dst" "$mode_auto"
        fi
    else
        qzmsg yellow " [!!!] Not persisting to pyrewall/iptables-persistent as -m/-np/--no-persist is set"
    fi

    return 0
}

ipunban() {
    local mode_auto="$IPBAN_AUTO_MODE"
    xquiet="$IPBAN_QUIET"
    local use_ipt=0 use_pyre=0 should_persist=1
    local pyre_dst="/etc/pyrewall/rules.pyre"
    local ipt4_dst="/etc/iptables/rules.v4" ipt6_dst="/etc/iptables/rules.v6"
    for v in "$@"; do
        case "$v" in
            -a|--auto)
                mode_auto=1
                shift;;
            -q|--quiet)
                xquiet=1
                shift;;
            -i|-ipt|--ipt|--iptables-persist)
                use_ipt=1
                shift
                ;;
            -p|-pyre|--pyre|--pyrewall|--pyrewall-persist)
                use_pyre=1
                shift
                ;;
            --pyre-file)
                shift
                pyre_dst="$1"
                shift
                ;;
            -m|--memory|-np|--no-persist)
                should_persist=0
                shift
                ;;
            -h|--help|-?)
                msg yellow "Usage: ipunban [-q|-a|-h|-m|-np|-i|-p|--help]"
                msg "    -a|--auto)    Auto mode - don't warn about saving iptables to rules.v4/v6"
                msg "    -q|--quiet)    Quiet mode - Don't output any progress messages"
                msg "    -i|-ipt|--ipt|--iptables-persist)    Force persisting to iptables rules.v4/v6 even if pyrewall is detected"
                msg "    -p|-pyre|--pyre|--pyrewall|--pyrewall-persist)    Force persisting to pyrewall's rules.pyre even if pyrewall is not detected"
                msg "    --pyre-file [file])    Write to a different pyrewall rules file instead of /etc/pyrewall/rules.pyre"
                msg "    -m|-np|--memory|--no-persist)    Memory only mode - Don't persist the unban to pyrewall or iptables"
                msg
                msg "Examples:"
                msg "    # Standard IP unban with automatic persistence detection"
                msg "    $ ipunban 2.3.4.5"
                msg "    # Don't prompt before saving to rules.v4/v6 for iptables-persistent"
                msg "    $ ipunban -a '2a07:e03:2::1'"
                msg "    # Quiet mode - don't output any progress messages"
                msg "    $ ipunban -q '2a07:e05::/32'"
                msg "    # Unban an entire /24 subnet and do not persist to pyrewall/iptables-persistent - only store in iptables memory"
                msg "    $ ipunban -m 4.5.6.0/24"
                msg "    # Force persisting to pyrewall even if not detected, and use a custom pyrewall rules file"
                msg "    $ ipunban -p --pyre-file '/root/custom.pyre' '2a07:e03:2::1'"

                return 1
                ;;
        esac


    done
    qzmsg() {
        (( xquiet )) || msg "$@"
    }
    local ipa="$1"
    
    if ip-is-v4 "$ipa"; then
        qzmsg yellow " [...] Unbanning IPv4 address/subnet '${ipa}' via iptables"
        sudo iptables -D INPUT -s "$ipa" -j DROP
    elif ip-is-v6 "$ipa"; then
        qzmsg yellow " [...] Unbanning IPv4 address/subnet '${ipa}' via iptables"
        sudo ip6tables -D INPUT -s "$ipa" -j DROP
    else
        qzmsg red " [!!!] INVALID IP ADDRESS $ipa"
        return 8
    fi
    if (( should_persist )); then
        if (( use_ipt == 0 )) && [[ -f "$pyre_dst" ]] || (( use_pyre )); then
            #_save-pyre "$ipa" "$pyre_dst" "drop"
            _remove-pyre "drop from $ipa" "$pyre_dst"
        elif (( use_ipt )) || [[ -f "$ipt4_dst" ]]; then
            _save-ipt "$ipa" "$ipt4_dst" "$ipt6_dst" "$mode_auto"
        fi
    else
        qzmsg yellow " [!!!] Not persisting to pyrewall/iptables-persistent as -m/-np/--no-persist is set"
    fi

    return 0
}

