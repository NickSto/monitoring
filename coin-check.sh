#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

DataDir="$HOME/.local/share/nbsdata"
SilenceFile="$DataDir/SILENCE"
ThresFile="$DataDir/coin-price.txt"
PidFile="$DataDir/coin-check.pid"

Usage="Usage: \$ $(basename $0) [options] [upper [lower]]
Check the price of bitcoin and send a notification if it's above (or below) a
certain price threshold.
Options:
-t: Print the results to stdout in human-readable text.
-n: Display a GUI notification if the price is outside the bounds."

function main {

  # Debug mode: Simulate receiving a price from the API.
  debug=
  if [[ "$#" -ge 2 ]] && [[ "$1" == '-D' ]]; then
    debug="$2"
    shift 2
  fi

  # Get arguments.
  text=
  notify=
  while getopts "htn" opt; do
    case "$opt" in
      t) text="true";;
      n) notify="true";;
      [h?]) fail "$Usage";;
    esac
  done
  upper="${@:$OPTIND:1}"
  lower="${@:$OPTIND+1:1}"

  if [[ -e "$SilenceFile" ]]; then
    fail "Error: SILENCE file is present ($Silence). Cannot continue."
  fi

  if [[ -f "$PidFile" ]]; then
    last_pid=$(cat "$PidFile")
    set +e
    if ps -o comm="" -p "$last_pid" 2>/dev/null >/dev/null; then
      fail "Error: An instance is already running at pid $last_pid"
    fi
    set -e
  fi
  echo "$$" > "$PidFile"

  # Get the price thresholds.
  current=
  if ! [[ "$upper" ]]; then
    if [[ -s "$ThresFile" ]]; then
      current=$(cat "$ThresFile")
      if ! is_int "$current"; then
        current=
      fi
    fi
    if ! [[ "$current" ]]; then
      fail "Error: Couldn't get a valid price from file \"$ThresFile\""
    fi
    upper=$((current+1000))
    lower=$((current-1000))
  elif ! [[ "$lower" ]]; then
    lower=0
  fi

  # Validate bounds.
  if ! is_int "$upper"; then
    fail "Error: upper threshold given ($upper) not a valid integer."
  fi
  if ! is_int "$lower"; then
    fail "Error: lower threshold given ($lower) not a valid integer."
  fi
  # If the bounds were given in the wrong order, just swap them.
  if [[ "$lower" -ge "$upper" ]]; then
    tmp="$upper"
    upper="$lower"
    lower="$tmp"
  fi

  data=$(curl -s 'https://api.coindesk.com/v1/bpi/currentprice.json')

  text_out=
  notify_title=
  notify_body=
  changed=
  if [[ "$data" ]]; then
    if [[ "$debug" ]]; then
      price="$debug"
    else
      price=$(echo "$data" | jq .bpi.USD.rate_float | cut -d . -f 1)
    fi
    if [[ "$price" ]] && is_int "$price"; then
      if [[ "$price" -gt "$upper" ]]; then
        text_out="Price above threshold: $price > $upper"
        notify_title="Bitcoin at \$$price"
        notify_body="It's over $upper!    "
        changed=true
      elif [[ "$price" -lt "$lower" ]]; then
        text_out="Price below threshold: $price < $lower"
        notify_title="Bitcoin at \$$price"
        notify_body="It's below $lower!    "
        changed=true
      else
        text_out="Price in range $lower <= $price <= $upper"
      fi
    else
      fail "Error: Could not obtain a valid price. Data received:
$data"
    fi
  else
    fail "Error obtaining price data from API."
  fi

  if [[ "$text" ]] && [[ "$text_out" ]]; then
    echo "$text_out"
  fi
  if [[ "$notify" ]] && ([[ "$notify_title" ]] || [[ "$notify_body" ]]); then
    zenity --warning --title "$notify_title" --text "$notify_body" 2>/dev/null
  fi

  if [[ "$changed" ]] && [[ "$current" ]]; then
    # Get the price floored to the last $1000 (e.g. 9734 -> 9000).
    current=$((1000*(price/1000)))
    echo "$current" > "$ThresFile"
  fi
}

function is_int {
  echo "$1" | grep -Eq '^[0-9]+$'
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
