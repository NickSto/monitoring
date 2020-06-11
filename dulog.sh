#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

Usage="Usage: $(basename $0) [options] path/to/dir
Print the disk usage of a file or directory, along with a timestamp.
Useful for simple environments like cron where you can't rely on shell features to write a
one-liner.
Prints a tab-delimited line with 3 fields:
the current Unix timestamp (date +%s), the size of the target in bytes (du -sb), and the absolute
path to the target.
Options:
-u: Print the size in these units instead of bytes. Options: kB, MB, GB (case-insensitive).
    You can just use the first letter instead.
-P: Omit the path field."

function main {

  # Get arguments.
  nopath=
  unit='b'
  while getopts "Pu:h" opt; do
    case "$opt" in
      P) nopath="true";;
      u) unit="$OPTARG";;
      [h?]) fail "$Usage";;
    esac
  done
  path="${@:$OPTIND:1}"

  if ! [[ "$path" ]]; then
    fail "$Usage"
  fi

  now=$(date +%s)
  bytes=$(du -sb "$path" | awk '{print $1}')
  abspath=$(realpath "$path")
  if [[ "$unit" == b ]]; then
    size="$bytes"
  else
    divisor=$(get_divisor "$unit")
    size=$(calc "round($bytes/$divisor, 1)")
  fi
  if [[ "$nopath" ]]; then
    printf '%d\t%s\n' "$now" "$size"
  else
    printf '%d\t%s\t%s\n' "$now" "$size" "$abspath"
  fi
}

function realpath {
  cd "$(dirname "$1")"
  dirname=$(pwd -P)
  basename=$(basename "$1")
  echo "$dirname/$basename"
}

function calc {
  python3 -c "print($*)"
}

function get_divisor {
  unit="$1"
  case $(echo "$unit" | tr '[:upper:]' '[:lower:]') in
    b*) echo 1;;
    k*) echo 1024;;
    m*) echo $((1024*1024));;
    g*) echo $((1024*1024*1024));;
    *) fail "Error: unrecognized unit $unit";;
  esac
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
