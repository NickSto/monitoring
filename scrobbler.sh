#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Usage='Usage: $ '"$(basename $0)"' state artist track_title album mp3_path
The "state" is whether this was called at the start, end, etc. of the song.
In Audacious'\'' Song Change plugin:
  scrobbler.sh start "%a" "%s" "%b" "%T" "%f"'

function main {
  if [[ $# -lt 5 ]] || [[ $1 == '-h' ]] || [[ $1 == '--help' ]]; then
    fail "$Usage"
  fi

  state="$1"
  artist="$2"
  track="$3"
  album="$4"
  path="$5"

  now=$(date +%s)
  echo -e "$now\t$state\t$artist\t$track\t$album\t$path" >> $HOME/aa/computer/logs/scrobbles.tsv
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
