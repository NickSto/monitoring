#!/usr/bin/env bash
UPSTATUS="$HOME/.local/share/nbsdata/upstatus.txt"

# $free: free disk space
free=$(df -h | grep -E ' /$' | awk '{print $4}')

# $temp: CPU temperature
temp=$(sensors | grep -A 3 '^coretemp-isa-0000' | tail -n 1 | awk '{print $3}' | sed -E -e 's/^\+//' -e 's/\.[0-9]+//')

# $updisp: Network connectivity monitor
updisp=$(cat "$UPSTATUS")

# $ping_str: Last ping latency
read ping ping_time rest <<< $(tail -n 1 /home/me/code/projects/uptest/logs/continuous.txt)
# figure out if ping is old
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


echo "| $free free | $updisp  $ping_str | $temp"
