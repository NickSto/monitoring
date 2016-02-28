#!/usr/bin/env bash
DataDir="$HOME/.local/share/nbsdata"

function human_time {
  total_sec=$1
  sec=$((total_sec % 60))
  total_min=$((total_sec/60))
  min=$((total_min % 60))
  total_hr=$((total_min/60))
  hr=$((total_hr % 24))
  days=$((total_hr/24))
  if [[ $days == 1 ]]; then
    days_str='1 day '
  else
    days_str="$days days "
  fi
  hr_str="$hr:"
  min_str="$min:"
  sec_str=$sec
  if [[ $min -lt 10 ]] && [[ $total_min -ge 60 ]]; then
    min_str="0$min:"
  fi
  if [[ $sec -lt 10 ]] && [[ $total_sec -ge 60 ]]; then
    sec_str="0$sec"
  elif [[ $total_sec -lt 60 ]]; then
    sec_str="${sec}s"
  fi
  if [[ $days == 0 ]]; then
    days_str=''
    if [[ $hr == 0 ]]; then
      hr_str=''
      if [[ $min == 0 ]]; then
        min_str=''
        if [[ $sec == 0 ]]; then
          sec_str='0s'
        fi
      fi
    fi
  fi
  echo "$days_str$hr_str$min_str$sec_str"
}

# $free: free disk space
free=$(df -h | grep -E ' /$' | awk '{print $4}')

# $temp: CPU temperature
temp=$(sensors | grep -A 3 '^coretemp-isa-0000' | tail -n 1 | awk '{print $3}' | sed -E -e 's/^\+//' -e 's/\.[0-9]+//')

# $updisp: Network connectivity monitor
updisp=$(cat "$DataDir/upstatus.txt")

# $ping_str: Last ping latency
logfile=$(grep -E ^logfile "$DataDir/upmonitor.cfg" | sed -E 's/^logfile\s*=\s*//')
if [[ $logfile ]] && [[ -f $logfile ]]; then
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
  age_str=$(human_time $age)
  if [[ $age -lt 300 ]];  then
    ping_str="$ping_str / $age_str ago"
  else
    ping_str="N/A ms / $age_str ago"
  fi
elif ! [[ -f "$DataDir/upmonitor.cfg" ]]; then
  ping_str='no upmonitor.cfg'
elif ! [[ -f $logfile ]]; then
  ping_str='no log'
elif ! [[ "$(tail -n 1 "$logfile")" ]]; then
  ping_str='empty log line'
else
  ping_str='error'
fi
# if ping is old, and upmonitor doesn't say it's offline, assume it's frozen
if [[ $updisp != '[OFFLINE]' ]] && [[ $ping_time -lt $thres ]]; then
  updisp='[STALLED]'
fi

# If the wifi-login script is running, include its current status from its log file.
# Get the log file it's printing to from its entry in ps aux. Also get its pid.
read log pid <<< $(ps aux | awk '$11 == "python" && $12 ~ /wifi-login2\.py$/ {for (i = 13; i <= NF; i++) {if ($i == "-l" || $i == "--log") {i++; print $i, $2; break}}}')
login_status=
if [[ $pid ]]; then
  if [[ ${log:0:1} == "/" ]]; then
    # $log is an absolute path.
    log_path=$log
  else
    # $log is a relative path. Piece its absolute path together using the process' working directory.
    wd=$(pwdx $pid | awk '{print $2}')
    log_path=$wd/$log
  fi
  if [[ -s $log_path ]]; then
    # Get the most recent log message.
    log_line=$(tail -n 1 $log_path | sed -E 's/^[^:]+: //')
    if [[ ${#log_line} -gt 35 ]]; then
      login_status="[ ${log_line:0:35}.. ]"
    else
      login_status="[ $log_line ]"
    fi
  fi
fi

echo "[ $free free ]$login_status$updisp[ $ping_str ][ $temp ]"
