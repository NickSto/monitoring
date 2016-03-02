#!/usr/bin/env bash
if [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -u


Debug=${Debug:-}
DataDir="$HOME/.local/share/nbsdata"
Silence="$DataDir/SILENCE"
AsnMacCache="$DataDir/asn-mac-cache.tsv"
AsnIpCache="$DataDir/asn-ip-cache.tsv"
# How long to trust cache entries (in seconds)?
TimeoutDefault=86400 # 1 day


Usage="Usage: $(basename $0) [-t timeout] [ip]
Look up the ASN (ISP) of an IP address, or if none is given, determine which ASN
you're connected to. Uses an API from an external site (ipinfo.io). However, by
using a cache, most of the time this will not make any connection to an external
site, or even create any network traffic at all. It will only do so if you move
to a different local network (identified by your gateway's IP and MAC) or the
cache entry expires. By default, cache entries expire in $TimeoutDefault seconds
(1 day), but this can be changed with the -t argument."


function main {

  timeout=$TimeoutDefault
  while getopts ":t:h" opt; do
    case "$opt" in
      t) timeout="$OPTARG";;
      *) fail "$Usage";;
    esac
  done
  ip=${@:$OPTIND:1}

  if [[ $ip ]]; then
    [[ $Debug ]] && echo "IP address provided. Looking up ASN of $ip.." >&2
    get_ip_asn $ip $timeout
  else
    [[ $Debug ]] && echo "No IP address provided. Looking up your current ASN.." >&2
    get_current_asn $timeout
  fi
}


function get_ip_asn {
  read ip timeout <<< "$@"

  now=$(date +%s)

  # Look up ASN in cache file by ip.
  read asn timestamp <<< $(awk '$1 == "'$ip'" {print $2,$3}' $AsnIpCache | head -n 1)
  if [[ $asn ]] && [[ $timestamp ]] && [[ $((now-timestamp)) -lt $timeout ]]; then
    [[ $Debug ]] && echo "Cache hit, $((now-timestamp)) seconds old." >&2
    echo $asn
    exit
  fi

  # Failure to find ASN in cache.
  [[ $Debug ]] && echo "Cache miss. Looking up using ipinfo.io.." >&2

  # Don't make the request, if SILENCE is in effect.
  if [[ -e $Silence ]]; then
    fail "Error: SILENCE file is present ($Silence). Cannot continue."
  fi

  asn=$(curl -s http://ipinfo.io/$ip/org | grep -Eo '^AS[0-9]+')

  if [[ $asn ]]; then
    [[ $Debug ]] && echo "Found using ipinfo.io." >&2
    echo $asn
  else
    fail "Error: Failure to find ASN."
  fi

  # Record the association between the gateway IP/MAC address and ASN.
  [[ $Debug ]] && echo "Cleaning cache.." >&2
  echo -e "$ip\t$asn\t$now" >> $AsnIpCache
  # Remove stale entries from cache.
  clean_cache $AsnIpCache $timeout 3
}


function get_current_asn {
  read timeout <<< "$@"

  asn=''
  now=$(date +%s)

  # Get info about the current LAN.
  read gateway_ip interface <<< $(get_lan_ip_interface)
  mac=$(get_mac $gateway_ip $interface)

  # Look up ASN in cache file by gateway ip and mac.
  if [[ $gateway_ip ]] && [[ $mac ]]; then
    read asn timestamp <<< $(awk '$1 == "'$mac'" && $2 == "'$gateway_ip'" \
      {print $3,$4}' $AsnMacCache | head -n 1)
    if [[ $((now-timestamp)) -lt $timeout ]]; then
      echo $asn
      exit
    fi
  fi

  # Failure to find ASN by gateway IP and MAC address.
  # We'll have to reach out to an outside service to get the ASN.

  # Don't make the request, if SILENCE is in effect.
  if [[ -e $Silence ]]; then
    fail "Error: SILENCE file is present ($Silence). Cannot continue."
  fi

  # Get ASN using ipinfo.io. API limits requests to 1000 per day.
  if ! [[ $asn ]]; then
    asn=$(curl -s http://ipinfo.io/org | grep -Eo '^AS[0-9]+')
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
    clean_cache $AsnMacCache $timeout 4
  fi

}


# Remove entries from the $AsnMacCache which are older than $timeout
function clean_cache {
  read cache_file timeout time_column <<< "$@"
  cache_file_bak="$cache_file.bak"
  now=$(date +%s)
  mv $cache_file $cache_file_bak
  awk "$now - \$$time_column <= $timeout {print \$0}" $cache_file_bak > $cache_file
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
  /usr/sbin/arp -a \
    | awk '$3 == "at" && $6 == "on" && $2 == "('$ip')" && $7 == "'$interface'" {print $4}'
}


function fail {
  echo "$1" >&2
  exit 1
}


main "$@"
