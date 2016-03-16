#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -u

PauseDefault=5
Usage="Usage: \$ $(basename $0) [options] [goal] command [args]
-p: minutes to wait between checks (${PauseDefault} min by default)
-s: the starting number, if continuing from a previous run.
-t: the starting time, if continuing from a previous run."

function main {

  # get options
  pause="$PauseDefault"
  start=''
  start_time=''
  while getopts ":p:s:t:h" opt; do
    case "$opt" in
      p) pause="$OPTARG";;
      s) start="$OPTARG";;
      t) start_time="$OPTARG";;
      h) fail "$Usage";;
    esac
  done

  # get positional arguments
  narg=$OPTIND
  while [[ $narg -le $# ]]; do
    arg=${@:$narg:1}
    narg=$((narg+1))
  done
  positionals=$((narg-OPTIND))
  if [[ $positionals -lt 2 ]]; then
    fail "$Usage"
  fi
  goal=${@:$OPTIND:1}
  command="${@:$OPTIND+1:1}"
  args=
  if [[ $positionals -ge 3 ]]; then
    args="${@:$OPTIND+2}"
  fi
  quoted=
  if has_spaces "$command"; then
    quoted=true
  fi

  # Check arguments
  if ! isint "$goal"; then
    fail "Error: goal \"$goal\" is not an integer."
  fi
  if ! isint "$pause"; then
    fail "Error: -p pause \"$pause\" is not an integer."
  fi
  if [[ $start ]] && ! isint "$start"; then
    fail "Error: -s start \"$start\" is not an integer."
  fi
  if [[ $start_time ]] && ! isint "$start_time"; then
    fail "Error: -t time \"$start_time\" is not an integer."
  fi

  # Check initial state.
  if ! ([[ $start ]] && [[ $start_time ]]); then
    start=$($command $args)
    start_time=$(date +%s)
    if ! isint "$start"; then
      fail "Error: command '$command $args' failed or did not output an integer. Output:
$start"
    fi
  fi
  if [[ $start -gt $goal ]]; then
    countdown='true'
  else
    countdown=''
  fi
  echo "Initial time: $start_time | Initial count: $start (goal: $goal)"

  sleep 15
  if [[ $countdown ]]; then
    togo=$((start-goal))
  else
    togo=$((goal-start))
  fi
  while [[ $togo -gt 0 ]]; do
    current=$($command $args)
    current_time=$(date +%s)
    if [[ $current == $start ]]; then
      echo "Still $current. No change yet."
    elif ! isint "$current"; then
      echo "Error: command '$command $args' failed or did not output an integer. Output:
$current" >&2
    else
      if [[ $countdown ]]; then
        progress=$((start-current))
        togo=$((current-goal))
      else
        progress=$((current-start))
        togo=$((goal-current))
      fi
      per_sec=$(calc "$progress/($current_time-$start_time)")
      sec_togo=$(calc "$togo/$per_sec")
      display $sec_togo $current
    fi
    sleep "$pause"m
  done
}

function display {
  read sec_togo current <<< $@
  # Keep 1 decimal point of precision, except for seconds, where we drop all decimals.
  local sec_togo=$(echo "$sec_togo" | sed -E 's/\..*$//')
  local min_togo=$(calc $sec_togo/60 | sed -E 's/\.([0-9]).*$/.\1/')
  local hr_togo=$(calc $min_togo/60 | sed -E 's/\.([0-9]).*$/.\1/')
  local eta=$(date -d "now + $sec_togo seconds")
  local now=$(date)
  # Show date if the ETA isn't on the same day.
  if [[ ${eta:0:10} == ${now:0:10} ]]; then
    eta=${eta:11:8}
  else
    eta=${eta:0:19}
  fi
  if [[ $(calc "int($hr_togo)") -gt 1 ]]; then
    local togo="$hr_togo hours"
  elif [[ $(calc "int($min_togo)") -gt 1 ]]; then
    local togo="$min_togo min"
  else
    local togo="$sec_togo sec"
  fi
  echo "Current: $current | ETA: $eta ($togo)"
}

function has_spaces {
  with=$(echo -n "$1" | wc -c)
  without=$(echo -n "$1" | tr -d ' ' | wc -c)
  if [[ $with == $without ]]; then
    return 1
  else
    return 0
  fi
}

function calc {
  python -c "from __future__ import division; from math import *; print $*"
}

function isint {
  echo "$1" | grep -q -E '^[0-9]+$'
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
