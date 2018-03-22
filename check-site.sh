#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

DataDirRel='.local/share/nbsdata'
DataDir="$HOME/$DataDirRel"
SilenceFile="$DataDir/SILENCE"

Usage="Usage: \$ $(basename $0) url [page_title]
Check if a webpage has been updated.
The page_title will be used in output messages. If not given, the url will be used by default.
This stores versions of the page in ~/$DataDirRel/checksite,
and checks against the previous version."

function main {
  if [[ $# -lt 1 ]] || [[ $1 == '-h' ]]; then
    fail "$Usage"
  fi

  if [[ -e "$SilenceFile" ]]; then
    fail "Error: SILENCE file is present ($Silence). Cannot continue."
  fi

  url="$1"
  if [[ $# -ge 2 ]]; then
    title="$2"
  else
    title="$url"
  fi

  page_dir="$DataDir/checksite/$(get_page_dir "$url")"
  mkdir -p "$page_dir"

  last_page=$(ls -1t "$page_dir" | head -n 1)

  page=$(date +'%F-%H%M%S.html.gz')
  curl -s "$url" | gzip -c - > "$page_dir/$page"

  bytes=$(wc -c "$page_dir/$page" | awk '{print $1}')
  if [[ "$bytes" -le 21 ]]; then
    rm "$page_dir/$page"
    fail "Error: Empty response from $url"
  fi

  if [[ "$last_page" ]]; then
    set +e
    if gunzip -c "$page_dir/$last_page" | diff -q - <(gunzip -c "$page_dir/$page") >/dev/null; then
      set -e
      echo "No change in $title" >&2
      rm "$page_dir/$page"
    else
      set -e
      add=$(gunzip -c "$page_dir/$last_page" | diff - <(gunzip -c "$page_dir/$page") | grep -c '^>')
      del=$(gunzip -c "$page_dir/$last_page" | diff - <(gunzip -c "$page_dir/$page") | grep -c '^<')
      echo -e "$title changed!\n$add additions\n$del deletions"
      notify zenity "$title changed!" "$add additions\n$del deletions"
    fi
  fi
}


function get_page_dir {
  url="$1"
  # Component 1: The domain.
  domain=$(echo "$url" | sed -E -e 's#^https?://##' -e 's#^([^/]+)/.*$#\1#')
  # Component 2: The path.
  path=$(echo "$url" | sed -E -e 's#^https?://##' -e 's#[^/]+(/.*)$#\1#')
  # Only allow letters, numbers, dots, and dashes.
  path_cleaned=$(echo "$path" | sed -E -e 's#/$##' -e 's#/#-#g' -e 's#[^a-zA-Z0-9.-]##g')
  # Truncate to the first 100 characters.
  path_cleaned=${path_cleaned:0:100}
  # Component 3: A checksum.
  checksum=$(crc32 <(echo "$url"))
  echo "$domain/$checksum$path_cleaned"
}


function notify {
  method="$1"
  title="$2"
  body=
  if [[ "$#" -ge 3 ]]; then
    body="$3"
  fi
  if [[ "$method" == notify-send ]]; then
    notify-send -i important "$title" "$body"
  elif [[ "$method" == zenity ]]; then
    # Set a width so the window title doesn't get cut off (zenity auto-sizes the window so the body
    # text isn't cut off, but not the title text).
    title_len=${#title}
    width=$((title_len*10))
    zenity --warning --width "$width" --title "$title" --text "$add additions\n$del deletions" \
      2>/dev/null
  fi
}


function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
