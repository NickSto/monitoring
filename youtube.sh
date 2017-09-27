#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

#TODO: Instagram:
#      youtube-dl 'https://www.instagram.com/p/4fvpqXMKGn/'
#      -o "Dogs [src %(uploader)s, instagram.com%%2F%(uploader_id)s] [posted 20150628] [id %(id)s].%(ext)s"

Usage="Usage: \$ $(basename $0)[options] url [title [quality]]
Supports youtube.com and facebook.com.
Options:
-F: Just print the available video quality options.
-n: Just print what the video filename would be, without downloading it.
-c: Give a file extension to convert the video to this file format using ffmpeg, then delete the
    video. The mp3 file will be named \$title.\$ext."

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

  if ! [[ $title ]]; then
    title='%(title)s'
  fi

  if [[ $get_formats ]]; then
    youtube-dl "$url" -F
    return
  fi

  site=
  if echo "$url" | grep -qE '^((https?://)?www\.)?youtube\.com'; then
    site='youtube'
  elif echo "$url" | grep -qE '^((https?://)?www\.)?facebook\.com'; then
    site='facebook'
  else
    fail "Error: Invalid url or domain is not youtube.com or facebook.com (in url \"$url\")."
  fi

  quality_args=
  if [[ $quality ]]; then
    case "$quality" in
      360) quality_args='-f 18';;
      640) quality_args='-f 18';;
      480) quality_args='-f 135+250';;  # 80k audio, 480p video
      720) quality_args='-f 22';;
      1280) quality_args='-f 22';;
      *) quality_args="-f $3";;
    esac
  fi

  format=
  if [[ $site == 'facebook' ]]; then
    if [[ $convert_to ]]; then
      fail "Error: -c not supported for Facebook."
    fi
    url_escaped=$(echo "$url" | sed -E -e 's#^((https?://)?www\.)?##' -e 's#^(facebook\.com/[^?]+).*$#\1#' -e 's#/$##')
    if which pct >/dev/null 2>/dev/null; then
      url_escaped=$(pct encode "$url_escaped")
      url_escaped=$(echo "$url_escaped" | sed -E 's#%#%%#g')
    else
      url_escaped=$(echo "$url_escaped" | sed -E 's#/#%%2F#g')
    fi
    format="$title [src $url_escaped] [posted %(upload_date)s].%(ext)s"
    youtube-dl --no-mtime "$url" -o "$format"
  elif [[ $site == 'youtube' ]]; then
    # First define the format and check the resulting filename.
    format="$title [src %(uploader)s, %(uploader_id)s] [posted %(upload_date)s] [id %(id)s].%(ext)s"
    uploader_id=$(youtube-dl --get-filename -o '%(uploader_id)s' "$url")
    # Only use both uploader and uploader_id if the id is a channel id like "UCZ5C1HBPMEcCA1YGQmqj6Iw"
    if ! echo "$uploader_id" | grep -qE '^UC[a-zA-Z0-9_-]{22}$'; then
      echo "uploader_id $uploader_id looks like a username, not a channel id. Omitting channel id.." >&2
      format="$title [src %(uploader_id)s] [posted %(upload_date)s] [id %(id)s].%(ext)s"
    fi
    filename=$(youtube-dl --get-filename -o "$format" "$url" $quality_args)
    if [[ $get_filename ]]; then
      echo $filename
      return
    fi
    # Do the actual downloading.
    youtube-dl --no-mtime "$url" -o "$format" $quality_args
    # Convert to the requested format (if any).
    if [[ $convert_to ]]; then
      if which ffmpeg >/dev/null 2>/dev/null; then
        if ffmpeg -i "$filename" -aq 5 "$title.$convert_to"; then
          echo "Converted to \"$title.$convert_to\"."
          rm "$filename"
        fi
      else
        fail "Error: ffmpeg not found."
      fi
    fi
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
