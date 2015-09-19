#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -u

PauseDefault=5
Usage="Usage: \$ $(basename $0) [options] 'command to check' [goal]
If a \"goal\" is not given, it is assumed to be 0.
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
    if [[ ${arg:0:1} == '-' ]]; then
      fail "Error: options like $arg must come before positional arguments."
    fi
    narg=$((narg+1))
  done
  positionals=$((narg-OPTIND))
  if [[ $positionals -lt 1 ]]; then
    fail "$Usage"
  fi
  command="${@:$OPTIND:1}"
  goal=0
  if [[ $positionals -ge 2 ]]; then
    goal="${@:$OPTIND+1:1}"
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
    start=$($command)
    start_time=$(date +%s)
    if ! isint "$start"; then
      fail "Error: command '$command' failed or did not output an integer."
    fi
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
