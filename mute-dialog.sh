#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue
unset CDPATH

MuteContinue="$HOME/.local/share/nbsdata/MUTE-CONTINUE"
Usage="Usage: \$ $(basename "$0") [delay]"

function main {

  # Get arguments.
  delay=60
  if [[ "$#" -ge 1 ]]; then
    if [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]]; then
      fail "$Usage"
    else
      delay="$1"
    fi
  fi

  touch "$MuteContinue"

  ask "$delay" &

  sleep "$delay"

  # Check if the user said to abort the mute. If not, continue with the muting.
  if [[ -f "$MuteContinue" ]]; then
    notify-send 'Muting..'
    amixer --quiet -D pulse set Master mute
  fi

  # Wait until the user has given a response.
  wait

  # If they have clicked "yes", then unmute.
  if ! [[ -f "$MuteContinue" ]]; then
    notify-send "Unmuting.."
    amixer --quiet -D pulse set Master unmute
  fi
}

function ask {
  local delay="$1"
  if [[ "$delay" == 60 ]]; then
    delay_human='1 minute'
  else
    delay_human="$delay"
  fi
  set +e
  zenity --question --text "Muting in $delay_human. Abort?"
  answer="$?"
  set -e
  if [[ "$answer" == 0 ]] && [[ -f "$MuteContinue" ]]; then
    rm "$MuteContinue"
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
