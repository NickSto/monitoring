#!/usr/bin/env bash
UPSTATUS="$HOME/.local/share/nbsdata/upstatus.txt"

temp=$(sensors | grep -A 3 '^coretemp-isa-0000' | tail -n 1 | awk '{print $3}' | sed -E -e 's/^\+//' -e 's/\.[0-9]+//')

updisp=$(cat "$UPSTATUS")

ping_line=$(tail -n 1 /home/me/aa/code/projects/uptest/logs/continuous.txt)
ping=$(echo "$ping_line" | cut -f 1)
# figure out if ping is old
ping_time=$(echo "$ping_line" | cut -f 2)
now=$(date +%s)
thres=$((now-30))
# if ping is old, mark it as not applicable
if [[ $ping_time -lt $thres ]] || [[ $updisp == '[OFFLINE]' ]]; then
  ping_str='N/A'
elif [[ $ping == 0 ]] || [[ $ping == 0.0 ]]; then
  ping_str='DROP'
else
  ping_str="$ping ms"
fi
# if ping is old, and upmonitor doesn't say it's offline, assume it's frozen
if [[ $updisp != '[OFFLINE]' ]] && [[ $ping_time -lt $thres ]]; then
  updisp='[STALLED]'
fi


echo "$updisp  $ping_str  $temp"
