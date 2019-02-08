#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

LogFile=$HOME/aa/computer/logs/upmonitor.tsv
PlotScript=$HOME/code/python/single/scatterplot.py
HoursDefault=24
Usage="Usage: \$ $(basename $0) [-i] [hours ago]
Default hours ago: $HoursDefault
-i: Invert the Y axis, showing 100/latency instead of Log10(latency)."

function main {

  # Get arguments.
  inverse=
  while getopts "ih" opt; do
    case "$opt" in
      i) inverse="true";;
      [h?]) fail "$Usage";;
    esac
  done
  hours="${@:$OPTIND:1}"

  if ! [[ "$hours" ]]; then
    hours="$HoursDefault"
  fi

  plot_script=$(which scatterplot.py)
  if [[ $? -gt 0 ]]; then
    if [[ -x $PlotScript ]]; then
      plot_script=$PlotScript
    else
      fail "Error: plotting script not found or not executable: \"$plot_script\""
    fi
  fi

  if ! [[ -s $LogFile ]]; then
    fail "Error: log file missing: \"$LogFile\""
  fi

  now=$(date +%s)

  sampling=$(python -c "from __future__ import division; print int(round($hours/2.5))")
  if [[ $sampling -le 0 ]]; then
    sampling=1
  fi

  if [[ "$inverse" ]]; then
    awk -F '\t' -v OFS='\t' \
      'NR % '$sampling' == 0 && $2 > '$now'-('$hours'*60*60) {
        printf("%f\t", ($2-'$now')/60/60)
        if ($1 == 0) {
          print 0
        } else {
          print 100/$1
        }
      }' $LogFile | $plot_script -T 'Connectivity' -X 'Hours ago' -Y 'Connectivity (100/latency)'
  else
    awk -F '\t' -v OFS='\t' \
      'NR % '$sampling' == 0 && $2 > '$now'-('$hours'*60*60) && $1 != 0 {
        print ($2-'$now')/60/60, log($1)/log(10)
      }' $LogFile | $plot_script -T 'Latency' -X 'Hours ago' -Y 'Log10(Latency)'
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
