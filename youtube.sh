#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

ValidConversions='mp3 m4a flac aac wav'
Usage="Usage: \$ $(basename $0) [options] url [title]
Supports youtube.com, vimeo.com, facebook.com, instagram.com, and twitter.com.
Options:
-F: Just print the available video quality options.
-n: Just print what the video filename would be, without downloading it.
-c: Give a file extension to convert the video to this audio format. The file
    will be named \$title.\$ext. Options: $ValidConversions
-p: Use this string as the 'posted' value, when not automatically obtained from the website
    (true for at least Twitter and Instagram).
-f: Quality of video to download. Here are the known resolutions and their aliases:
    640x360:  18
    640x480:  135
    1280x720: 22"

function main {
  # Parse arguments.
  if [[ $# -ge 1 ]] && [[ $1 == '--help' ]]; then
    fail "$Usage"
  fi
  get_formats=
  get_filename=
  convert_to=
  quality=
  posted=
  while getopts ":Fnc:f:p:h" opt; do
    case "$opt" in
      F) get_formats=true;;
      n) get_filename=true;;
      c) convert_to=$OPTARG;;
      f) quality=$OPTARG;;
      p) posted="$OPTARG";;
      h) fail "$Usage";;
    esac
  done
  # Get positionals.
  url=${@:$OPTIND:1}
  title=${@:$OPTIND+1:1}
  if [[ $(($#-OPTIND)) -ge 2 ]]; then
    fail "$Usage"
  fi

  epilog=

  if ! [[ "$title" ]]; then
    title='%(title)s'
  fi

  if [[ $get_formats ]] || [[ "$url" == '-F' ]] || [[ "$title" == '-F' ]]; then
    youtube-dl "$url" -F
    return
  fi

  site=
  for candidate in {youtube,vimeo,facebook,instagram,twitter}.com clips.twitch.tv; do
    if echo "$url" | grep -qE '^(https?://)?(www\.)?'"$candidate"; then
      site=$(echo "$candidate" | awk -F . '{print $(NF-1)}')
      break
    fi
  done
  if ! [[ $site ]]; then
    fail "Error: Invalid url or domain is not youtube.com, vimeo.com, facebook.com, instagram.com, twitter.com, or twitch.tv (in url \"$url\")."
  fi

  quality_args=
  if [[ $quality ]]; then
    if [[ $site == youtube ]]; then
      case "$quality" in
        360) quality_args='-f 18';;
        640) quality_args='-f 18';;
        480) quality_args='-f 135+250';;  # 80k audio, 480p video
        720) quality_args='-f 22';;
        1280) quality_args='-f 22';;
        *) quality_args="-f $quality";;
      esac
    else
      echo "Warning: Quality only selectable for Youtube." >&2
    fi
  fi

  conversion_args=
  if [[ $convert_to ]]; then
    valid=
    for conversion in $ValidConversions; do
      if [[ $convert_to == $conversion ]]; then
        valid=true
        break
      fi
    done
    if [[ $valid ]]; then
      conversion_args="--extract-audio --audio-format $convert_to"
    else
      fail "Error: Invalid conversion target \"$convert_to\"."
    fi
  fi

  # Construct the format string (site-specific).
  format=
  if [[ $convert_to ]]; then
    format="$title.%(ext)s"
  elif [[ $site == youtube ]]; then
    format="$title [src %(uploader)s, %(uploader_id)s] [posted %(upload_date)s] [id %(id)s].%(ext)s"
    uploader_id=$(youtube-dl --get-filename -o '%(uploader_id)s' "$url")
    # Only use both uploader and uploader_id if the id is a channel id like "UCZ5C1HBPMEcCA1YGQmqj6Iw"
    if ! echo "$uploader_id" | grep -qE '^UC[a-zA-Z0-9_-]{22}$'; then
      echo "uploader_id $uploader_id looks like a username, not a channel id. Omitting channel id.." >&2
      format="$title [src %(uploader_id)s] [posted %(upload_date)s] [id %(id)s].%(ext)s"
    fi
  elif [[ $site == vimeo ]]; then
    format="$title [src vimeo.com%%2F%(uploader_id)s] [posted %(upload_date)s] [id %(id)s].%(ext)s"
  elif [[ "$site" == twitch ]]; then
    id=$(echo "$url" | sed -E 's#^https?://clips.twitch.tv/([^/?]+)((\?|/).*)?$#\1#')
    format="$title [src twitch.tv%%2F%(creator)s] [posted %(upload_date)s] [id $id].%(ext)s"
  elif [[ $site == facebook ]]; then
    url_escaped=$(echo "$url" | sed -E -e 's#^((https?://)?www\.)?##' -e 's#^(facebook\.com/[^?]+).*$#\1#' -e 's#/$##')
    url_escaped=$(url_double_escape "$url_escaped")
    format="$title [src $url_escaped] [posted %(upload_date)s].%(ext)s"
  elif [[ $site == instagram ]] || [[ $site == twitter ]]; then
    upload_date=$(youtube-dl --get-filename -o '%(upload_date)s' "$url")
    if [[ $upload_date == NA ]]; then
      if [[ "$posted" ]]; then
        posted_str="[posted $posted] "
      else
        posted_str=
        epilog="$epilog
No upload date could be obtained! You might want to put it in yourself:
        [posted YYYYMMDD]"
      fi
    else
      posted_str="[posted %(upload_date)s] "
    fi
    format="$title $posted_str[src $site.com%%2F%(uploader_id)s] [id %(id)s].%(ext)s"
  fi

  # Get the the resulting filename, then exit, if requested.
  if [[ $get_filename ]]; then
    youtube-dl --get-filename -o "$format" "$url" $conversion_args $quality_args
    return
  fi

  # Do the actual downloading.
  echo "\$ youtube-dl --no-mtime --xattrs $conversion_args $quality_args '$url' -o '$format'"
  youtube-dl --no-mtime --xattrs $conversion_args $quality_args "$url" -o "$format"

  echo "$epilog" >&2
}


function url_double_escape {
  # Escape non-url safe characters.
  # Double-escape them because % is a special character in the youtube-dl -o format string.
  if which pct >/dev/null 2>/dev/null; then
    pct encode "$1" | sed -E 's#%#%%#g'
  else
    echo "$1" | sed -E 's#/#%%2F#g'
  fi
}


function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
