#!/usr/bin/env bash
set -ue
SecondsDefault=5400  # 1.5 hours
LogFile=$HOME/aa/misc/computerthings/logs/temp.log
PlotScript=$HOME/aa/code/python/single/scatterplot.py
Usage="Usage: $(basename $0) [time or points]
Optionally give the amount of time or log points in the past.
If not given, will show the last $SecondsDefault seconds ("$(python -c "print $SecondsDefault/60.0/60")" hours).
The amount of time can be given by appending \"s\" (seconds), \"m\" (minutes),
\"h\" (hours), or \"d\" (days) to a number, like \"6h\"."


function main {
  plot_script=$(which scatterplot.py)
  if [[ $? -gt 0 ]]; then
    plot_script=$PlotScript
  fi

  seconds=
  points=
  if [[ $# -lt 1 ]]; then
    seconds=$SecondsDefault
  elif [[ $1 == '-h' ]]; then
    echo "$Usage" >&2
    exit 1
  elif [[ $1 =~ ^[0-9]+$ ]]; then
    points=$1
  elif [[ $1 =~ ^[0-9]+[sSmMhHdD]$ ]]; then
    unit=$(echo $1 | sed -E 's/[0-9]//g')
    quantity=$(echo $1 | sed -E 's/[^0-9]//g')
    case $unit in
      s|S) seconds=$quantity;;
      m|M) seconds=$(($quantity*60));;
      h|H) seconds=$(($quantity*60*60));;
      d|D) seconds=$(($quantity*60*60*24));;
    esac
  else
    echo -e "Error: Time format of \"$1\" not recognized.\n" >&2
    echo "$Usage" >&2
    exit 1
  fi

  now=$(date +%s)
  if [[ $seconds ]]; then
    cutoff=$((now-seconds))
    awk "\$4 > $cutoff {print (\$4-$now)/60/60, \$1}" $LogFile \
      | scatterplot.py -x 1 -y 2 -X 'Hours in past' -Y Celsius
  else
    tail -n $points $LogFile \
      | awk '{print ($4-'$now')/60/60, $1}' \
      | scatterplot.py -x 1 -y 2 -X 'Hours in past' -Y Celsius
  fi
}


main "$@"
