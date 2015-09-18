#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -u

PauseDefault=5
Usage="Usage: \$ $(basename $0) 'command to check' [goal] [pause]
If a \"goal\" is not given, it is assumed to be 0.
\"pause\" is in minutes."

function main {

  # Process arguments
  if [[ $# -lt 1 ]] || [[ $1 == '-h' ]]; then
    fail "$Usage"
  fi
  # $command
  command="$1"
  # $goal
  goal=0
  if [[ $# -ge 2 ]]; then
    goal=$2
    if ! isint "$goal"; then
      fail "Error: goal \"$goal\" is not an integer."
    fi
  fi
  # $pause
  pause=$PauseDefault
  if [[ $# -ge 3 ]]; then
    pause="$3"
    if ! isint "$pause"; then
      fail "Error: pause \"$pause\" is not an integer."
    fi
  fi

  # Check initial state.
  start=$($command)
  start_time=$(date +%s)
  if ! isint "$start"; then
    fail "Error: command '$command' failed or did not output an integer."
  fi
  if [[ $start -gt $goal ]]; then
    countdown='true'
  else
    countdown=''
  fi
  echo "Initial: $start | Goal: $goal | Time: $start_time"

  sleep 15
  if [[ $countdown ]]; then
    togo=$((start-goal))
  else
    togo=$((goal-start))
  fi
  while [[ $togo -gt 0 ]]; do
    current=$($command)
    current_time=$(date +%s)
    if [[ $current == $start ]]; then
      echo "Still $current. No change yet."
    elif ! isint "$current"; then
      echo "Error: command '$command' failed or did not output an integer." >&2
    else
      if [[ $countdown ]]; then
        progress=$((start-current))
      else
        progress=$((current-start))
      fi
      per_sec=$(calc "$progress/($current_time-$start_time)")
      eta_sec=$(calc "($current-$goal)/$per_sec")
      display $eta_sec $current
    fi
    sleep "$pause"m
  done
}

function display {
  read eta_sec current <<< $@
  # Keep 1 decimal point of precision, except for seconds, where we drop all decimals.
  eta_sec=$(echo "$eta_sec" | sed -E 's/\..*$//')
  eta_min=$(calc $eta_sec/60 | sed -E 's/\.([0-9]).*$/.\1/')
  eta_hr=$(calc $eta_min/60 | sed -E 's/\.([0-9]).*$/.\1/')
  eta=$(date -d "now + $eta_sec seconds")
  now=$(date)
  if [[ ${eta:0:10} == ${now:0:10} ]]; then
    eta=${eta:11:8}
  else
    eta=${eta:0:19}
  fi
  echo "Current: $current | ETA: $eta ($eta_hr hours / $eta_min min / $eta_sec sec)"
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
