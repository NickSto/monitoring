#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Debug=${Debug:=''}
CookieDefault='3uj6lune7bsgvb8galt66kkfn2'
UserAgent='Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:44.0) Gecko/20100101 Firefox/44.0'
Usage="Usage: $(basename $0) [options] start_episode
Download WTF episodes from libsyn into the current directory.
Give the number of the episode to start from.
Options:
-c: \"libsyn-paywall\" cookie allowing access to non-free episodes.
-s: stop episode number (inclusive)."

if python -c 'import titlecase'; then
  titlecase=true
else
  echo "Warning: Python module \"titlecase\" not installed. Defaulting to worse built-in version." >&2
  titlecase=
fi

function main {

  # Parse arguments
  if [[ $# -lt 1 ]]; then
    fail "$Usage"
  fi
  stop=''
  cookie="$CookieDefault"
  while getopts ":s:c:h" opt; do
    case "$opt" in
      h) fail "$Usage";;
      s) stop="$OPTARG";;
      c) cookie="$OPTARG";;
    esac
  done
  start=${@:$OPTIND:1}

  # Check arguments.
  if ! echo "$start" | grep -qE '^[0-9]+$'; then
    fail "Error: Starting episode number (first argument) \"$start\" invalid. Must be an integer."
  fi
  if [[ $stop != '' ]] && ! echo "$stop" | grep -qE '^[0-9]+$'; then
    fail "Error: Stopping episode number (-s) \"$stop\" invalid. Must be an integer."
  fi

  # Find the page number for the starting episode.
  page=$(get_episode_page $start)

  # Download each episode.
  # Walk backward from the page for the starting episode down to page 1.
  # Or, if a stopping episode was given, stop when we see that episode.
  while [[ $page -gt 0 ]]; do
    mp3_url=$(get_mp3_url $(get_iframe_urls http://wtfpod.libsyn.com/webpage/page/$page/size/1))
    ep_num="$(get_mp3_name "$mp3_url" number)"
    # Check if this is the stopping episode.
    if [[ $stop ]] && [[ $ep_num ]] && [[ $ep_num -gt $stop ]]; then
      break
    fi
    filename="$(get_mp3_name "$mp3_url")"
    echo "Downloading \"$filename\""
    download_mp3 "$mp3_url" "$filename" "$cookie"
    # Check that it worked
    if [[ -s "$filename" ]]; then
      mime=$(file --brief --mime-type "$filename")
      if [[ $mime == 'text/html' ]] || \
          ( \
            [[ $mime != 'application/octet-stream' ]] && \
            [[ $mime != 'audio/mpeg3' ]] && \
            [[ $mime != 'audio/x-mpeg-3' ]] && \
            [[ $mime != 'audio/x-mpeg-3' ]] \
          ); then
        echo "Warning: Download failure, likely because access denied to paywall episode." >&2
      fi
    else
      echo "Warning: Download failure." >&2
    fi
    page=$((page-1))
  done
}


# Get the page number of the given episode.
# This will return a number ready to be put into a url (http://wtfpod.libsyn.com/page/$page/size/1).
# It effectively does a binary search through the episode listing pages. Specifically, it starts
# looking through listings with 256 episodes per page, until it goes past the target episode, then
# backs up and halves the number of episodes per page, and keeps going, until it's down to 1 episode
# per page and on the target episode.
function get_episode_page {
  target="$1"
  page=0
  step=256
  current=999999999
  tries=0
  first_loop='true'
  while ! ([[ $step == 1 ]] && [[ $current == $target ]]); do
    if [[ $current -gt $target ]]; then
      # If we're not there yet, advance to the next page.
      if [[ $Debug ]]; then echo "$current > $target" >&2; fi
      page=$((page+1))
    elif [[ $step -gt 1 ]]; then
      # If we're at or beyond the target and we're not down to 1 episode per page yet,
      # unless we're already at or past the target.
      if [[ $Debug ]]; then echo "$current <= $target and $step > 1" >&2; fi
      if [[ $page -gt 1 ]]; then
        page=$(((page-1)*2))
      fi
      step=$((step/2))
    elif [[ $step == 1 ]]; then
      # If we're at or beyond the target and we're already at 1 episode per page, just back up one.
      page=$((page-1))
      if [[ $Debug ]]; then echo "$current <= $target and $step == 1" >&2; fi
    fi
    # Sample the first (valid) episode from the current page.
    current=''
    while ! [[ $current ]]; do
      episodes=0
      for iframe in $(get_iframe_urls "http://wtfpod.libsyn.com/page/$page/size/$step"); do
        episodes=$((episodes+1))
        current=$(get_mp3_name $(get_mp3_url "$iframe") number)
        if [[ $Debug ]]; then echo -en "page: $page\tstep: $step\tcurrent: $current\t" >&2; fi
        # If the first episode doesn't have an episode number, try the next. Otherwise, stop.
        if [[ $current ]]; then
          break
        fi
      done
      # No valid episode number from that whole page?
      if ! [[ $current ]]; then
        if [[ $episodes == 0 ]]; then
          # If we saw 0 episodes at all, then we've gone past the start. Back up and halve the size.
          if [[ $Debug ]]; then echo -n "Went past start (page $page, step $step). " >&2; fi
          page=$(((page-2)*2))
          step=$((step/2))
          if [[ $page -lt 1 ]]; then
            page=1
          fi
          if [[ $Debug ]]; then echo "Going back to page $page, step $step." >&2; fi
        else
          # Otherwise, we saw episodes, but they didn't have valid numbers. Back up.
          page=$((page+1))
        fi
      fi
    done
    # Error checking
    if [[ $tries -gt 40 ]]; then
      fail "Error in get_first_page(): Could not find the episode page within 40 loops."
    fi
    if [[ $first_loop ]] && [[ $current -lt $target ]]; then
      fail "Error in get_first_page(): Latest episode ($current) < target ($target)."
    fi
    first_loop=''
  done
  if [[ $Debug ]]; then echo $current >&2; fi
  echo $page
}


# Give the URL of an episode list page, like
# http://wtfpod.libsyn.com/webpage/page/19/size/10
# Returns the url of the iframe containing the player
# N.B.: Also works to get the single player url from an episode page like
# http://wtfpod.libsyn.com/webpage/episode-495-benmont-tench
function get_iframe_urls {
  list_url="$1"
  curl -s "$list_url" \
    | grep -E '<iframe .*html5-player'  \
    | sed -E 's/^.*src="([^"]+)".*$/http:\1/'
}


# Give the URL of the iframe player, like 
# http://html5-player.libsyn.com/embed/episode/id/2825791/height/45/width/300/theme/standard/direction/no/autoplay/no/autonext/no/thumbnail/no/preload/no/no_addthis/no/
# Returns the url of the actual mp3
function get_mp3_url {
  player_url="$1"
  mp3_url=$(curl -s "$player_url" \
    | grep -E 'var mediaURL( |=)' \
    | sed -E 's/^.*= *"([^"]+)".*$/\1/')
  if echo "$mp3_url" | grep -qE '^http.*\.mp3$'; then
    echo "$mp3_url"
  else
    fail "Error: mp3 url doesn't look right: \"$mp3_url\"."
  fi
}


# Give the url of the mp3 itself
function get_mp3_name {
  mp3_url="$1"
  if [[ $# -gt 1 ]]; then
    number="$2"
  else
    number=''
  fi
  title="$(echo "$mp3_url" | sed -E \
    -e 's#^https?:.*/([^/]+)$#\1#' \
    -e 's/^_?WTF(.*)\.mp3$/\1/' \
    -e 's/_/ /g' \
    -e 's/ - EPISODE ([0-9]+) / \1 - /' \
    -e 's/ - EPISODE ([0-9]+)$/ \1/' \
    -e 's/EPISODE ?//')"
  if [[ $number ]]; then
    # The caller just wants the episode number.
    echo "$title" | sed -En 's/^\s*([0-9]+).*$/\1/p'
  else
    # Otherwise, print a nicely formatted filename.
    if [[ $titlecase ]]; then
      title="$(python -c 'import sys, titlecase; print titlecase.titlecase(sys.argv[1])' "$title")"
    else
      title="$(python -c 'import sys; print sys.argv[1].title()' "$title")"
    fi
    echo "WTF$title.mp3"
  fi
}


function download_mp3 {
  url="$1"
  filename="$2"
  cookie="$3"
  if [[ -s "$filename" ]]; then
    echo "Warning: Skipping episode because filename already exists: $filename" >&2
  else
    curl -sL -b "libsyn-paywall=$cookie" -A "$UserAgent" "$url" > "$filename"
  fi
}


function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
