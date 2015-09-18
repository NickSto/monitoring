#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

PauseDefault=5
Usage="Usage: \$ $(basename $0) 'command to check' [goal] [pause]
If a \"goal\" is not given, it is assumed to be 0.
\"pause\" is in minutes."

function main {
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
    fail "Error: output of command '$command' is not an integer."
  fi
  if [[ $start -gt $goal ]]; then
    countdown='true'
  else
    countdown=''
  fi

  #TODO: Work for countup too.
  sleep 15
  while [[ $start -gt $goal ]]; do
    current=$($command)
    current_time=$(date +%s)
    if [[ $current == $start ]]; then
      echo "Still $current. No change yet."
    elif ! isint "$current"; then
      echo "Error: output of command '$command' is not an integer." >&2
    else
      per_sec=$(calc "($start-$current)/($current_time-$start_time)")
      eta_sec=$(calc "($current-$goal)/$per_sec")
      eta_min=$(calc $eta_sec/60)
      eta_hr=$(calc $eta_min/60)
      eta=$(date -d "now + $eta_sec seconds")
      echo "Current: $current ETA: ${eta:11:8} (${eta_hr:0:4} hours / ${eta_min:0:5} min / $eta_sec sec)"
    fi
    sleep "$pause"m
  done
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
