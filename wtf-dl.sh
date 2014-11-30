#!/usr/bin/env bash
set -ue

Cookie='3uj6lune7bsgvb8galt66kkfn2'
UserAgent='Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:33.0) Gecko/20100101 Firefox/33.0'
StopPage=50

function main {
  if [[ $# -lt 1 ]]; then
    fail "Usage: $(basename $0) (opt | list_url)
Download all WTF episodes from libsyn. Can give a url like
http://wtfpod.libsyn.com/webpage/page/17/size/10
to just download all episodes from that page.
Or give the option \"-a\" (\"after\") to start from page 1 and download all
episodes until page $StopPage.
Or give the option \"-b\" (\"before\") to start from page $StopPage and download
all episodes until the end."
  fi
  if [[ "$1" == '-a' ]] || [[ "$1" == '-b' ]]; then
    page=1
    list_url="http://wtfpod.libsyn.com/webpage/page/$page/size/10"
    all='true'
    if [[ "$1" == '-a' ]]; then
      after='true'
    else
      after=''
      fail "Error: -b not yet implemented."
    fi
  else
    list_url="$1"
    all=''
  fi

  finished=''
  while [[ ! "$finished" ]]; do
    # Download the mp3s
    player_urls=$(get_player_urls "$list_url")
    for player_url in $player_urls; do
      mp3_url=$(get_mp3_url "$player_url")
      # echo "$mp3_url"
      mp3_name=$(get_mp3_name "$mp3_url")
      echo "$mp3_name"
      download_mp3 "$mp3_url" "$mp3_name"
    done
    # Are we done?
    if [[ ! "$player_urls" ]]; then
      finished='true'
      echo "done!"
    fi
    if [[ "$all" ]]; then
      page=$((page+1))
      list_url="http://wtfpod.libsyn.com/webpage/page/$page/size/10"
      # kludge to protect against downloading ones from before good filenaming
      if [[ $page -gt $StopPage ]]; then
        break
      fi
    else
      finished='true'
    fi
  done
}


# Give the URL of an episode list page, like
# http://wtfpod.libsyn.com/webpage/page/19/size/10
# Returns the url of the iframe containing the player
# N.B.: Also works to get the single player url from an episode page like
# http://wtfpod.libsyn.com/webpage/episode-495-benmont-tench
function get_player_urls {
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


function get_mp3_name {
  url="$1"
  title="$(echo "$url" \
    | sed -E 's#^http:.*/_?WTF([^/]+)\.mp3$#\1#' \
    | sed    's/_/ /g' \
    | sed -E 's/ - EPISODE ([0-9]+) / \1 - /' \
    | sed -E 's/ - EPISODE ([0-9]+)$/ \1/' \
    | sed -E 's/EPISODE ?//')"
  title="$(python -c 'import sys, titlecase; print titlecase.titlecase(sys.argv[1])' "$title")"
  echo "WTF$title.mp3"
}


function download_mp3 {
  url="$1"
  filename="$2"
  curl -sL -b "libsyn-paywall=$Cookie" -A "$UserAgent" "$url" > "$filename"
}


function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
