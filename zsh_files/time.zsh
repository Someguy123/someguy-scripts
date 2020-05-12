#!/usr/bin/env zsh
######################################################
#                         ##   Designed for ZSH.     #
# Date/Time Shell Helpers ##   Requires: curl, jq    #
#    by @someguy123       ##   May or may not work   #
# steemit.com/@someguy123 ##   with bash.            #
#                         ##   License: GNU AGPLv3   #
######################################################


# Returns the current UTC time in ISO/RFC format
#
#   $ rfc_datetime
#   2020-05-11T14:25:57
#
rfc_datetime() {
    TZ='UTC' date +'%Y-%m-%dT%H:%M:%S'
}
OS_NAME="$(uname -s)"

# date_to_seconds [date_time]
# Converts the first argument 'date_time' from a string date/time format, into
# standard integer UNIX time (epoch).
#
# For most reliable conversion, pass date/time in ISO format:
#       2020-02-28T20:08:09   (%Y-%m-%dT%H:%M:%S)
# e.g.
#   $ date_to_seconds "2020-02-28T20:08:09"
#   1582920489
#
date_to_seconds() {
    if [[ "$OS_NAME" == "Darwin" ]]; then
        date -j -f "%Y-%m-%dT%H:%M:%S" "$1" "+%s"
    else
        date -d "$1" '+%s'
    fi
}

# compare_dates [rfc_date_1] [rfc_date_2]
# Outputs the amount of seconds between date_2 and date_1
# 
# For most reliable conversion, pass date/time in ISO format:
#       2020-02-28T20:08:09   (%Y-%m-%dT%H:%M:%S)
#
# e.g.
#   $ compare_dates "2020-03-19T23:08:49" "2020-03-19T20:08:09"
#   10840
# means date_1 is 10,840 seconds in the future compared to date_2
#
compare_dates() {
    _compare_dates_usage() {
        msgerr cyan "Usage:${RESET} $0 [rfc_date_1] [rfc_date_2]\n"
        msgerr yellow "    Outputs the amount of seconds between date_2 and date_1"
        msgerr yellow "    For most reliable conversion, pass date/time in ISO format:\n"
        msgerr        "        2020-02-28T20:08:09   (%Y-%m-%dT%H:%M:%S)\n"

        msgerr bold blue "Examples:\n"
        msgerr cyan "   $ $0 '2020-05-11T14:42:03' '2020-05-11T14:25:57'"
        msgerr cyan "   966\n"
        msgerr cyan "   $ $0 '2020-05-11T14:42:03' '2020-05-01T10:15:21'"
        msgerr cyan "   880002\n"
        msgerr bold blue "Combine with the 'human-seconds' function to convert into days/hours/minutes etc.:\n"
        msgerr cyan "   $ human-seconds \$($0 '2020-05-11T14:42:03' '2020-05-01T10:15:21')"
        msgerr cyan "   10 day(s) + 4 hour(s) + 26 minute(s)\n"
    }

    if (( $# < 2 )); then msgerr bold red " [!!!] $0 expects TWO arguments"; _compare_dates_usage; return 1; fi
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then _compare_dates_usage; return 1; fi
    echo "$(($(date_to_seconds "$1")-$(date_to_seconds "$2")))"
}
compare-dates() { compare_dates "$@"; };

SECS_MIN=60
SECS_HR=$(( SECS_MIN * 60 ))
SECS_DAY=$(( SECS_HR * 24 ))
SECS_WK=$(( SECS_DAY * 7 ))
SECS_MON=$(( SECS_WK * 4 ))
SECS_YR=$(( SECS_DAY * 365 ))

# Separators between time units used by human_seconds
: ${REL_TIME_SEP=' + '}
: ${LAST_REL_TIME_SEP=' + '}

# Enable/disable time unit display / usage by human_seconds()
# by setting these env vars to 1 (enabled) or 0 (disabled)
: ${INC_MONTHS=1}
: ${INC_WEEKS=1}
: ${INC_DAYS=1}
: ${INC_HOURS=1}
: ${INC_MINUTES=1}
: ${INC_SECONDS=0}

# Alternative functionality for human_seconds when 2 args are passed
# Converts arg 1 'seconds' into a given time unit, e.g. 'hour'
_human_seconds_conv() {
    secs=$(( $1 ))
    case "$2" in
        m|M|min*|MIN*) _add_s minute "$(( secs / SECS_MIN ))";;
        h*|H*) _add_s hour "$(( secs / SECS_HR ))";;
        d|D|day*|DAY*) _add_s day "$(( secs / SECS_DAY ))";;
        w|W|we*|WE*) _add_s week "$(( secs / SECS_WK ))";;
        mon*|MON*) _add_s month "$(( secs / SECS_MON ))";;
        y*|Y*) _add_s year "$(( secs / SECS_YR ))";;
        *)
            msgerr bold red "Invalid unit '$2'\n"
            msgerr yellow "Valid units are: m(inute) h(our) d(ay) w(eek) mon(th) y(ear)"
            msgerr yellow "e.g. '$0 $secs min' or '$0 $secs h'\n"
            _human_seconds_usage
            return 1
            ;;
    esac
    return 0
}

