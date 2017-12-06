#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

#TODO: Instagram:
#      youtube-dl 'https://www.instagram.com/p/4fvpqXMKGn/'
#      -o "Dogs [src %(uploader)s, instagram.com%%2F%(uploader_id)s] [posted 20150628] [id %(id)s].%(ext)s"

ValidConversions='mp3 m4a flac aac wav'
Usage="Usage: \$ $(basename $0) [options] url [title [quality]]
Supports youtube.com, facebook.com, and instagram.com.
Options:
-F: Just print the available video quality options.
-n: Just print what the video filename would be, without downloading it.
-c: Give a file extension to convert the video to this audio format. The file
    will be named \$title.\$ext. Options: $ValidConversions"

function main {
  # Parse arguments.
  get_formats=
  get_filename=
  convert_to=
  while getopts ":Fnc:h" opt; do
    case "$opt" in
      F) get_formats=true;;
      n) get_filename=true;;
      c) convert_to=$OPTARG;;
      h) echo "$Usage" >&2
         return 1;;
    esac
  done
  # Get positionals.
  url=${@:$OPTIND:1}
  title=${@:$OPTIND+1:1}
  quality=${@:$OPTIND+2:1}

  epilog=

  if ! [[ "$title" ]]; then
    title='%(title)s'
  fi

  if [[ $get_formats ]] || [[ "$url" == '-F' ]] || [[ "$title" == '-F' ]]; then
    youtube-dl "$url" -F
    return
  fi

  site=
  for candidate in youtube facebook instagram; do
    if echo "$url" | grep -qE '^((https?://)?www\.)?'$candidate'\.com'; then
      site=$candidate
      break
    fi
  done
  if ! [[ $site ]]; then
    fail "Error: Invalid url or domain is not youtube.com, facebook.com, or instagram.com (in url \"$url\")."
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
        *) quality_args="-f $3";;
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
  elif [[ $site == facebook ]]; then
    url_escaped=$(echo "$url" | sed -E -e 's#^((https?://)?www\.)?##' -e 's#^(facebook\.com/[^?]+).*$#\1#' -e 's#/$##')
    if which pct >/dev/null 2>/dev/null; then
      url_escaped=$(pct encode "$url_escaped")
      url_escaped=$(echo "$url_escaped" | sed -E 's#%#%%#g')
    else
      url_escaped=$(echo "$url_escaped" | sed -E 's#/#%%2F#g')
    fi
    format="$title [src $url_escaped] [posted %(upload_date)s].%(ext)s"
  elif [[ $site == youtube ]]; then
    format="$title [src %(uploader)s, %(uploader_id)s] [posted %(upload_date)s] [id %(id)s].%(ext)s"
    uploader_id=$(youtube-dl --get-filename -o '%(uploader_id)s' "$url")
    # Only use both uploader and uploader_id if the id is a channel id like "UCZ5C1HBPMEcCA1YGQmqj6Iw"
    if ! echo "$uploader_id" | grep -qE '^UC[a-zA-Z0-9_-]{22}$'; then
      echo "uploader_id $uploader_id looks like a username, not a channel id. Omitting channel id.." >&2
      format="$title [src %(uploader_id)s] [posted %(upload_date)s] [id %(id)s].%(ext)s"
    fi
  elif [[ $site == instagram ]]; then
    upload_date=$(youtube-dl --get-filename -o '%(upload_date)s' "$url")
    if [[ $upload_date == NA ]]; then
      posted=
      epilog="$epilog
No upload date could be obtained! You might want to put it in yourself:
    [posted YYYYMMDD]"
    else
      posted=" [posted %(upload_date)s]"
    fi
    format="$title [src instagram.com%%2F%(uploader_id)s]$posted [id %(id)s].%(ext)s"
  fi

  # Get the the resulting filename, then exit, if requested.
  if [[ $get_filename ]]; then
    youtube-dl --get-filename -o "$format" "$url" $conversion_args $quality_args
    return
  fi

  # Do the actual downloading.
  youtube-dl --no-mtime --xattrs "$url" -o "$format" $conversion_args $quality_args

  echo "$epilog" >&2
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
