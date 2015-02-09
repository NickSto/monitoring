#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -u

SleepDefault=5
IgnoreDefault='http,https'

USAGE="Usage: \$ $(basename $0) [sleep [ports,to,ignore]]
Monitor when IP connections are opened or closed. New connections are marked '>', closed ones '<'.
Checks every $SleepDefault seconds by default. Ignores connections to these ports by default: \"$IgnoreDefault\".
To change ignored ports, give a different comma-separated list. Whether to use the port numbers or
service names depends on whether netstat does."

function main {

  sleep=$SleepDefault
  ignore=$(echo "$IgnoreDefault" | tr ',' '|')
  if [[ $# -ge 1 ]]; then
    if [[ $1 == '-h' ]]; then
      fail "$USAGE"
    fi
    sleep=$1
  fi
  if [[ $# -ge 2 ]]; then
    ignore=$(echo "$2" | tr ',' '|')
  fi


  old=$(tempfile)
  new=$(tempfile)
  touch $old
  trap cleanup SIGINT SIGHUP SIGQUIT SIGKILL

  while true; do
    netstat --inet -W | awk '$6 == "ESTABLISHED" {print $5}' | grep -vE ":($ignore)$" > $new
    if ! diff $old $new; then
      echo '--------------'
    fi
    mv $new $old
    sleep $sleep
  done
}


function cleanup {
  rm $old 2>/dev/null
  rm $new 2>/dev/null
  exit
}


function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