# small helper function to plurify a unit if num isn't 1
# _add_s minute 1    # outputs: 1 minute
# _add_s minute 5    # outputs: 5 minutes
# _add_s hour 0      # outputs: 0 hours
_add_s() {
    local word="$1" num=$(( $2 ))
    (( num == 1 )) && echo "1 $word" || echo "$num ${word}s"
}

# Usage / help text for human_seconds()
_human_seconds_usage() {
    msgerr cyan "Usage:${RESET} human_seconds [seconds] (unit)\n"
    msgerr bold cyan "    (Also aliased to 'human-seconds')\n"
    msgerr yellow "    Converts integer seconds into relative human time. \n"

    msgerr bold blue "Basic examples:\n"
    msgerr red  "   \$${RESET} human_seconds 70"
    msgerr cyan "   1 minute + 10 seconds\n"
    msgerr red  "   \$${RESET} human_seconds 4000"
    msgerr cyan "   1 hour + 6 minutes\n"
    msgerr red  "   \$${RESET} human_seconds 60000000"
    msgerr cyan "   1 year + 11 months + 3 weeks + 10 hours + 40 minutes\n"

    msgerr bold blue "Convert 'seconds' directly into another unit (returns rounded integer):\n"
    msgerr red  "   \$${RESET} human_seconds 60000000 mon"
    msgerr cyan "   24 months\n"
    msgerr red  "   \$${RESET} human_seconds 60000000 day"
    msgerr cyan "   694 days\n"

    msgerr bold blue "Environment Variables for additional customisation:\n"

    msgerr yellow "   The env var 'REL_TIME_SEP' (default '${REL_TIME_SEP}') controls the separator used for all but the last"
    msgerr yellow "   time unit (normally seconds or minutes)\n"
    msgerr yellow "   The env var 'LAST_REL_TIME_SEP' (default '${LAST_REL_TIME_SEP}') controls the separator used to join the LAST"
    msgerr yellow "   time unit used (normally seconds or minutes)\n"

    msgerr red  "   \$${RESET} REL_TIME_SEP=', ' LAST_REL_TIME_SEP=' and ' human_seconds 60000000"
    msgerr cyan "   1 year + 11 months + 3 weeks + 10 hours + 40 minutes\n"
    msgerr red  "   \$${RESET} REL_TIME_SEP=' / ' LAST_REL_TIME_SEP=' & ' human_seconds 1200000"
    msgerr cyan "   1 week / 6 days / 21 hours & 20 minutes\n"

    msgerr yellow "   The env variables INC_SECONDS, INC_MINUTES, INC_HOURS, INC_DAYS, INC_WEEKS, and INC_MONTHS can be used"
    msgerr yellow "   to control the display of smaller time units when handling large time periods."
    msgerr yellow "   All of the INC_ envs default to 1, other than INC_SECONDS which defaults to 0 (disabled)\n"
    msgerr yellow "   NOTE: INC_WEEKS is a special case, when INC_WEEKS is disabled (set to 0), weeks will be completely disabled"
    msgerr yellow "         and will not be used as part of the calculations. \n"
    msgerr cyan   "    - INC_SECONDS (def: 0)    ${BOLD}1 = always show seconds,        0 = show seconds only if time period is < 60 mins\n"
    msgerr cyan   "    - INC_MINUTES (def: 1)    ${BOLD}1 = always show minutes,        0 = show minutes only if time period is < 24 hours\n"
    msgerr cyan   "    - INC_HOURS (def: 1)      ${BOLD}1 = always show hours,          0 = show hours only if time period is < 7 days\n"
    msgerr cyan   "    - INC_DAYS (def: 1)       ${BOLD}1 = always show days,           0 = show days only if time period is < 28 days\n"
    msgerr cyan   "    - INC_WEEKS (def: 1)      ${BOLD}1 = enable week(s) time unit    0 = disable use of week(s) entirely. days goes up to 28 instead of 7\n"

    msgerr red    "   \$${RESET} human_seconds 4002161"
    msgerr cyan   "   1 month + 2 weeks + 4 days + 7 hours + 42 minutes\n"
    msgerr bold cyan   "   # With INC_WEEKS=0, you can see that the 2 weeks + 4 days were flattened into 18 days."
    msgerr red    "   \$${RESET} INC_WEEKS=0 human_seconds 4002161"
    msgerr cyan   "   1 month + 18 days + 7 hours + 42 minutes\n"

    msgerr bold cyan   "   # By default INC_SECONDS is 0, which causes 'x seconds' to be truncated for times longer than 59 minutes"
    msgerr red    "   \$${RESET} human_seconds 620"
    msgerr cyan   "   10 minutes + 20 seconds\n"
    msgerr red    "   \$${RESET} human_seconds 6020"
    msgerr cyan   "   1 hour + 40 minutes\n"
    msgerr bold cyan   "   # If we change INC_SECONDS to 1, 'x seconds' will always be displayed, no matter how long the time period is."
    msgerr red    "   \$${RESET} INC_SECONDS=1 human_seconds 6020"
    msgerr cyan   "   1 hour + 40 minutes + 20 seconds\n"
}

