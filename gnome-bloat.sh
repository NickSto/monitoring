#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

LogDirDefault="$HOME/aa/computer/logs"
UptimeDefault="$LogDirDefault/uptime.tsv"
GnomeLogDefault="$LogDirDefault/mem.gnome.tsv"
Usage="Usage: \$ $(basename "$0") [mem.gnome.tsv [uptime.tsv]]"

function main {

  # Get arguments.
  gnome_log="$GnomeLogDefault"
  uptime_log="$UptimeDefault"
  if [[ "$#" -ge 1 ]]; then
    if [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]] || [[ "$#" -gt 2 ]]; then
      fail "$Usage"
    fi
    gnome_log="$1"
    if [[ "$#" == 2 ]]; then
      uptime_log="$2"
    fi
  fi

  last_restart=$(awk -F '\t' 'END {print $1}' "$uptime_log")

  awk -F '\t' -v OFS='\t' '$1 > '"$last_restart"' {print $1, $3}' "$gnome_log" \
    | scatterplot.py --grid --date -u x -Y MB -T 'GNOME Memory Usage'
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
