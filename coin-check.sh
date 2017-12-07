#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

SilenceFile="$HOME/.local/share/nbsdata/SILENCE"

Usage="Usage: \$ $(basename $0) upper [lower]
Check the price of bitcoin and send a notification if it's above (or below) a
certain price threshold."

function main {
  if [[ $# -lt 1 ]] || [[ $1 == '-h' ]]; then
    fail "$Usage"
  fi

  if [[ -e "$SilenceFile" ]]; then
    fail "Error: SILENCE file is present ($Silence). Cannot continue."
  fi

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

  data=$(curl -s 'https://api.coindesk.com/v1/bpi/currentprice.json')

  if [[ $data ]]; then
    price=$(echo "$data" | jq .bpi.USD.rate_float | cut -d . -f 1)
    if [[ $price ]] && is_int $price; then
      if [[ $price -gt $upper ]]; then
        echo "Price above threshold: $price > $upper"
        notify-send -i important "Bitcoin at \$$price" "It's above $upper!"
      elif [[ $price -lt $lower ]]; then
        echo "Price below threshold: $price < $lower"
        notify-send -i important "Bitcoin at \$$price" "It's below $lower!"
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
}

function is_int {
  echo "$1" | grep -Eq '^[0-9]+$'
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
