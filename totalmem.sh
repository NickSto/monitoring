#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Usage="Usage: \$ $(basename "$0") cmd_prefix [name]
-t: Output tab-delimited format with 2 columns: the % of total CPU usage
    (all cores), and the RAM usage, in MB.
-u: Include the unix timestamp as an additional 1st column in the tsv output."

function main {
  if [[ "$#" -lt 1 ]] || [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]]; then
    fail "$Usage"
  fi

  tsv=
  timestamp=
  while getopts ":tuh" opt; do
  case "$opt" in
      t) tsv="true";;
      u) timestamp="true";;
      h) fail "$USAGE";;
    esac
  done
  # get positionals
  prefix="${@:$OPTIND:1}"
  name="${@:$OPTIND+1:1}"

  if ! [[ "$name" ]]; then
    name="$prefix"
  fi

  prefix_len=$(echo -n "$prefix" | wc -c)

  mem=$(awk '$1 == "MemTotal:" && $3 == "kB" {print $2*1024}' /proc/meminfo)

  if ! [[ "$mem" ]]; then
    fail 'Error getting total memory.'
  fi

  cores=$(grep -c 'core id' /proc/cpuinfo)
  if [[ "$cores" == 0 ]]; then
    fail 'Error getting number of cores.'
  fi

  if [[ "$tsv" ]]; then
    if [[ "$timestamp" ]]; then
      now=$(date +%s)
      echo -ne "$now\t"
    fi
    ps aux | awk 'substr($11, 1, '"$prefix_len"') == "'"$prefix"'" {cpu+=$3; mem+=$4} \
      END {print cpu/'"$cores"' "\t" '"$mem"'*mem/100/1024/1024}'
  else
    ps aux | awk 'substr($11, 1, '"$prefix_len"') == "'"$prefix"'" {cpu+=$3; mem+=$4} \
      END {printf("'"$name"' is using %.1f%% CPU, %.2fGB RAM\n", \
           cpu/'"$cores"', '"$mem"'*mem/100/1024/1024/1024)}'
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
