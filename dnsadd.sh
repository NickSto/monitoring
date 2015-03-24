#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

ConfigFile="/etc/dnsmasq.conf"

command=$(basename $0)
USAGE="Usage: \$ sudo $command [add|rm] example.com
\"add\" does a DNS lookup for the given domain to get its IP address, then adds
a line like \"address=/example.com/10.11.12.13\" to the dnsmasq config file
\"$ConfigFile\" so lookups for that domain (and all subdomains) are done
locally."

function main {
  
  if [[ $# -lt 1 ]] || [[ $1 == '-h' ]]; then
    fail "$USAGE"
  fi

  if [[ ! -f "$ConfigFile" ]]; then
    fail "Error: Missing config file \"$ConfigFile\"."
  fi

  if [[ $EUID != 0 ]]; then
    fail "Error: Must run as root"
  fi

  if [[ $# == 1 ]]; then
    action="add"
    domain="$1"
  else
    action="$1"
    domain="$2"
  fi

  if [[ $action == "add" ]]; then
    ip=$(dig +short $domain | tail -n 1)
    if [[ ! $ip ]]; then
      fail "Error: DNS lookup for $domain failed."
    fi
    if grep -q "^address=/$domain/" "$ConfigFile"; then
      fail "Error: $domain already in $ConfigFile. Use rm first."
    fi
    echo "address=/$domain/$ip" | tee -a "$ConfigFile"
    service dnsmasq restart
  elif [[ $action == "rm" ]] || [[ $action == "remove" ]]; then
    if grep -q "^address=/$domain/" "$ConfigFile"; then
      echo "removing $domain..."
    else
      fail "$domain not in $ConfigFile"
    fi
    tempfile=$(tempfile)
    #TODO: keep "." in domain names being interpreted as regex wildcard
    grep -v "^address=/$domain/" "$ConfigFile" > $tempfile
    chmod 0644 $tempfile
    mv $tempfile "$ConfigFile" || rm $tempfile
    service dnsmasq restart
  else
    fail "Error: Unrecognized command \"$1\"."
  fi

}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
