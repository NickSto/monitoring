#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

DEFAULT_LOG="$HOME/aa/computer/logs/smart-sda.tsv"
DEFAULT_IDS='5,187,188,197,198'
DEFAULT_WIDTH=2

Usage="Usage: \$ $(basename "$0") [options] [smart-log.tsv]
Process the SMART stats log, finding the first timepoint where any of a set of SMART statistics
becomes >1. Then print the values of all the selected SMART stats from that timepoint forward.
-i: Filter out all SMART stats except these ids.
    Default: The critical 5 ($DEFAULT_IDS)
-w: Printing width of each value. Passed directly to the format string.
    Default: $DEFAULT_WIDTH"

function main {

  # Get arguments.
  ids="$DEFAULT_IDS"
  width="$DEFAULT_WIDTH"
  while getopts "i:w:h" opt; do
    case "$opt" in
      i) ids="$OPTARG";;
      w) width="$OPTARG";;
      [h?]) fail "$Usage";;
    esac
  done
  log="${@:$OPTIND:1}"

  if ! [[ "$log" ]]; then
    log="$DEFAULT_LOG"
  fi

  if ! [[ -f "$log" ]]; then
    fail "Error: Cannot find log file $log"
  fi

  gawk -F '\t' -v OFS='\t' -v INCLUDE_IDS="$ids" '
    BEGIN {
      split(INCLUDE_IDS, fields, ",")
      for (i in fields) {
        include[fields[i]] = 1
      }
      start = 0
    }
    {
      time = $1; id = $2; name = $3; value = $4
      names[id] = name
      if (include[id] && (start || value > 0)) {
        data[id][time] = value
        if (time != last_time) {
          times[timeslen++] = time
        }
        if (start == 0) {
          start = time
        }
        last_time = time
      }
    }
    END {
      print "Starting at " start ":"
      for (id in data) {
        if (! include[id]) {
          continue
        }
        printf("%-22s  ", names[id])
        for (i in times) {
          printf("%'"$width"'d ", data[id][times[i]])
        }
        printf("\n")
      }
    }' "$log"

}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
