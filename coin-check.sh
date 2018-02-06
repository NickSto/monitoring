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

Usage="Usage: \$ $(basename $0) [upper [lower]]
Check the price of bitcoin and send a notification if it's above (or below) a
certain price threshold."

function main {
  if [[ $# -ge 1 ]] && ([[ $1 == '-h' ]] || [[ $1 == '--help' ]]); then
    fail "$Usage"
  fi

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
  echo $$ > "$PidFile"

  current=
  if [[ $# == 0 ]]; then
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
  else
    upper="$1"
    lower=0
    if [[ $# -ge 2 ]]; then
      lower="$2"
    fi
    if ! is_int $upper; then
      fail "Error: upper threshold given ($upper) not a valid integer."
    fi
    if ! is_int $lower; then
      fail "Error: lower threshold given ($lower) not a valid integer."
    fi
    # If the bounds were given in the wrong order, just swap them.
    if [[ $lower -ge $upper ]]; then
      tmp=$upper
      upper=$lower
      lower=$tmp
    fi
  fi

  data=$(curl -s 'https://api.coindesk.com/v1/bpi/currentprice.json')

  if [[ $data ]]; then
    price=$(echo "$data" | jq .bpi.USD.rate_float | cut -d . -f 1)
    if [[ $price ]] && is_int $price; then
      if [[ $price -gt $upper ]]; then
        echo "Price above threshold: $price > $upper"
        zenity --warning --title "Bitcoin at \$$price" --text "It's above $upper!    " 2>/dev/null
      elif [[ $price -lt $lower ]]; then
        echo "Price below threshold: $price < $lower"
        zenity --warning --title "Bitcoin at \$$price" --text "It's below $lower!    " 2>/dev/null
      else
        echo "Price in range $lower <= $price <= $upper" >&2
      fi
    else
      fail "Error: Could not obtain a valid price. Data received:
$data"
    fi
  else
    fail "Error obtaining price data from API."
  fi

  if [[ "$current" ]]; then
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
