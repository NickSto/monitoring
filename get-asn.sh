#!/usr/bin/env bash
if [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

DataDir="$HOME/.local/share/nbsdata"
Silence="$DataDir/SILENCE"
CacheFile="$DataDir/asn-cache.tsv"

function fail {
  echo "$1" >&2
  exit 1
}

if [[ -e $Silence ]]; then
  fail "Error: SILENCE file is present ($Silence). Cannot continue."
fi

# Status unknown and it's currently work hours. Does it look like we're at work?
#TODO: Cache public IP's by associating every combination of local IP & gateway
#      MAC address with its corresponding public IP.
ip=$(curl -s ipv4.icanhazip.com)
# Cache ASN lookups to prevent exceeding ipinfo.io API limits (1000 per day)
asn=$(awk -F '\t' '$1 == "'$ip'" {print $2}' $CacheFile | head -n 1)
if [[ ! $asn ]]; then
  asn=$(curl -s http://ipinfo.io/$ip/org | grep -Eo '^AS[0-9]+')
  if [[ $asn ]]; then
    echo -e "$ip\t$asn" >> $CacheFile
  fi
fi

echo $asn