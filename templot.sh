#!/usr/bin/env bash
set -ue
PointsDefault=250
LogFile=$HOME/aa/misc/computerthings/logs/temp.log
PlotScript=$HOME/aa/code/python/single/scatterplot.py

plot_script=$(which scatterplot.py)
if [[ $? -gt 0 ]]; then
  plot_script=$PlotScript
fi

if [[ $# -lt 1 ]]; then
  points=$PointsDefault
elif [[ $1 == '-h' ]]; then
  echo "Usage: $(basename $0) [timepoints]
Default number of timepoints: $PointsDefault" >&2
  exit 1
else
  points=$1
fi

time=$(date +%s)
tail -n $points $LogFile \
  | awk '{print ($4-'$time')/60/60, $1}' \
  | scatterplot.py -x 1 -y 2 -X 'Hours in past' -Y Celsius
