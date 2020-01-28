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

  if [[ $(ps aux | awk '$12 ~ /file-metadata\.py$/') ]]; then
    eta=$(get_eta "$old_log" "$new_log")
    eta_human=$(human_time "$eta")
    notify-send "ETA: $eta_human"
  fi

  plot_progress "$old_log" "$new_log"
}


function plot_progress {
  old_log="$1"
  new_log="$2"
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
      print old_name, ($1-old_start)/60/60, $2/1024/1024/1024, $3
    } else {
      print new_name, ($1-new_start)/60/60, $2/1024/1024/1024, $3
    }
  }' "$old_log" "$new_log" | scatterplot.py -g 1 -x 2 -y 3 -X Hours -Y GB
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

function get_eta {
  old_log="$1"
  new_log="$2"
  read current_time current_bytes current_files <<< $(tail -n 1 "$new_log")
  awk -F '\t' -v current_bytes="$current_bytes" '
  $2 > current_bytes && extrap_time == "" {
    time = $1
    bytes = $2
    #print "("bytes"-"last_bytes")/("time"-"last_time")" > "/dev/stderr"
    rate = (bytes-last_bytes)/(time-last_time)
    #print "rate (MB/sec)\t" rate/1024/1024 > "/dev/stderr"
    extrap_time = ((current_bytes-last_bytes)/rate) + last_time
    #print "extrap_time\t" extrap_time-1577000000 > "/dev/stderr"
  }
  {
    last_time = $1
    last_bytes = $2
  }
  END {
    end_time = $1
    #print "end_time\t" end_time-1577000000 > "/dev/stderr"
    time_to_end = end_time - extrap_time
    print time_to_end
  }' "$old_log"
}

function human_time {
  sec=$(printf "%0.0f" "$1")
  if [[ "$sec" -lt 60 ]]; then
    format_time "$sec" second
  elif [[ "$sec" -lt $((60*60)) ]]; then
    min=$(echo "scale=3; $sec/60" | bc)
    format_time "$min" minute
  elif [[ "$sec" -lt $((60*60*24)) ]]; then
    hr=$(echo "scale=3; $sec/60/60" | bc)
    format_time "$hr" hour
  elif [[ "$sec" -lt $((60*60*24*10)) ]]; then
    days=$(echo "scale=3; $sec/60/60/24" | bc)
    format_time "$days" day
  elif [[ "$sec" -lt $((60*60*24*40)) ]]; then
    weeks=$(echo "scale=3; $sec/60/60/24/7" | bc)
    format_time "$weeks" week
  elif [[ "$sec" -lt $((60*60*24*365)) ]]; then
    months=$(echo "scale=3; $sec/60/60/24/30" | bc)
    format_time "$months" month
  else
    years=$(echo "scale=3; $sec/60/60/24/365" | bc)
    format_time "$years" year
  fi
}


function format_time {
  quantity="$1"
  unit="$2"
  if [[ $(echo "$quantity < 10" | bc) == 1 ]]; then
    rounded1decimal=$(printf "%0.1f" "$quantity")
    rounded0decimal=$(printf "%0.0f" "$quantity")
    if [[ $(echo "$rounded1decimal == $rounded0decimal" | bc) == 1 ]]; then
      rounded=$rounded0decimal
    else
      rounded=$rounded1decimal
    fi
  else
    rounded=$(printf "%0.0f" "$quantity")
  fi
  if [[ "$rounded" == 1 ]]; then
    echo "$rounded $unit"
  else
    echo "$rounded ${unit}s"
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
