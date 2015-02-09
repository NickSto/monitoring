#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -u

SLEEP=5

USAGE="Usage: \$ $(basename $0)
Monitor when IP connections are opened or closed. Checks every $SLEEP seconds. Ignores http and
https connections. New connections are marked \">\", closed ones \"<\"."

function main {

  old=$(tempfile)
  new=$(tempfile)
  touch $old
  trap cleanup SIGINT SIGHUP SIGQUIT SIGKILL

  while true; do
    netstat --inet -W | awk '$6 == "ESTABLISHED" && $5 !~ /:https?$/ {print $5}' > $new
    if ! diff $old $new; then
      echo '--------------'
    fi
    mv $new $old
    sleep $SLEEP
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
