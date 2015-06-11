#!/usr/bin/env bash
DataDir="$HOME/.local/share/nbsdata"

# $free: free disk space
free=$(df -h | grep -E ' /$' | awk '{print $4}')

# $temp: CPU temperature
temp=$(sensors | grep -A 3 '^coretemp-isa-0000' | tail -n 1 | awk '{print $3}' | sed -E -e 's/^\+//' -e 's/\.[0-9]+//')

# $updisp: Network connectivity monitor
updisp=$(cat "$DataDir/upstatus.txt")

# $ping_str: Last ping latency
logfile=$(grep -E ^logfile "$DataDir/upmonitor.cfg" | sed -E 's/^logfile\s*=\s*//')
if [[ $logfile ]] && [[ -s $logfile ]]; then
  read ping ping_time rest <<< $(tail -n 1 "$logfile")
fi
# If ping is old, mark it as not applicable.
if [[ $ping == 0 ]] || [[ $ping == 0.0 ]]; then
  ping_str='DROP'
else
  ping_str="$ping ms"
fi
# How old is the last ping?
if [[ $ping_time ]]; then
  now=$(date +%s)
  age=$((now - ping_time))
  if [[ $age -lt 300 ]];  then
    ping_str="$ping_str / ${age}s ago"
  else
    ping_str="N/A ms / ${age}s ago"
  fi
else
  ping_str="no file"
fi
# if ping is old, and upmonitor doesn't say it's offline, assume it's frozen
if [[ $updisp != '[OFFLINE]' ]] && [[ $ping_time -lt $thres ]]; then
  updisp='[STALLED]'
fi

echo "[ $free free ]$updisp[ $ping_str ][ $temp ]"