# human_seconds [seconds]
# convert an amount of seconds into a humanized time (minutes, hours, days)
#
# human_seconds 60      # output: 1 minute(s)
# human_seconds 4000    # output: 1 hour(s) and 6 minute(s)
# human_seconds 90500   # output: 1 day(s) + 1 hour(s) + 8 minute(s)
#
human_seconds() {

    if (( $# < 1 )); then msgerr bold red " [!!!] $0 expects at least ONE argument"; _human_seconds_usage; return 1; fi
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then _human_seconds_usage; return 1; fi

    # Prevent weird quirks from leftover vars by blanking some of them.
    local secs="" mins="" hrs="" days="" m=""
    
    secs=$(( $1 ))
    # local rem_secs rem_mins rem_hrs m
    local mod_yrs mod_mons mod_wks mod_days mod_hrs mod_mins
    local rem_yrs rem_mons rem_wks rem_days rem_hrs rem_mins rem_secs
    local day_brkpt
    # Modulo the seconds against the amount of seconds in a year, a month, a week etc.
    # So we can determine the remainder seconds for each time unit
    mod_yrs=$(( secs % SECS_YR )) mod_mons=$(( mod_yrs % SECS_MON )) 
    # If weeks are disabled, mod_wks should just point to the month modulo
    (( INC_WEEKS )) && mod_wks=$(( mod_mons % SECS_WK )) || mod_wks="$mod_mons"
    mod_days=$(( mod_wks % SECS_DAY )) mod_hrs=$(( mod_days % SECS_HR )) mod_mins=$(( mod_hrs % SECS_MIN ))

    rem_yrs=$(( secs / SECS_YR )) rem_mons=$(( mod_yrs / SECS_MON ))
    # If weeks are disabled, rem_wks should just be 0.
    (( INC_WEEKS )) && rem_wks=$(( mod_mons / SECS_WK )) || rem_wks="0"
    rem_days=$(( mod_wks / SECS_DAY )) rem_hrs=$(( mod_days / SECS_HR )) rem_mins=$(( mod_hrs / SECS_MIN ))
    rem_secs="$mod_mins"

    # If a 2nd arg is specified, we're converting the passed seconds directly into another
    # time unit, e.g. days, weeks, months, minutes etc.
    if (( $# > 1 )); then
        _human_seconds_conv "$@"
        return $?
    fi

    # If weeks are enabled, days can only go up to 7 days before rolling over into 1 week
    # If weeks are disabled, days go up to 28 days instead (1 month = 4 weeks = 28 days)
    (( INC_WEEKS )) && day_brkpt="$SECS_WK" || day_brkpt="$SECS_MON"

    if (( secs < SECS_MIN )); then       # less than 1 minute
        m="$secs seconds"
    elif (( secs < SECS_HR )); then     # less than 1 hour
        mins=$(( secs / SECS_MIN ))
        m=$(_add_s minute $mins)
    elif (( secs < SECS_DAY )); then    # less than 1 day
        hrs=$(( secs / SECS_HR )) 
        m=$(_add_s hour $hrs)
    elif (( secs < day_brkpt )); then
        days=$(( secs / SECS_DAY ))
        m=$(_add_s day $days)
    elif (( INC_WEEKS )) && (( secs < SECS_MON )); then
        weeks=$(( secs / SECS_WK ))
        m=$(_add_s week $weeks)
    elif (( secs < SECS_YR )); then
        months=$(( secs / SECS_MON )) 
        m=$(_add_s month $months)
    else
        years=$(( secs / SECS_YR )) 
        m=$(_add_s year $years)
    fi
    # (( INC_MONTHS )) && (( secs > SECS_YR )) && (( rem_mons > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s month $rem_mons)"
    { (( INC_MONTHS )) || (( secs < SECS_YR )); } && (( secs > SECS_YR )) && (( rem_mons > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s month $rem_mons)"
    # (( INC_WEEKS )) && (( secs > SECS_MON )) && (( rem_wks > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s week $rem_wks)"
    # { (( INC_WEEKS )) || (( secs < SECS_YR )); } && (( secs > SECS_MON )) && (( rem_wks > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s week $rem_wks)"

    if (( INC_WEEKS )); then
        { (( INC_WEEKS )) || (( secs < SECS_YR )); } && (( secs > SECS_MON )) && (( rem_wks > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s week $rem_wks)"
    fi
    # (( INC_DAYS )) && (( secs > SECS_WK )) && (( rem_days > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s day $rem_days)"
    { (( INC_DAYS )) || (( secs < SECS_MON )); } && (( secs > day_brkpt )) && (( rem_days > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s day $rem_days)"

    # (( INC_HOURS )) && (( secs > SECS_DAY )) && (( rem_hrs > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s hour $rem_hrs)"

    { (( INC_HOURS )) || (( secs < SECS_WK )); } && (( secs > SECS_DAY )) && (( rem_hrs > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s hour $rem_hrs)"

    # ! (( INC_HOURS )) && (( secs > SECS_DAY )) && (( secs < SECS_MON )) && (( rem_hrs > 0 )) && m="${m}${REL_TIME_SEP}$(_add_s hour $rem_hrs)"
    # (( secs > SECS_HR )) && (( rem_mins > 0 )) && m="${m}${REL_TIME_SEP}$rem_mins minute(s)"
    # (( INC_MINUTES )) && (( secs > SECS_HR )) && (( rem_mins > 0 )) && m="${m}${LAST_REL_TIME_SEP}$(_add_s minute $rem_mins)"
    { (( INC_MINUTES )) || (( secs < SECS_DAY )); } && (( secs > SECS_HR )) && (( rem_mins > 0 )) && m="${m}${LAST_REL_TIME_SEP}$(_add_s minute $rem_mins)"
    # ! (( INC_MINUTES )) && (( secs > SECS_HR )) && (( secs < SECS_WK )) && (( rem_mins > 0 )) && m="${m}${LAST_REL_TIME_SEP}$(_add_s minute $rem_mins)"
    { (( INC_SECONDS )) || (( secs < SECS_HR )); } && (( secs > SECS_MIN )) && (( rem_secs > 0 )) && m="${m}${LAST_REL_TIME_SEP}$(_add_s second $rem_secs)"

    # if (( INC_SECONDS )); then
    #     (( secs > SECS_MIN )) && (( secs < SECS_HR )) && m="${m}${LAST_REL_TIME_SEP}$(_add_s second $rem_secs)"
    # else    
    #     (( secs > SECS_MIN )) && (( secs < SECS_HR )) && m="${m}${LAST_REL_TIME_SEP}$(_add_s second $rem_secs)"
    # fi

    echo "$m"
}

human-seconds() { human_seconds "$@"; };
