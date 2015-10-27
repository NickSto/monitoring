#!/usr/bin/env bash
set -ue
POINTS_DEFAULT=250
STATE_DIR=$HOME/.local/share/nbsdata
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

tail -n $points $STATE_DIR/temp.log | $plot_script -x 4 -y 1
