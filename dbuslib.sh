#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

# From https://askubuntu.com/questions/742870/background-not-changing-using-gsettings-from-cron/743024#743024

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

