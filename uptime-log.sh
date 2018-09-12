#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

DataDir=$HOME/.local/share/nbsdata
UptimeFile=$DataDir/uptime-current.txt
SleepTime=1m

Usage="Usage: \$ $(basename $0) log-file.tsv
This is a daemon which, if run on startup, will log the previous uptime to a log file and then
periodically record the current uptime (to be logged on the next restart). The sleep time between
checks is $SleepTime. This means the precision of all information is limited by that.
The current uptime, in seconds, is stored in $UptimeFile
The log file is tab-delimited, with 5 columns:
1. time of last shutdown (unix timestamp)
2. length of the last uptime (in seconds)
3. length of the last uptime (human-readable)
4. time of last startup (before the last shutdown) (human-readable)
5. time of last shutdown (human-readable)"

function main {

  if [[ $# -lt 1 ]] || [[ $1 == '-h' ]]; then
    fail "$Usage"
  else
    log_file="$1"
  fi

  if ! [[ -e /proc/uptime ]]; then
    fail "Error: /proc/uptime missing."
  fi

  if [[ -s $UptimeFile ]]; then
    shutdown_time=$(stat -c %Y $UptimeFile)
    last_uptime=$(cat $UptimeFile)
    last_uptime_human=$(human_time $last_uptime)
    startup_time_human=$(date -d @$((shutdown_time-last_uptime)))
    shutdown_time_human=$(date -d @$shutdown_time)
    echo -e "$shutdown_time\t$last_uptime\t$last_uptime_human\t$startup_time_human\t$shutdown_time_human\t." >> "$log_file"
  fi

  while true; do
    # Get the uptime in seconds from /proc/uptime.
    # The sed command gets the first number, without the decimal point.
    sed -E 's/^([0-9]+)\..*$/\1/' /proc/uptime > $UptimeFile
    sleep $SleepTime
  done
}


# Convert a number of seconds into a human-readable time string.
function human_time {
  local sec_total=$1
  local sec=$((sec_total % 60))
  local min_total=$((sec_total/60))
  local min=$((min_total % 60))
  local hr_total=$((min_total/60))
  local hr=$((hr_total % 24))
  local days_total=$((hr_total/24))
  local days=$((days_total % 365))
  local years_total=$((days_total/365))
  if [[ $days == 1 ]]; then
    local days_str='1 day '
  else
    local days_str="$days days "
  fi
  if [[ $years_total == 1 ]]; then
    local years_str='1 year '
  else
    local years_str="$years_total years "
  fi
  local hr_str="$hr:"
  local min_str="$min:"
  local sec_str=$sec
  if [[ $min -lt 10 ]] && [[ $min_total -ge 60 ]]; then
    min_str="0$min:"
  fi
  if [[ $sec -lt 10 ]] && [[ $sec_total -ge 60 ]]; then
    sec_str="0$sec"
  fi
  if [[ $years_total == 0 ]]; then
    years_str=''
    if [[ $days == 0 ]]; then
      days_str=''
      if [[ $hr == 0 ]]; then
        hr_str=''
        if [[ $min == 0 ]]; then
          min_str=''
          if [[ $sec == 0 ]]; then
            sec_str='0'
          fi
        fi
      fi
    fi
  fi
  echo "$years_str$days_str$hr_str$min_str$sec_str"
}


function fail {
  echo "$@" >&2
  exit 1
}


main "$@"
