#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

# From https://askubuntu.com/questions/742870/background-not-changing-using-gsettings-from-cron/743024#743024
Usage="Usage: \$ $(basename "$0") [gsettings args]
This is intended to be a drop-in replacement for the 'gsettings' command that works in cron and
other similar environments without the proper variables and such."

function main {

  dbus_address=$(get_dbus_address)

  if [[ "$dbus_address" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="$dbus_address"
  else
    fail "Error: Could not find the DBUS_SESSION_BUS_ADDRESS."
  fi

  gsettings "$@"
}

function get_dbus_address {
  get_dbus_var | sed -E -e 's/\x0//g' -e 's/^[^=]+=//'
}

function get_dbus_var {
  pgrep gnome-session | while read pid; do
    set +e
    grep -z '^DBUS_SESSION_BUS_ADDRESS=' "/proc/$pid/environ"
    if [[ "$?" == 0 ]]; then
      return
    fi
  done
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
