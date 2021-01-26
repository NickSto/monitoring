#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

LogFileDefault="$HOME/aa/computer/logs/upmonitor.tsv"
PlotScript="$HOME/code/python/single/scatterplot.py"
HoursDefault=12
Usage="Usage: \$ $(basename "$0") [-l|-i|-n] [-L logfile.tsv] [-s start_at | -t timestamp] [hours]
Default number of hours to show: $HoursDefault
-s: Start this many hours ago (default: same as the number of hours to show).
-t: Start at this unix timestamp.
-l: Show Y axis as Log10(latency) (default).
-i: Invert the Y axis, showing 100/latency.
-n: Show Y axis as raw millisecond values.
-L: Display this log file instead of the default ($LogFileDefault)."

function main {

  now=$(date +%s)

  # Get arguments.
  transform="log"
  start_time=
  start_hrs=
  log_file="$LogFileDefault"
  while getopts "lins:t:L:h" opt; do
    case "$opt" in
      i) transform="inverse";;
      n) transform="normal";;
      l) transform="log";;
      s) start_hrs="$OPTARG";;
      t) start_time="$OPTARG";;
      L) log_file="$OPTARG";;
      [h?]) fail "$Usage";;
    esac
  done
  hours="${@:$OPTIND:1}"
  if ! [[ "$hours" ]]; then
    hours="$HoursDefault"
  fi
  if [[ "$start_time" ]]; then
    start_hrs=$(calc "($now-$start_time)/60/60")
  elif ! [[ "$start_hrs" ]]; then
    start_hrs="$hours"
  fi
  if ! [[ -s "$log_file" ]]; then
    fail "Error: log file missing: \"$log_file\""
  fi

  # Find the plotting script.
  plot_script=$(which scatterplot.py)
  if [[ "$?" -gt 0 ]]; then
    if [[ -x "$PlotScript" ]]; then
      plot_script="$PlotScript"
    else
      fail "Error: plotting script not found or not executable: \"$plot_script\""
    fi
  fi

  # Figure out sampling rate.
  sampling=$(calc "round($hours/10)")
  if [[ "$sampling" -le 0 ]]; then
    sampling=1
  fi
  if [[ "$sampling" == 1 ]]; then
    subtitle="every ping"
  else
    subtitle="every $(ordinal "$sampling") ping"
  fi

  # Figure out start and end of displayed period.
  end_hrs=$(calc "max($start_hrs-$hours, 0)")
  if ! [[ "$start_time" ]]; then
    start_time=$(calc "$now - $start_hrs*60*60")
  fi
  end_time=$(calc "$now - $end_hrs*60*60")

  # Figure out plot labels.
  case "$transform" in
    log)
      title='Latency'$'\n'"($subtitle)"
      ylabel='Latency (Log10(milliseconds))';;
    inverse)
      title='Connectivity'$'\n'"($subtitle)"
      ylabel='Connectivity (100/latency)';;
    normal)
      title='Latency'$'\n'"($subtitle)"
      ylabel='Latency (milliseconds)';;
  esac

  # Read log, transform data, and show plot.
  < "$log_file" \
  filter_log "$start_time" "$end_time" \
    | convert_log_times "$now" \
    | transform_log "$transform" \
    | "$plot_script" --grid --x-field 1 --y-field 2 --tag-field 3 --title "$title" \
      --x-range "-$start_hrs" "-$end_hrs" --x-label 'Hours ago' --point-size 5 --y-label "$ylabel"
}

function awkt {
  awk -F '\t' -v OFS='\t' "$@"
}

function filter_log {
  awkt -v "start_time=$1" -v "end_time=$2" '$2 > start_time && $2 < end_time'
}

function convert_log_times {
  awkt -v "now=$1" '{
    $2 = ($2-now)/60/60
    print
  }'
}

function transform_log {
  local transform="$1"
  if [[ "$transform" == log ]]; then
    awkt '{
      if ($7 == "up" && $1 != 0) {
        print $2, log($1)/log(10), $7
      } else {
        print $2, 0, $7
      }
    }'
  elif [[ "$transform" == inverse ]]; then
    awkt '{
      if ($7 == "up" && $1 != 0) {
        print $2, 100/$1, $7
      } else {
        print $2, 0, $7
      }
    }'
  else
    awkt '{
      print $2, $1, $7
    }'
  fi
}

function ordinal {
  number="$1"
  case "$number" in
    1[0-9]) ending=th;;
    *1) ending=st;;
    *2) ending=nd;;
    *3) ending=rd;;
    *) ending=th;;
  esac
  echo "${number}${ending}"
}

function calc {
  python3 -c "print($1)"
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
