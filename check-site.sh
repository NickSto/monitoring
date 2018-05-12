#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

DataDirRel='.local/share/nbsdata'
DataDir="$HOME/$DataDirRel"
SilenceFile="$DataDir/SILENCE"
PidFile="$DataDir/check-site.pid"

Usage="Usage: \$ $(basename $0) [options] url [page_title]
Check if a webpage has been updated.
The page_title will be used in output messages. If not given, the url will be used by default.
This stores versions of the page in ~/$DataDirRel/checksite,
and checks against the previous version.
Options:
-a: The minimum number of additions to consider the page updated. The diff must show that at least
    this many lines were added in order to display the alert. This is 0 by default.
-d: The minimum number of deletions. 0 by default."

function main {

  # Read arguments.
  min_add=0
  min_del=0
  while getopts ":a:d:l:h" opt; do
    case "$opt" in
      a) min_add="$OPTARG";;
      d) min_del="$OPTARG";;
      h) fail "$Usage";;
    esac
  done
  url="${@:$OPTIND:1}"
  title="${@:$OPTIND+1:1}"
  if ! [[ "$title" ]]; then
    title="$url"
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
  echo "$$" > "$PidFile"

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
    if gzip_diff "$page_dir/$last_page" "$page_dir/$page" -q >/dev/null; then
      set -e
      echo "No change in $title" >&2
      rm "$page_dir/$page"
    else
      set -e
      add=$(gzip_diff "$page_dir/$last_page" "$page_dir/$page" | grep -c '^>')
      del=$(gzip_diff "$page_dir/$last_page" "$page_dir/$page" | grep -c '^<')
      if [[ "$add" -ge "$min_add" ]] && [[ "$del" -ge "$min_del" ]]; then
        echo -e "$title changed!\n$add additions\n$del deletions"
        if [[ $(notify zenity "$title changed!" "$add additions\n$del deletions") ]]; then
          show_diff gui "$page_dir/$last_page" "$page_dir/$page"
        fi
      fi
    fi
  fi
}


function gzip_diff {
  file1="$1"
  file2="$2"
  opts=
  if [[ "$#" -ge 3 ]]; then
    opts="$3"
  fi
  gunzip -c "$file1" | diff $opts - <(gunzip -c "$file2")
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
    set +e
    if zenity --question --width "$width" --title "$title" \
        --text "$add additions\n$del deletions\n\nView diff?" 2>/dev/null; then
      echo "view diff"
    fi
    set -e
  fi
}


function show_diff {
  method="$1"
  last_page="$2"
  this_page="$3"
  if [[ "$method" == terminal ]]; then
    set +e
    gzip_diff "$this_page" "$last_page"
    set -e
  elif [[ "$method" == gui ]]; then
    diff_file=$(mktemp --tmpdir --suffix .txt check-site.diff.XXXXX)
    set +e
    gzip_diff "$this_page" "$last_page" > "$diff_file"
    set -e
    mousepad "$diff_file"
    rm "$diff_file"
  fi
}


function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
