#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Usage="Usage: \$ $(basename "$0") [options] command1 [command2 [command3 [..]]]
Default: Match the command to the start of the executable as shown in ps (field 11).
So '/usr/lib/firefox/' would match '/usr/lib/firefox/browser'.
-e: Match the command to the exact path of the executable as show in ps.
    So '/usr/lib/firefox/browser' would only match '/usr/lib/firefox/browser'.
-b: Match the command to the basename of the executable as shown in ps.
    So 'browser' would match '/usr/lib/firefox/browser'.
-n: A name to call the RAM user in the human-readable output. Defaults to the first command.
-t: Output tab-delimited format with 2 columns: the % of total CPU usage
    (all cores), and the RAM usage, in MB.
-u: Include the unix timestamp as an additional 1st column in the tsv output."

function main {
  if [[ "$#" -lt 1 ]] || [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]]; then
    fail "$Usage"
  fi

  tsv=
  name=
  exact=
  basename=
  timestamp=
  while getopts ":n:ebtuh" opt; do
  case "$opt" in
      n) name="$OPTARG";;
      e) ending="true";;
      b) basename="true";;
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
  for command in "${@:$OPTIND}"; do
    if [[ "$exact" ]]; then
      read cpu mem seen <<< $(ps aux | awk -v cpu="$cpu" -v mem="$mem" \
        '$11 == "'"$command"'" {seen=1; cpu+=$3; mem+=$4} END {print cpu, mem, seen}')
    elif [[ "$basename" ]]; then
      read cpu mem seen <<< $(ps aux | awk -v cpu="$cpu" -v mem="$mem" \
        '{len = split($11, fields, "/"); if (fields[len] == "'"$command"'") {seen=1; cpu+=$3; mem+=$4}}
         END {print cpu, mem, seen}')
    else
      read cpu mem seen <<< $(ps aux | awk -v cpu="$cpu" -v mem="$mem" \
        'substr($11, 1, '${#command}') == "'"$command"'" {seen=1; cpu+=$3; mem+=$4}
        END {print cpu, mem, seen}')
    fi
  done

  if ! [[ "$seen" ]]; then
    fail "Did not find any processes matching the given command(s)."
  fi

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
