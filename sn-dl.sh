#!/usr/bin/env bash
set -ue

WAIT=5m
#POD_DIR="$HOME/backuphide/podcasts"
POD_DIR="$HOME/Dropbox/nickextra"
MAX_RUNTIME=$((24*60*60)) # seconds
SILENCE="$HOME/.local/share/nbsdata/SILENCE"
USAGE="USAGE: \$ $(basename $0) [episode number]"


function fail {
  echo "$1" >&2
  exit 1
}

function trim {
  echo "$@" | sed -E -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

function sleep_or_die {
  sleep $1
  now=$(date +%s)
  if [[ $((now-start)) -gt $MAX_RUNTIME ]]; then
    fail "Error: reached max runtime before catching episode."
  fi
}

cd "$POD_DIR"
start=$(date +%s)

while [[ 1 ]]; do

  if [[ $# -gt 0 ]]; then
    if [[ $1 == '-h' ]]; then
      echo "$USAGE"
      exit
    else
      lastnum=$1
    fi
  else
    lastfile=$(ls -1 sn*.mp3 2>/dev/null | tail -n 1)
    lastnum=$(echo "$lastfile" | sed -E 's/^sn0*([0-9]+)\.mp3$/\1/g')
    if [[ ! "$lastnum" ]]; then
      fail "Error: no previous episode found."
    fi
    lastnum=$((lastnum+1))
  fi

  if [[ $lastnum -gt 999 ]]; then
    fail "Error: episode number over 1000. Can't deal."
  fi
  if [[ -e "sn0$lastnum.mp3" ]]; then
    fail "Error: file for episode $lastnum already exists."
  fi

  url="https://twit.cachefly.net/audio/sn/sn0$lastnum/sn0$lastnum.mp3"

  if [[ -f "$SILENCE" ]]; then
    sleep_or_die $WAIT
    continue
  fi

  response=$(curl -sI "$url" | head -n 1 | sed -E -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [[ "$response" == "HTTP/1.1 200 OK" ]]; then
    # it's up; download
    wget "$url"
    exit $?
  elif [[ "$response" == "HTTP/1.1 404 Not Found" ]]; then
    true # it's not up yet
  else
    echo "unrecognized response line: $response" >&2
  fi

  sleep_or_die $WAIT

done
