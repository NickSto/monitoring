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
Line1Pattern='^Physical id 0:'
Line2Pattern='^Core 0:'
Line3Pattern='^Core 1:'
TempRegex='s/^.*:\s+[+-]([0-9]+)\.[0-9]+.C\s+\(.*$/\1/'
LogFile="$HOME/.local/share/nbsdata/temp.log"

pause=$PauseDefault
log=''
if [[ $# -gt 0 ]]; then
  pause=$1
  if [[ $pause == '-f' ]]; then
    log='yes'
    pause=$PauseDefault
    if [[ $# -gt 1 ]]; then
      pause=$2
    fi
  fi
fi

# Print an initial string of dots.
# Also, build a string of characters to iterate over later on, to make the loop
# prettier. It doesn't really make sense to do this, but just for fun..
pause_str=''
pause_ctr=$pause
while [[ $pause_ctr -gt 0 ]]; do
  if ! [[ $log ]]; then
    echo -n '.' 1>&2
  fi
  pause_str=$pause_str'p '
  pause_ctr=$((pause_ctr-1))
done
if ! [[ $log ]]; then
  echo -en '\t' 1>&2
fi

# Main loop.
while true; do

  temp1=$(sensors | grep "$Line1Pattern" | sed -E "$TempRegex")
  temp2=$(sensors | grep "$Line2Pattern" | sed -E "$TempRegex")
  temp3=$(sensors | grep "$Line3Pattern" | sed -E "$TempRegex")

  if [[ $log ]]; then
    echo -en "$temp1\t$temp2\t$temp3\t" >> $LogFile
    date +%s >> $LogFile
  else
    echo -en "$temp1°C\t$temp2°C\t$temp3°C\t"
    date +%s
  fi

  for i in $pause_str; do
    if ! [[ $log ]]; then
      echo -n '.' 1>&2
    fi
    sleep 1
  done
  if ! [[ $log ]]; then
    echo -en '\t' 1>&2
  fi

done
