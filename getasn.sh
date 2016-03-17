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


Usage="Usage: $(basename $0) [-n] [-t timeout] [ip]
Look up the ASN (ISP) of an IP address, or if none is given, determine which ASN
you're connected to. Uses an API from an external site (ipinfo.io). However, by
using a cache, most of the time this will not make any connection to an external
site, or even create any network traffic at all. It will only do so if you move
to a different local network (identified by your gateway's IP and MAC) or the
cache entry expires.
Options:
-n: Don't use the cache to look up the ASN. Always query ipinfo.io. (Will still
    update the cache after a successful query).
-t: Use a cache expiration time of this many seconds. Default: $TimeoutDefault (1 day).
-m: Just look up the MAC address of the wifi router (or whatever is the first
    device on the default route).
Caches:
$AsnMacCache
$AsnIpCache"


function main {

  no_cache=
  only_mac=
  timeout=$TimeoutDefault
  while getopts ":t:nmh" opt; do
    case "$opt" in
      n) no_cache=true;;
      t) timeout="$OPTARG";;
      m) only_mac=true;;
      *) fail "$Usage";;
    esac
  done
  ip=${@:$OPTIND:1}

  if [[ $only_mac ]]; then
    [[ $Debug ]] && echo "Only looking up the gateway's MAC address.." >&2
    get_default_mac
  elif [[ $ip ]]; then
    [[ $Debug ]] && echo "IP address provided. Looking up ASN of $ip.." >&2
    get_ip_asn $ip $timeout $no_cache
  else
    [[ $Debug ]] && echo "No IP address provided. Looking up your current ASN.." >&2
    get_current_asn $timeout $no_cache
  fi
}


function get_ip_asn {
  read ip timeout no_cache <<< "$@"

  now=$(date +%s)

  # If enabled, look up ASN in cache file by ip.
  if [[ $no_cache ]]; then
    [[ $Debug ]] && echo "Skipping cache.." >&2
  else
    read asn timestamp <<< $(awk '$1 == "'$ip'" {print $2,$3; exit}' $AsnIpCache)
    if [[ $asn ]] && [[ $timestamp ]] && [[ $((now-timestamp)) -lt $timeout ]]; then
      [[ $Debug ]] && echo "Cache hit, $((now-timestamp)) seconds old." >&2
      echo $asn
      return 0
    else
      # Failure to find ASN in cache.
      [[ $Debug ]] && echo "Cache miss. Looking up using ipinfo.io.." >&2
    fi
  fi

  # Don't make the request if SILENCE is in effect.
  if [[ -e $Silence ]]; then
    fail "Error: SILENCE file is present ($Silence). Cannot continue."
  fi

  # Look up ASN using ipinfo.io. API limits requests to 1000 per day.
  asn=$(curl -s http://ipinfo.io/$ip/org | grep -Eo '^AS[0-9]+')

  if [[ $asn ]]; then
    [[ $Debug ]] && echo "Found using ipinfo.io." >&2
    echo $asn
  else
    fail "Error: Failure to find ASN."
  fi

  # Record the association between the IP address and ASN.
  # Don't add to the cache if we didn't use it. That could get us into the situation where we keep
  # adding duplicate entries to the cache, and they aren't cleaned out for a long time (when they
  # expire, which could be a day or longer).
  if ! [[ $no_cache ]]; then
    [[ $Debug ]] && echo "Cleaning cache.." >&2
    echo -e "$ip\t$asn\t$now" >> $AsnIpCache
    # Remove stale entries from cache.
    clean_cache $AsnIpCache $timeout 3
  fi
}


function get_current_asn {
  read timeout no_cache <<< "$@"

  asn=''
  now=$(date +%s)

  # Get info about the current LAN.
  read gateway_ip interface <<< $(get_lan_ip_interface)
  mac=$(get_mac $gateway_ip $interface)

  if [[ $no_cache ]]; then
    [[ $Debug ]] && echo "Skipping cache.." >&2
  else
    [[ $Debug ]] && echo "Found gateway IP \"$gateway_ip\" and MAC address \"$mac\" of interface \"$interface\"." >&2
    # Look up ASN in cache file by gateway ip and mac.
    read asn timestamp <<< $(awk '$1 == "'$mac'" && $2 == "'$gateway_ip'" {print $3,$4; exit}' $AsnMacCache)
    if [[ $asn ]] && [[ $timestamp ]] && [[ $((now-timestamp)) -lt $timeout ]]; then
      [[ $Debug ]] && echo "Cache hit." >&2
      echo $asn
      return 0
    else
      # Failure to find ASN by gateway IP and MAC address.
      [[ $Debug ]] && echo "Cache miss. Looking up ASN with ipinfo.io.." >&2
    fi
  fi

  # Don't make the request, if SILENCE is in effect.
  if [[ -e $Silence ]]; then
    fail "Error: SILENCE file is present ($Silence). Cannot continue."
  fi

  # Get ASN using ipinfo.io. API limits requests to 1000 per day.
  asn=$(curl -s http://ipinfo.io/org | grep -Eo '^AS[0-9]+')

  if [[ $asn ]]; then
    [[ $Debug ]] && echo "Found using ipinfo.io." >&2
    echo $asn
  else
    fail "Error: Failure to find ASN."
  fi

  # Record the association between the gateway IP/MAC address and ASN.
  # Don't add to the cache if we didn't use it. That could get us into the situation where we keep
  # adding duplicate entries to the cache, and they aren't cleaned out for a long time (when they
  # expire, which could be a day or longer).
  if ! [[ $no_cache ]] && [[ $gateway_ip ]] && [[ $mac ]]; then
    [[ $Debug ]] && echo "Cleaning cache.." >&2
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


# Get the MAC address of the device on the default route.
function get_default_mac {
  read gateway_ip interface <<< $(get_lan_ip_interface)
  get_mac $gateway_ip $interface
}


# Get the LAN IP and interface of the default route.
function get_lan_ip_interface {
  /sbin/ip route show \
    | awk '$1 == "default" && $2 == "via" && $4 == "dev" {print $3,$5; exit}'
}


# Look up the MAC address matching the given IP address on the given interface.
function get_mac {
  read ip interface <<< "$@"
  /usr/sbin/arp -an -i $interface $ip | awk '{print $4}'
}


function fail {
  echo "$1" >&2
  exit 1
}


main "$@"
