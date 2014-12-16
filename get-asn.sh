#!/usr/bin/env bash
if [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue


DataDir="$HOME/.local/share/nbsdata"
Silence="$DataDir/SILENCE"
AsnCache="$DataDir/asn-cache.tsv"
AsnMacCache="$DataDir/asn-mac-cache.tsv"
# How long to trust cache entries (in seconds)?
TimeoutDefault=86400 # 1 day


function main {
  timeout=$TimeoutDefault
  now=$(date +%s)

  read gateway_ip interface <<< $(get_lan_ip_interface)
  mac=$(get_mac $gateway_ip $interface)

  if [[ $gateway_ip ]] && [[ $mac ]]; then
    # Look up ASN in cache file by gateway ip and mac
    read asn timestamp <<< $(awk '$1 == "'$mac'" && $2 == "'$gateway_ip'" \
      {print $3,$4}' $AsnMacCache | head -n 1)
    if [[ $((now-timestamp)) -lt $timeout ]]; then
      echo $asn
      exit
    fi
  fi

  if [[ -e $Silence ]]; then
    fail "Error: SILENCE file is present ($Silence). Cannot continue."
  fi

  # Failure to find ASN by gateway IP and MAC address.
  # Find the ASN using the traditional icanhazip.com -> ipinfo.io method.
  ip=$(curl -s ipv4.icanhazip.com)
  # Cache ASN lookups to prevent exceeding ipinfo.io API limits (1000 per day)
  asn=$(awk -F '\t' '$1 == "'$ip'" {print $2}' $AsnCache | head -n 1)
  if [[ ! $asn ]]; then
    asn=$(curl -s http://ipinfo.io/$ip/org | grep -Eo '^AS[0-9]+')
    if [[ $asn ]]; then
      echo -e "$ip\t$asn" >> $AsnCache
    fi
  fi

  if [[ $asn ]]; then
    echo $asn
  else
    fail "Error: Failure to find ASN."
  fi

  # Record the association between the gateway IP/MAC address and ASN.
  if [[ $gateway_ip ]] && [[ $mac ]]; then
    echo -e "$mac\t$gateway_ip\t$asn\t$now" >> $AsnMacCache
    # Remove stale entries from cache.
    clean_cache $AsnMacCache $timeout
  fi

}


# Remove entries from the $AsnMacCache which are older than $timeout
function clean_cache {
  read cache_file timeout <<< "$@"
  cache_file_bak="$cache_file.bak"
  now=$(date +%s)
  mv $cache_file $cache_file_bak
  awk "$now - \$4 <= $timeout {print \$0}" $cache_file_bak > $cache_file
}


# Get the LAN IP and interface of the default route.
function get_lan_ip_interface {
  ip route show \
    | awk '$1 == "default" && $2 == "via" && $4 == "dev" {print $3,$5}' \
    | head -n 1
}


# Look up the MAC address matching the given IP address on the given interface.
function get_mac {
  read ip interface <<< "$@"
  arp -a \
    | awk '$3 == "at" && $6 == "on" && $2 == "('$ip')" && $7 == "'$interface'" {print $4}'
}


function fail {
  echo "$1" >&2
  exit 1
}


main "$@"
