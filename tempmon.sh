#!/usr/bin/env bash
# Continually monitor CPU temperature using the lm-sensors package
# 
# Currently built for only one particular computer's output of the 'sensors'
# command (that of the Asus ZenBook Prime). Example output:
#  acpitz-virtual-0
#  Adapter: Virtual device
#  temp1:        +74.0°C  (crit = +108.0°C)

#  asus-isa-0000
#  Adapter: ISA adapter
#  temp1:        +74.0°C  

#  coretemp-isa-0000
#  Adapter: ISA adapter
#  Physical id 0:  +76.0°C  (high = +87.0°C, crit = +105.0°C)
#  Core 0:         +76.0°C  (high = +87.0°C, crit = +105.0°C)
#  Core 1:         +70.0°C  (high = +87.0°C, crit = +105.0°C)
set -ue


PAUSE_DEFAULT=15
LOG_DEFAULT='no'
LINE1_PATTERN="'^Physical id 0:'"
LINE2_PATTERN="'^Core 0:'"
LINE3_PATTERN="'^Core 1:'"
TEMP_REGEX="'s/^.*:\s+[+-]([0-9]+)\.[0-9]+.C\s+\(.*$/\1/'"
LOG_FILE='/home/me/.local/share/nbsdata/temp.log'

pause=$PAUSE_DEFAULT
log=$LOG_DEFAULT
if [ $# -gt 0 ]; then
  pause=$1
  if [ $pause == '-f' ]; then
    log='yes'
    pause=$PAUSE_DEFAULT
    if [ $# -gt 1 ]; then
      pause=$2
    fi
  fi
fi

# Print an initial string of dots.
# Also, build a string of characters to iterate over later on, to make the loop
# prettier. It doesn't really make sense to do this, but just for fun..
pause_str=''
pause_ctr=$pause
while [ $pause_ctr -gt 0 ]; do
  if [ $log == 'no' ]; then
    echo -n '.' 1>&2
  fi
  pause_str=$pause_str'p '
  pause_ctr=$((pause_ctr-1))
done
if [ $log == 'no' ]; then
  echo -en '\t' 1>&2
fi

while [[ 1 ]]; do

  cmd1="sensors | grep "$LINE1_PATTERN" | sed -r "$TEMP_REGEX
  cmd2="sensors | grep "$LINE2_PATTERN" | sed -r "$TEMP_REGEX
  cmd3="sensors | grep "$LINE3_PATTERN" | sed -r "$TEMP_REGEX
  temp1=`eval $cmd1`
  temp2=`eval $cmd2`
  temp3=`eval $cmd3`

  if [ $log == 'yes' ]; then
    echo -en "$temp1\t$temp2\t$temp3\t" >> $LOG_FILE
    date +%s >> $LOG_FILE
  else
    echo -en "$temp1°C\t$temp2°C\t$temp3°C\t"
    date +%s
  fi

  for i in $pause_str; do
    if [ $log == 'no' ]; then
      echo -n '.' 1>&2
    fi
    sleep 1
  done
  if [ $log == 'no' ]; then
    echo -en '\t' 1>&2
  fi

done
