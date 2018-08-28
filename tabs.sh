#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

AwkScript='{
  for (i = 1; i <= NF; i++) {
    tot += $i
    if ($i > max) {
      max = $i
    }
  }
  print max, tot
}'

Now=$(date +%s)
DefaultTabsLog=$HOME/aa/computer/logs/tabs.tsv
DefaultStartTime=1518701800
SessionScript=${SessionScript:-$HOME/code/python/single/firefox-sessions.py}
Usage="Usage: \$ $(basename $0) [-g] [-c] [-t tabs_log.tsv] [-s start_time]
-t: The tabs log tsv file.
-n: Show tab counts taken during browsing sessions, instead of at the end.
-s: Starting timestamp.
-g: Use a zenity prompt to get the start time from the user.
-u: Update the tabs log from the latest session files.
-c: Also display the current tab count in a pop-up notification."

function main {

  tabs_log="$DefaultTabsLog"
  start_time="$DefaultStartTime"
  gui=
  now=
  update=
  current=
  while getopts ":guncs:t:h" opt; do
  case "$opt" in
      t) tabs_log="$OPTARG";;
      s) start_time=$OPTARG;;
      n) now="true";;
      g) gui="true";;
      u) update="true";;
      c) current="true";;
      h) fail "$Usage";;
    esac
  done

  # Notify the current number of tabs, if requested.
  if [[ "$current" ]]; then
    if ! [[ -x "$SessionScript" ]]; then
      fail "Error: script $SessionScript missing."
    fi
    # Get the number of tabs in the main (biggest) window, and in all windows.
    read main total <<< $("$SessionScript" -T | awk "$AwkScript")
    session_file=$("$SessionScript" --print-path)
    modified=$(stat -c "%Y" "$session_file")
    age_seconds=$((Now-modified))
    age_human=$(human_time "$age_seconds")
    if [[ "$main" == "$total" ]]; then
      total_line=
    else
      total_line="$total total\n"
    fi
    notify-send "$main tabs" "$total_line$age_human ago"
  fi

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
    else
      fail "Error: Did not receive a start time."
    fi
  elif [[ $# -ge 2 ]]; then
    start_time=$2
  fi

  if [[ $update ]]; then
    script_dir=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
    if [[ -s "$script_dir/tab-log.sh" ]]; then
      bash "$script_dir/tab-log.sh" "$tabs_log" >> "$tabs_log"
    else
      fail "Error: Can't find tabs-log.sh at $script_dir"
    fi
  fi

  if [[ "$now" ]]; then
    now_cmp='=='
    now_title='(constant monitoring)'
  else
    now_cmp='!='
    now_title='(end of session)'
  fi

  # 1481753483 is the last entry with over a thousand tabs, before the big, automated cleanup.
  awk -F '\t' '$1 >= '"$start_time"' && $5 '"$now_cmp"' "now" {print $1, $2}' "$tabs_log" \
    | scatterplot.py --unix-time X --date -T 'Tabs over time'$'\n'"$now_title" -Y 'Tabs in main window'
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

function human_time {
  sec=$(printf "%0.0f" "$1")
  if [[ "$sec" -lt 60 ]]; then
    format_time "$sec" second
  elif [[ "$sec" -lt $((60*60)) ]]; then
    min=$(echo "scale=3; $sec/60" | bc)
    format_time "$min" minute
  elif [[ "$sec" -lt $((60*60*24)) ]]; then
    hr=$(echo "scale=3; $sec/60/60" | bc)
    format_time "$hr" hour
  elif [[ "$sec" -lt $((60*60*24*10)) ]]; then
    days=$(echo "scale=3; $sec/60/60/24" | bc)
    format_time "$days" day
  elif [[ "$sec" -lt $((60*60*24*40)) ]]; then
    weeks=$(echo "scale=3; $sec/60/60/24/7" | bc)
    format_time "$weeks" week
  elif [[ "$sec" -lt $((60*60*24*365)) ]]; then
    months=$(echo "scale=3; $sec/60/60/24/30" | bc)
    format_time "$months" month
  else
    years=$(echo "scale=3; $sec/60/60/24/365" | bc)
    format_time "$years" year
  fi
}

function format_time {
  quantity="$1"
  unit="$2"
  if [[ $(echo "$quantity < 10" | bc) == 1 ]]; then
    rounded1decimal=$(printf "%0.1f" "$quantity")
    rounded0decimal=$(printf "%0.0f" "$quantity")
    if [[ $(echo "$rounded1decimal == $rounded0decimal" | bc) == 1 ]]; then
      rounded=$rounded0decimal
    else
      rounded=$rounded1decimal
    fi
  else
    rounded=$(printf "%0.0f" "$quantity")
  fi
  if [[ "$rounded" == 1 ]]; then
    echo "$rounded $unit"
  else
    echo "$rounded ${unit}s"
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
