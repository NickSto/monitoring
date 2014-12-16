#!/usr/bin/env bash
set -ue

DATA_DIR="$HOME/.local/share/nbsdata"
SILENCE="$DATA_DIR/SILENCE"
STATUS_FILE="$DATA_DIR/mute-checked"
CACHE_FILE="$DATA_DIR/asn-cache.tsv"

DAY_START="8" # 8:00AM
DAY_END="18"  # 6:00PM
WORK_ASNS="AS3999 AS25"
# AS3999: Penn State
# AS25:   UC Berkeley

# what to do if we're found to be at work for the first time today?
function work_action {
  # mute sound
  amixer --quiet set Master toggle
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
    echo "$bin_path"
  fi
  path=$(real_dir)/$command
  if [[ -x $path ]]; then
    echo "$path"
  else
    return 1
  fi
}


if [[ -e $SILENCE ]]; then
  exit
fi

# Not currently work hours? Exit.
now_hour=$(date +%H)
if [[ $now_hour -lt $DAY_START ]] || [[ $now_hour -ge $DAY_END ]]; then
  exit 0
fi

# Check status file to know if we've already checked today.
today=$(date +%F)
if [[ -e $STATUS_FILE ]]; then
  file_date=$(stat -c '%y' $STATUS_FILE | awk '{print $1}')
  # If status file is present and from today, we've already checked. Exit.
  if [[ $file_date == $today ]]; then
    exit 0
  fi
fi

# Status unknown and it's currently work hours. Does it look like we're at work?
get_asn=$(get_command 'get-asn.sh')
asn=$($get_asn)

for work_asn in $WORK_ASNS; do
  if [[ $asn == $work_asn ]]; then
    work_action
    touch $STATUS_FILE
  fi
done
