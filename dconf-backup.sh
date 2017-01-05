#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Usage="Usage: \$ $(basename $0) backup/folder [-d]
Update existing dconf backups.
This will look through the given directory, and for each file like
\"org.gnome.evince.txt\" it will use \"$ dconf dump\" to back up the custom settings
under that path into that file.
By default it will preserve the previous version of the file as a .bak.
Give -d to delete the .bak instead."

function main {
  if [[ $# -lt 1 ]] || [[ $1 == '-h' ]]; then
    fail "$Usage"
  fi

  dir="$1"
  keep_bak=true
  if [[ $# -ge 2 ]]; then
    if [[ $2 == '-d' ]]; then
      keep_bak=
    else
      fail "Error: Invalid 2nd argument \"$2\". Must be \"-d\", if given."
    fi
  fi

  for file in $(ls $dir); do
    path=/$(basename $file .txt | tr . /)/
    if [[ $file =~ \.bak$ ]]; then
      continue
    fi
    if ! [[ $(dconf list $path) ]]; then
      echo "Warning: path \"$path\" empty. \"$file\" not a valid backup?" >&2
      continue
    fi
    echo $path
    if [[ $keep_bak ]]; then
      mv $dir/$file $dir/$file.bak
    fi
    dconf dump $path > $dir/$file
  done
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
