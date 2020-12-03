#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

ScriptDir=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
source "$ScriptDir/dbuslib.sh"

DefaultPowerLog="$HOME/aa/computer/logs/power.log"
Usage="Usage: \$ $(basename "$0") [options] [power.log]
Options:
-v: Verbose mode."

function main {

  # Get arguments.
  verbose=
  while getopts "vh" opt; do
    case "$opt" in
      v) verbose=true;;
      [h?]) fail "$Usage";;
    esac
  done
  power_log="${@:$OPTIND:1}"

  if ! [[ "$power_log" ]]; then
    power_log="$DefaultPowerLog"
  fi
  if ! [[ -f "$power_log" ]]; then
    fail "Error: $power_log file not found."
  fi

  dbus_address=$(get_dbus_address)
  if [[ "$dbus_address" ]]; then
    if [[ "$verbose" ]]; then
      printf "%s\tGot dbus address '%s'\n" "$(date)" "$dbus_address" >&2
    fi
    export DBUS_SESSION_BUS_ADDRESS="$dbus_address"
  else
    fail "Error: Could not find the DBUS_SESSION_BUS_ADDRESS."
  fi

  set +e
  tail -n 0 -f "$power_log" | while read timestamp timing event; do
    if [[ "$event" == 'lock' ]] && [[ "$timing" == 'post' ]]; then
      if [[ "$verbose" ]]; then
        printf '%s\tToggling natural scrolling.\n' "$(date)" >&2
      fi
      gsettings set org.gnome.desktop.peripherals.mouse natural-scroll false
      gsettings set org.gnome.desktop.peripherals.mouse natural-scroll true
    fi
  done

}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
