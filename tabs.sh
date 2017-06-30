#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Now=$(date +%s)
DefaultTabsLog=$HOME/aa/misc/computerthings/logs/tabs.tsv
DefaultStartTime=1490984789
Usage="Usage: \$ $(basename $0) [-g] [-t tabs_log.tsv] [-s start_time]"

function main {

  tabs_log="$DefaultTabsLog"
  start_time="$DefaultStartTime"
  gui=
  while getopts ":gs:t:h" opt; do
  case "$opt" in
      t) tabs_log="$OPTARG";;
      s) start_time=$OPTARG;;
      g) gui="true";;
      h) fail "$Usage";;
    esac
  done

  if [[ $gui ]] && which zenity >/dev/null 2>/dev/null; then
    default_days_ago=$(((Now-DefaultStartTime)/(60*60*24)))
    set +e
    result=$(zenity --entry \
      --title 'When to start' \
      --text 'Starting timestamp or how long ago to start:' \
      --entry-text "$default_days_ago days" \
      2>/dev/null)
    set -e
    if [[ $result ]]; then
      start_time=$(get_start_time "$result")
    fi
  elif [[ $# -ge 2 ]]; then
    start_time=$2
  fi

  # 1481753483 is the last entry with over a thousand tabs, before the big, automated cleanup.
  awk '$1 >= '$start_time' {print ($1-'$(date +%s)')/60/60/24/30.5, $2}' "$tabs_log" \
    | scatterplot.py -T 'Tabs over time' -X 'Months ago' -Y 'Tabs in main window'
}

function get_start_time {
  time_str="$1"
  if echo "$time_str" | grep -qE '^[0-9]+$'; then
    start_time=$time_str
  else
    sec_ago=$(parse_time "$time_str")
    start_time=$((Now-sec_ago))
  fi
  echo "$start_time"
}

# Parse a time given in English into a number of seconds.
# Works on "20", "30s", "10 Months", "15min", etc.
function parse_time {
  time_str="$1"
  time_str=$(echo "$time_str" | tr [:upper:] [:lower:])
  if echo "$time_str" | grep -qE '^[0-9]+$'; then
    echo "$time_str"
    return 0
  elif ! echo "$time_str" | grep -qE '^[0-9]+ *[a-z]+$'; then
    return 1
  fi
  quantity=$(echo "$time_str" | sed -E 's/^([0-9]+).*$/\1/')
  unit=$(echo "$time_str" | sed -E 's/^[0-9]+ *([a-z]+)/\1/')
  if [[ ${unit:0:1} == s ]]; then
    multiplier=1
  elif [[ ${unit:0:1} == mi ]]; then
    multiplier=60
  elif [[ ${unit:0:1} == h ]]; then
    multiplier=$((60*60))
  elif [[ ${unit:0:1} == d ]]; then
    multiplier=$((60*60*24))
  elif [[ ${unit:0:1} == w ]]; then
    multiplier=$((60*60*24*7))
  elif [[ ${unit:0:2} == mo ]]; then
    multiplier=2635200 # == 60*60*24*30.5
  elif [[ ${unit:0:1} == y ]]; then
    multiplier=$((60*60*24*365))
  elif [[ ${unit:0:1} == m ]]; then
    # If only "m" is given, default to minutes
    multiplier=60
  else
    return 1
  fi
  echo $((quantity*multiplier))
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
