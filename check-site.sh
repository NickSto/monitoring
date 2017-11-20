#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

SilenceFile="$HOME/.local/share/nbsdata/SILENCE"
EmptyHash=d41d8cd98f00b204e9800998ecf8427e

Usage="Usage: \$ $(basename $0) url [hash [page_title]]
Check if a webpage has been updated based on its md5sum.
The page_title will be used in output messages. The url will be used by default.
Get the current hash with \$ $(basename $0) url (which just runs \"\$ curl -s url | md5sum\")"

function main {
  if [[ $# -lt 1 ]] || [[ $1 == '-h' ]]; then
    fail "$Usage"
  fi

  if [[ -e "$SilenceFile" ]]; then
    fail "Error: SILENCE file is present ($Silence). Cannot continue."
  fi

  url="$1"
  expected_hash=
  if [[ $# -ge 2 ]]; then
    expected_hash="$2"
  fi
  if [[ $# -ge 3 ]]; then
    title="$3"
  else
    title="$url"
  fi

  observed_hash=$(curl -s "$url" | md5sum | awk '{print $1}')

  if ! [[ $expected_hash ]]; then
    echo "$observed_hash"
  elif [[ $observed_hash == $expected_hash ]]; then
    printf "No change in $title\n" >&2
  elif [[ $observed_hash == $EmptyHash ]]; then
    printf "Error: Empty response from $url\n" >&2
  else
    printf "$title changed!\n"
    notify-send -i important "$title changed!" 'Saw a different hash.'
  fi

}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
