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
#TODO: Cache public IP's by associating every combination of local IP & gateway
#      MAC address with its corresponding public IP.
ip=$(curl -s ipv4.icanhazip.com)
# Cache ASN lookups to prevent exceeding ipinfo.io API limits (1000 per day)
asn=$(awk -F '\t' '$1 == "'$ip'" {print $2}' $CACHE_FILE | head -n 1)
if [[ ! $asn ]]; then
  asn=$(curl -s http://ipinfo.io/$ip/org | grep -Eo '^AS[0-9]+')
  if [[ $asn ]]; then
    echo -e "$ip\t$asn" >> $CACHE_FILE
  fi
fi
for work_asn in $WORK_ASNS; do
  if [[ $asn == $work_asn ]]; then
    work_action
    touch $STATUS_FILE
  fi
done
