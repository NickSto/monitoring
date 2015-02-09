#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -u

SleepDefault=5
IgnoreDefault='http,https'

USAGE="Usage: \$ $(basename $0) [sleep [ports,to,ignore]]
Monitor when IP connections are opened or closed. Checks every $SleepDefault seconds by default.
Ignores http and https connections. New connections are marked \">\", closed ones \"<\"."

function main {

  sleep=$SleepDefault
  ignore=$(echo "$IgnoreDefault" | tr ',' '|')
  if [[ $# -gt 0 ]]; then
    if [[ $1 == '-h' ]]; then
      fail "$USAGE"
    fi
    sleep=$1
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
