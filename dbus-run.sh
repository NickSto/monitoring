#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

ScriptDir=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
source "$ScriptDir/dbuslib.sh"

Usage="Usage: \$ $(basename "$0") command [args]
This is a wrapper script for commands that need to be executed with the DBUS_SESSION_BUS_ADDRESS
environment variable set properly first. Just prefix your command with this one and it will
automatically set the environment appropriately, then execute your command.
This is useful for environments like cron that don't have the right dbus environment set up."

function main {

  dbus_address=$(get_dbus_address)

  if [[ "$dbus_address" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="$dbus_address"
  else
    fail "Error: Could not find the DBUS_SESSION_BUS_ADDRESS."
  fi

  "$@"
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
