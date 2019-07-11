#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Silence="$HOME/.local/share/nbsdata/SILENCE"
ConfigFileDefault=~/aa/computer/proxpn-config/proxpn.ovpn

Usage="Usage: \$ $(basename $0) [openvpn/config.ovpn]"

function main {

  if [[ $# -ge 1 ]]; then
    if [[ $1 == '-h' ]]; then
      fail "$Usage"
    fi
    config_file="$1"
  else
    config_file="$ConfigFileDefault"
  fi

  # Check requirements.
  if ! [[ -f $config_file ]]; then
    fail "Error: $config_file missing!"
  fi
  if [[ $EUID != 0 ]]; then
    fail "Error: Must be run as root."
  fi

  # When run with sudo, $USER will be "root", but $HOME will be the original user's home
  # directory. Use that to figure out who's actually running the script.
  if [[ -f /etc/passwd ]]; then
    # The passwd file should map home directories to users.
    user=$(awk -F : '$6 == "'$HOME'" {print $1}' /etc/passwd)
  else
    # As a fallback, just assume it's the $HOME directory name.
    user=$(basename $HOME)
  fi
  echo "Determined \$USER to be \"$user\"."

  # Check the SILENCE file and confirm.
  echo
  if [[ -e "$Silence" ]]; then
    echo "System is silenced. You want to make a VPN connection?"
  else
    echo "System is NOT silenced! Are you sure you want to continue?"
  fi
  read -p "Hit ENTER to continue or Ctrl+C to abort.
"

  # OpenVPN config file contains relative paths, so we need to be in its directory.
  config_dir=$(dirname "$config_file")
  cd $config_dir
  if [[ $? != 0 ]]; then
    fail "Error cd-ing into $config_dir"
  fi

  # Determine the interface name of the default route.
  interface=$(ip route show 0/0 | awk '{print $5}')
  if ! [[ $interface ]]; then
    fail "Error: network interface name not detected. Check your connection?"
  fi
  
  # Avoid IPv6 leaks
  if ! sysctl -w net.ipv6.conf.$interface.disable_ipv6=1; then
    echo "Error turning off ipv6. Is this the correct interface name? \"$interface\"" >&2
    return 1
  fi

  # Start the actual openvpn session.
  config_filename=$(basename "$config_file")
  openvpn --user $user --config $config_filename
  
  # Restore IPv6 functionality.
  sysctl -w net.ipv6.conf.$interface.disable_ipv6=0
  
  # Unsilence network traffic.
  rm $Silence
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
