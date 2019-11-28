#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

Usage="Usage: \$ $(basename "$0") [-d snapshot/dir] [old-snapshot-log.tsv [new-snapshot-log.tsv]]
If either snapshot file argument is omitted, you must give a -d snapshot/dir."

function main {

  # Get arguments.
  snap_dir=
  while getopts "d:h" opt; do
    case "$opt" in
      d) snap_dir="$OPTARG";;
      [h?]) fail "$Usage";;
    esac
  done
  old_log="${@:$OPTIND:1}"
  new_log="${@:$OPTIND+1:1}"

  if ! ([[ "$old_log" ]] && [[ "$new_log" ]]) && ! [[ "$snap_dir" ]]; then
    fail "$Usage"
  fi

  if ! [[ "$old_log" ]]; then
    old_log=$(ls -1t "$snap_dir"/log.snapshot-20*.tsv | tail -n 1)
  fi
  if ! [[ "$new_log" ]]; then
    new_log=$(ls -1t "$snap_dir"/log.snapshot-20*.tsv | head -n 1)
  fi

  old_name=$(get_name "$old_log" Old)
  new_name=$(get_name "$new_log" New)
  if [[ "$new_name" == $(date +'%Y-%m-%d') ]]; then
    new_name="Today"
  fi

  read old_start old_end <<< $(get_ends "$old_log")
  read new_start new_end <<< $(get_ends "$new_log")

  border=$(((old_end+new_start)/2))

  awk -F '\t' -v OFS='\t' -v old_start="$old_start" -v new_start="$new_start" -v border="$border" \
    -v old_name="$old_name" -v new_name="$new_name" '{
    if ($1 < border) {
      print old_name, ($1-old_start)/60, $2/1024/1024/1024, $3
    } else {
      print new_name, ($1-new_start)/60, $2/1024/1024/1024, $3
    }
  }' "$old_log" "$new_log" | scatterplot.py -g 1 -x 2 -y 3 -X Minutes -Y GB
}

function get_name {
  path="$1"
  fallback="$2"
  date=$(echo "$path" | grep -Eo '20[12][0-9]-[012][0-9]-[0-3][0-9]' | head -n 1)
  if [[ "$date" ]]; then
    echo "$date"
  else
    echo "$fallback"
  fi
}

function get_ends {
  log="$1"
  awk -F '\t' 'NR == 1 {printf("%d\t", $1)} END {print $1}' "$log"
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
