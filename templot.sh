#!/usr/bin/env bash
set -ue
POINTS_DEFAULT=250
LOG_FILE=$HOME/aa/misc/computerthings/logs/temp.log
PLOT_SCRIPT=$HOME/aa/code/python/single/scatterplot.py

plot_script=$(which scatterplot.py)
if [[ $? -gt 0 ]]; then
  plot_script=$PLOT_SCRIPT
fi

if [[ $# -lt 1 ]]; then
  points=$POINTS_DEFAULT
else
  points=$1
fi

tail -n $points $LOG_FILE | $plot_script -x 4 -y 1
