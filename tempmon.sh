#!/usr/bin/env bash
# Continually monitor CPU temperature using the lm-sensors package
# 
# Currently tested on only two particular computers' outputs of the 'sensors'
# command (the Asus ZenBook Prime and Thinkpad S1 Yoga). Example output:
#  acpitz-virtual-0
#  Adapter: Virtual device
#  temp1:        +74.0°C  (crit = +108.0°C)
#
#  asus-isa-0000
#  Adapter: ISA adapter
#  temp1:        +74.0°C  
#
#  coretemp-isa-0000
#  Adapter: ISA adapter
#  Physical id 0:  +76.0°C  (high = +87.0°C, crit = +105.0°C)
#  Core 0:         +76.0°C  (high = +87.0°C, crit = +105.0°C)
#  Core 1:         +70.0°C  (high = +87.0°C, crit = +105.0°C)
set -ue


PauseDefault=15
Line1Pattern='^Package id 0:'
Line2Pattern='^Core 0:'
Line3Pattern='^Core 1:'
TempRegex='s/^.*:\s+[+-]([0-9]+)\.[0-9]+.C\s+\(.*$/\1/'
LogFileDefault="$HOME/.local/share/nbsdata/temp.log"

Usage="Usage: $0 [pause_seconds [log_file]]
Default time between checks (pause_seconds): $PauseDefault
If log_file is not given, will print to stdout only.
If log_file is given, will print instead to log_file.
If \"-l\" is given as log_file, will use default log_file:
$LogFileDefault"

# Read arguments.
pause=$PauseDefault
log_file=''
if [[ $# -gt 0 ]]; then
  if [[ $1 == '-h' ]]; then
    echo "$Usage" >&2
    exit 1
  fi
  pause=$1
fi
if [[ $# -gt 1 ]]; then
  if [[ $2 == '-l' ]]; then
    log_file="$LogFileDefault"
  else
    log_file="$2"
  fi
fi
if ! echo "$pause" | grep -E '^[0-9]+$' >/dev/null 2>/dev/null; then
  echo "Error: first argument (pause seconds) must be an integer." >&2
  exit 1
fi
if ! [[ -d $(dirname "$log_file") ]]; then
  echo "Error: log file parent directory nonexistent: "$(dirname "$log_file") >&2
  exit 1
fi
if ! sensors >/dev/null 2>/dev/null; then
  echo "Error: \"sensors\" command not present. Please install lm-sensors package." >&2
  exit 1
fi

# Print an initial string of dots.
# Also, build a string of characters to iterate over later on, to make the loop
# prettier. It doesn't really make sense to do this, but just for fun..
pause_str=''
pause_ctr=$pause
while [[ $pause_ctr -gt 0 ]]; do
  if ! [[ "$log_file" ]]; then
    echo -n '.' 1>&2
  fi
  pause_str=$pause_str'p '
  pause_ctr=$((pause_ctr-1))
done
if ! [[ "$log_file" ]]; then
  echo -en '\t' 1>&2
fi

# Main loop.
while true; do

  sensor_data=$(sensors)

  temp1=$(echo "$sensor_data" | grep "$Line1Pattern" | sed -E "$TempRegex")
  temp2=$(echo "$sensor_data" | grep "$Line2Pattern" | sed -E "$TempRegex")
  temp3=$(echo "$sensor_data" | grep "$Line3Pattern" | sed -E "$TempRegex")

  if [[ "$log_file" ]]; then
    echo -en "$temp1\t$temp2\t$temp3\t" >> "$log_file"
    date +%s >> "$log_file"
  else
    echo -en "$temp1°C\t$temp2°C\t$temp3°C\t"
    date +%s
  fi

  if [[ "$log_file" ]]; then
    sleep "$pause"
  else
    for i in $pause_str; do
      echo -n '.' 1>&2
      sleep 1
    done
    echo -en '\t' 1>&2
  fi

done
