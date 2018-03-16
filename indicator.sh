#!/usr/bin/env bash
DataDir="$HOME/.local/share/nbsdata"

# Comment out a line to exclude the field.
Fields=disk
Fields="$Fields wifilogin"
Fields="$Fields pings"
Fields="$Fields lastping"
Fields="$Fields temp"
# Fields="$Fields ssid"
# Fields="$Fields timestamp"

Now=$(date +%s)

function main {
  output=''
  for field in $Fields; do
    fxn="get_$field"
    str=$($fxn)
    if [[ $str ]]; then
      # Does the string already start with a '['?
      # Bash freaks out with a literal '[', so use a workaround.
      ord=$(printf '%d' "'${str:0:1}")
      if [[ $ord == 91 ]]; then
        output="$output$str"
      else
        output="$output[ $str ]"
      fi
    fi
  done
  echo "$output"
}

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

# Unix time
function get_timestamp {
  echo $Now
}

# Wifi SSID
function get_ssid {
  iwconfig 2> /dev/null | sed -nE 's/^.*SSID:"(.*)"\s*$/\1/pig' | head -n 1
}

# Free disk space
# Shows free space for any mounted device under /dev that's not mounted under /boot.
function get_disk {
  df -h | awk 'substr($1, 1, 5) == "/dev/" && substr($6, 1, 5) != "/boot" {printf("%s,", $4)}' | head -c -1
}

# CPU temperature
function get_temp {
  sensors | grep -A 3 '^coretemp-isa-0000' | tail -n 1 | awk '{print $3}' | sed -E -e 's/^\+//' -e 's/\.[0-9]+//'
}

# Variables that depend on reading upmonitor status files.
# Can't have them in separate functions because they have interactions.
pings_global=
lastping_global=
upmonitor_read=
# Network connectivity monitor
function get_pings {
  if ! [[ $upmonitor_read ]]; then
    read_upmonitor_files
  fi
  echo "$pings_global"
}
# Last ping latency
function get_lastping {
  if ! [[ $upmonitor_read ]]; then
    read_upmonitor_files
  fi
  echo "$lastping_global"
}
# Underlying function to read the upmonitor status files.
function read_upmonitor_files {
  local lastping
  local pings=$(cat "$DataDir/upstatus.txt")
  logfile=$(grep -E ^logfile "$DataDir/upmonitor.cfg" | sed -E 's/^logfile\s*=\s*//')
  if [[ $logfile ]] && [[ -f $logfile ]]; then
    read ping ping_time rest <<< $(tail -n 1 "$logfile")
  fi
  # If ping is old, mark it as not applicable.
  if [[ $ping == 0 ]] || [[ $ping == 0.0 ]]; then
    lastping='DROP'
  else
    lastping="$ping ms"
  fi
  # How old is the last ping?
  if [[ $ping_time ]]; then
    now=$Now
    age=$((now - ping_time))
    age_str=$(human_time $age)
    if [[ $age -lt 300 ]];  then
      lastping="$lastping / $age_str ago"
    else
      lastping="N/A ms / $age_str ago"
    fi
  elif ! [[ -f "$DataDir/upmonitor.cfg" ]]; then
    lastping='no upmonitor.cfg'
  elif ! [[ -f $logfile ]]; then
    lastping='no log'
  elif ! [[ "$(tail -n 1 "$logfile")" ]]; then
    lastping='empty log line'
  else
    lastping='error'
  fi
  # If ping is old, and upmonitor doesn't say it's offline, assume it's frozen.
  if [[ $pings != '[OFFLINE]' ]] && [[ $ping_time -lt $thres ]]; then
    pings='[STALLED]'
  fi
  pings_global="$pings"
  lastping_global="$lastping"
  upmonitor_read=true
}


# wifi-login2.py log file messages, if it's running.
function get_wifilogin {
  # If the wifi-login script is running, include its current status from its log file.
  # Get the log file it's printing to from its entry in ps aux. Also get its pid.
  awkscript='
  $11 == "python" && $12 ~ /wifi-login2\.py$/ {
    for (i = 13; i <= NF; i++) {
      if ($i == "-l" || $i == "--log") {
        i++
        print $i, $2
        break
      }
    }
  }'
  read log pid <<< $(ps aux | awk "$awkscript")
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
}

main "$@"
