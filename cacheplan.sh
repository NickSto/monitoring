#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

TypeDefault=total
CacheLogDefault="$HOME/aa/computer/logs/cacheplan.tsv"
YMinDefault=-1
YMaxDefault=20
AwkScript='
last_time && last_size && $1 != last_time {
  print $1, ($2-last_size)/($1-last_time)/1024/1024
}
{
  last_time=$1
  last_size=$2
}'

Usage="Usage: \$ $(basename $0) [graph_type [cache_log.tsv [y_min [y_max]]]
graph types:
  \"total\" (default): Y axis is the total size of the cache
  \"rate\": Y axis is the rate of cache growth
y_min and y_max are the range of the Y axis. For \"rate\", it's in KB/s, with
defaults $YMinDefault to $YMaxDefault. For \"total\", it's in GB, with defaults 0 to the maximum
value observed."

function main {
  if [[ "$#" -ge 1 ]] && ([[ "$1" == '-h' ]] || [[ "$1" == '--help' ]]); then
    fail "$Usage"
  fi

  type="$TypeDefault"
  if [[ "$#" -ge 1 ]]; then
    type="$1"
  fi
  cache_log="$CacheLogDefault"
  if [[ "$#" -ge 2 ]]; then
    cache_log="$2"
  fi
  user_set_y_range=
  y_min="$YMinDefault"
  if [[ "$#" -ge 3 ]]; then
    user_set_y_range=true
    y_min="$3"
  fi
  y_max="$YMaxDefault"
  if [[ "$#" -ge 4 ]]; then
    y_max="$4"
  fi

  if [[ "$user_set_y_range" ]]; then
    y_range="--y-range $y_min $y_max"
  else
    y_range=
  fi

  if [[ "$type" == total ]]; then
    awk '{print $1, $2/1024/1024/1024}' "$cache_log" \
      | scatterplot.py --grid --title 'Cache size' --unix-time x --time-unit year --y-label GB \
        $y_range
  elif [[ "$type" == rate ]]; then
    awk "$AwkScript" "$cache_log" \
      | scatterplot.py --grid --title 'Cache growth rate' --unix-time x --time-unit year \
        --y-label 'MB/s' $y_range
  else
    fail "Error: Invalid graph type '$type'."
  fi

}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
