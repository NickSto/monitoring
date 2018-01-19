#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

LogFile=$HOME/aa/computer/logs/upmonitor.tsv
PlotScript=$HOME/code/python/single/scatterplot.py
HoursDefault=24
Usage="Usage: \$ $(basename $0) [hours ago]
Default hours ago: $HoursDefault"

function main {

  hours=$HoursDefault
  if [[ $# -ge 1 ]]; then
    if [[ $1 == '-h' ]] || [[ $1 == '--help' ]]; then
      fail "$Usage"
    else
      hours=$1
    fi
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

  awk -F '\t' -v OFS='\t' \
    'NR % '$sampling' == 0 && $2 > '$now'-('$hours'*60*60) {
      printf("%f\t", ($2-'$now')/60/60)
      if ($1 == 0) {
        print 0
      } else {
        print 100/$1
      }
    }' $LogFile | $plot_script -X 'Hours ago' -Y 'Connectivity (100/latency)'
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
