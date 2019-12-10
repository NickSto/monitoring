#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

LogDirDefault="$HOME/aa/computer/logs"
Usage="Usage: \$ $(basename "$0") [log/dir]"

function main {

  # Get arguments.
  log_dir="${@:$OPTIND:1}"
  if ! [[ "$log_dir" ]]; then
    log_dir="$LogDirDefault"
  fi

  last_restart=$(awk -F '\t' 'END {print $1}' "$log_dir/uptime.tsv")

  awk -F '\t' -v OFS='\t' '$1 > '"$last_restart"' {print $1, $4/1024}' "$log_dir/gnome-bloat.tsv" \
    | scatterplot.py --date -u x -Y MB -T 'GNOME Memory Usage'
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
