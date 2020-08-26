#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

LogFile="$HOME/aa/computer/logs/upmonitor.tsv"
PlotScript="$HOME/code/python/single/scatterplot.py"
HoursDefault=24
Usage="Usage: \$ $(basename "$0") [-i] [hours]
Default number of hours to show: $HoursDefault
-s: Start this many hours ago (default: same as the number of hours to show).
-i: Invert the Y axis, showing 100/latency instead of Log10(latency)."

function main {

  # Get arguments.
  inverse=
  start=
  while getopts "is:h" opt; do
    case "$opt" in
      i) inverse="true";;
      s) start="$OPTARG";;
      [h?]) fail "$Usage";;
    esac
  done
  hours="${@:$OPTIND:1}"

  if ! [[ "$hours" ]]; then
    hours="$HoursDefault"
  fi

  if ! [[ "$start" ]]; then
    start="$hours"
  fi

  plot_script=$(which scatterplot.py)
  if [[ "$?" -gt 0 ]]; then
    if [[ -x "$PlotScript" ]]; then
      plot_script="$PlotScript"
    else
      fail "Error: plotting script not found or not executable: \"$plot_script\""
    fi
  fi

  if ! [[ -s "$LogFile" ]]; then
    fail "Error: log file missing: \"$LogFile\""
  fi

  now=$(date +%s)

  sampling=$(calc "round($hours/10)")
  if [[ "$sampling" -le 0 ]]; then
    sampling=1
  fi
  end=$(calc "$start-$hours")
  start_sec=$(calc "$now - $start*60*60")
  end_sec=$(calc "$now - $end*60*60")

  if [[ "$inverse" ]]; then
    awk -F '\t' -v OFS='\t' \
      'NR % '"$sampling"' == 0 && $2 > '"$start_sec"' && $2 < '"$end_sec"' {
        printf("%f\t", ($2-'"$now"')/60/60)
        if ($1 == 0) {
          print 0
        } else {
          print 100/$1
        }
      }' "$LogFile" \
      | "$plot_script" --grid --title 'Connectivity' --x-label 'Hours ago' --point-size 5 \
        --x-range "-$start" "-$end" --y-label 'Connectivity (100/latency)'
  else
    awk -F '\t' -v OFS='\t' \
      'NR % '"$sampling"' == 0 && $2 > '"$start_sec"' && $2 < '"$end_sec"' {
        hrs_ago = ($2-'"$now"')/60/60
        if ($7 == "up" && $1 != 0) {
          print $7, hrs_ago, log($1)/log(10)
        } else if ($7 == "down") {
          print $7, hrs_ago, 0
        }
      }' "$LogFile" \
      | "$plot_script" --grid --tag-field 1 --x-field 2 --y-field 3 --title Latency \
        --x-range "-$start" "-$end" --x-label 'Hours ago' --point-size 5 --y-label 'Log10(Latency)'
  fi
}

function calc {
  python3 -c "print($1)"
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
