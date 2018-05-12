#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Usage="Usage: \$ $(basename "$0") [options] cmd_prefix1 [prefix2 [prefix3 [..]]]
-n: A name to call the RAM user in the human-readable output. Defaults to the first prefix.
-t: Output tab-delimited format with 2 columns: the % of total CPU usage
    (all cores), and the RAM usage, in MB.
-u: Include the unix timestamp as an additional 1st column in the tsv output."

function main {
  if [[ "$#" -lt 1 ]] || [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]]; then
    fail "$Usage"
  fi

  tsv=
  name=
  timestamp=
  while getopts ":n:tuh" opt; do
  case "$opt" in
      n) name="$OPTARG";;
      t) tsv="true";;
      u) timestamp="true";;
      h) fail "$USAGE";;
    esac
  done

  if ! [[ "$name" ]]; then
    name=$(basename "${@:$OPTIND:1}")
  fi

  total_mem=$(awk '$1 == "MemTotal:" && $3 == "kB" {print $2*1024}' /proc/meminfo)
  if ! [[ "$total_mem" ]]; then
    fail 'Error getting total memory.'
  fi
  cores=$(grep -c 'core id' /proc/cpuinfo)
  if [[ "$cores" == 0 ]]; then
    fail 'Error getting number of cores.'
  fi

  cpu=0
  mem=0
  for prefix in "${@:$OPTIND}"; do
    read cpu mem <<< $(ps aux | awk -v cpu="$cpu" -v mem="$mem" \
      'substr($11, 1, '${#prefix}') == "'"$prefix"'" {cpu+=$3; mem+=$4} END {print cpu, mem}')
  done

  if [[ "$tsv" ]]; then
    if [[ "$timestamp" ]]; then
      now=$(date +%s)
      echo -ne "$now\t"
    fi
    awk -v cpu="$cpu" -v mem="$mem" 'BEGIN {print cpu/'"$cores"' "\t" '"$total_mem"'*mem/100/1024/1024}'
  else
    awk -v cpu="$cpu" -v mem="$mem" 'BEGIN {printf("'"$name"' is using %.1f%% CPU, %.2fGB RAM\n", \
                                     cpu/'"$cores"', '"$total_mem"'*mem/100/1024/1024/1024)}'
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
