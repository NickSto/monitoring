#!/usr/bin/env bash
set -ue
SecondsDefault=5400  # 1.5 hours
LogFile=$HOME/aa/computer/logs/temp.log
PlotScript=$HOME/code/python/single/scatterplot.py
Usage="Usage: \$ $(basename $0) [points or start_time] [end_time]
Without any arguments, will show the last $SecondsDefault seconds ("$(python -c "print $SecondsDefault/60.0/60")" hours).
Or specify how much to show:
Give a single integer to say how many timepoints in the past to display.
Or give a time (an integer appended with a unit) to say how far back in the past:
\"s\" (seconds), \"m\" (minutes), \"h\" (hours), or \"d\" (days), e.g. \"30m\" or \"6h\".
Give another time to say where to stop.
E.g. \"\$ $(basename $0) 12h 10h\" means show timepoints between 12 and 10 hours ago."


function main {
  plot_script=$(which scatterplot.py)
  if [[ $? -gt 0 ]]; then
    plot_script=$PlotScript
  fi

  start=
  points=
  if [[ $# -lt 1 ]]; then
    start=$SecondsDefault
  elif [[ $1 == '-h' ]]; then
    fail "$Usage"
  elif [[ $1 =~ ^[0-9]+$ ]]; then
    points=$1
  elif [[ $1 =~ ^[0-9]+[sSmMhHdD]$ ]]; then
    start=$(to_seconds $1)
  else
    echo -e "Error: Time format of \"$1\" not recognized.\n" >&2
    fail "$Usage"
  fi

  end=0
  if [[ $# -ge 2 ]]; then
    if [[ $2 =~ ^[0-9]+[sSmMhHdD]$ ]]; then
      end=$(to_seconds $2)
    else
      echo -e "Error: Time format of \"$2\" not recognized.\n" >&2
      fail "$Usage"
    fi
  fi

  now=$(date +%s)
  if [[ $start ]]; then
    start_time=$((now-start))
    end_time=$((now-end))
    awk "\$4 > $start_time && \$4 < $end_time {print (\$4-$now)/60/60, \$1}" $LogFile \
      | scatterplot.py -x 1 -y 2 -X 'Hours in past' -Y Celsius
  else
    tail -n $points $LogFile \
      | awk '{print ($4-'$now')/60/60, $1}' \
      | scatterplot.py -x 1 -y 2 -X 'Hours in past' -Y Celsius
  fi
}


function to_seconds {
  unit=$(echo $1 | sed -E 's/[0-9]//g')
  quantity=$(echo $1 | sed -E 's/[^0-9]//g')
  case $unit in
    s|S) seconds=$quantity;;
    m|M) seconds=$(($quantity*60));;
    h|H) seconds=$(($quantity*60*60));;
    d|D) seconds=$(($quantity*60*60*24));;
  esac
  echo $seconds
}


function fail {
  echo "$@" >&2
  exit 1
}


main "$@"
