#!/usr/bin/env bash
set -ue

#TODO: Also allow identifying a work environment by an IP address. Allows places like specific
#      coffee shops which don't have their own ASN.

Debug=${Debug:-}
DayStart="8"   # 8:00AM
DayEnd="18"    # 6:00PM
Weekdays=true  # Only activate on weekdays.
WorkAsns="AS3999 AS46749 AS25"
# AS3999:  Penn State
# AS46749: Stanford
# AS25:    UC Berkeley
WorkMacs="00:18:5a:58:56:20"
# 00:18:5a:58:56:20: Peet's Menlo Park

DataDir="$HOME/.local/share/nbsdata"
Silence="$DataDir/SILENCE"
StatusFile="$DataDir/mute-checked"
Usage="Usage: \$ $(basename $0)
Mute if it's work hours and we're at work (based on the ASN of your network). Requires a connection
to look up your IP address. The workday is defined as between the hours of $DayStart and $DayEnd on weekdays.
The current ASNs defined as workplaces are: $WorkAsns.
If it sees the file $StatusFile exists, it will assume we've already
checked today and it won't run.
Options:
-n: Run now, regardless of work hours/days."


function main {
  
  if [[ -e $Silence ]]; then
    exit
  fi

  now=
  if [[ $# -gt 0 ]]; then
    if [[ $1 == '-h' ]]; then
      echo "$Usage" >&2
      exit 1
    elif [[ $1 == '-n' ]]; then
      now=true
    fi
  fi

  # Exit if it's not currently work hours. If -n was given, run now regardless of the time.
  if ! [[ $now ]]; then
    day=$(date +%u)
    if [[ $Weekdays ]] && ([[ $day -lt 1 ]] || [[ $day -gt 5 ]]); then
      [[ $Debug ]] && echo "It's not a weekday. Exiting.." >&2
      exit 0
    fi
    now_hour=$(date +%k)
    if [[ $now_hour -lt $DayStart ]] || [[ $now_hour -ge $DayEnd ]]; then
      [[ $Debug ]] && echo "It's not work hours ($DayStart:00 to $DayEnd:59). Exiting.." >&2
      exit 0
    fi
  fi

  # Check status file to know if we've already checked today.
  today=$(date +%F)
  if [[ -e $StatusFile ]]; then
    [[ $Debug ]] && echo "Status file $StatusFile already exists." >&2
    file_date=$(stat -c '%y' $StatusFile | awk '{print $1}')
    # If status file is present and from today, we've already checked. Exit.
    if [[ $file_date == $today ]]; then
      [[ $Debug ]] && echo "Status file is from today. We've already checked. Exiting.." >&2
      exit 0
    else
      [[ $Debug ]] && echo "Status file is stale. Need to perform check again." >&2
    fi
  fi

  # Status unknown and it's currently work hours. Does it look like we're at work?
  get_asn=$(get_command 'getasn.sh')

  # Check if it's a work MAC address.
  mac=$(bash $get_asn -m | tr [:upper:] [:lower:])
  [[ $Debug ]] && echo "Got gateway's MAC address: $mac" >&2
  for work_mac in $WorkMacs; do
    if [[ $mac == $work_mac ]]; then
      [[ $Debug ]] && echo "MAC address matches a work MAC address." >&2
      work_action
      touch $StatusFile
      exit 0
    fi
  done
  [[ $Debug ]] && echo "Your MAC address doesn't match a work MAC address." >&2

  # No luck? Check if it's a work ASN.
  asn=$(bash $get_asn)
  [[ $Debug ]] && echo "Got your current network's ASN: $asn" >&2
  for work_asn in $WorkAsns; do
    if [[ $asn == $work_asn ]]; then
      [[ $Debug ]] && echo "ASN matches a work ASN." >&2
      work_action
      touch $StatusFile
      exit 0
    fi
  done
  [[ $Debug ]] && echo "Your ASN doesn't match a work ASN." >&2
}


# what to do if we're found to be at work for the first time today?
function work_action {
  # mute sound
  # amixer --quiet set Master toggle  # old method
  [[ $Debug ]] && echo "Muting sound.." >&2
  amixer --quiet -D pulse set Master toggle
}


# Get the script's actual directory path.
function real_dir {
  if readlink -f test >/dev/null 2>/dev/null; then
    dirname $(readlink -f $0)
  else
    # If readlink -f doesn't work (like on BSD).
    # Read the link destination from the output of ls -l and cd to it.
    # Have to cd to the link's directory first, to handle relative links.
    # Currently only works with one level of linking.
    cd $(dirname $0)
    script=$(basename $0)
    link=$(ls -l $script | awk '{print $NF}')
    cd $(dirname $link)
    pwd
  fi
}


# Return the command needed to execute a script that is either on the PATH or
# in this script's directory.
function get_command {
  command="$1"
  # Is it simply on the PATH?
  if which $command >/dev/null 2>/dev/null; then
    echo "$command"
    return
  fi
  path=$(real_dir)/$command
  if [[ -x $path ]]; then
    echo "$path"
  else
    return 1
  fi
}


main "$@"
