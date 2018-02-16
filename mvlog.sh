#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Now=$(date +%s)
LogFile="$HOME/aa/misc/backups/0historical-record/mv.tsv"
Usage="Usage: \$ $(basename $0) src dst"

function main {
  if [[ $# != 2 ]] || [[ $1 == '-h' ]] || [[ $1 == '--help' ]]; then
    fail "$Usage"
  fi

  src="$1"
  dst="$2"

  if ! [[ "$src" ]] || ! [[ "$dst" ]]; then
    fail "Error: Missing source or destination."
  fi
  if ! [[ -f "$src" ]] && ! [[ -d "$src" ]]; then
    fail "Error: source \"$src\" does not seem to be an existing file or directory."
  fi

  # Get absolute paths of src and dst.
  if ! readlink -m dummy >/dev/null 2>/dev/null; then
    fail "Error: readlink does not have -m option."
  fi
  src_abs=$(readlink -m "$src")
  dst_abs=$(readlink -m "$dst")
  if ! [[ -f "$src_abs" ]] && ! [[ -d "$src_abs" ]]; then
    fail "Error: source path \"$src_abs\" does not seem to be an existing file or directory."
  fi

  if ! [[ -f "$LogFile" ]]; then
    fail "Error: Could not access log file \"$LogFile\"."
  fi

  # If the destination is a directory, then we're not actually renaming $src to $dst. We're moving
  # $src into $dst. We want the log to be a mapping of the full paths of things before and after
  # moves. So in that case, get the predicted name after the move.
  if [[ -d "$dst_abs" ]]; then
    filename=$(basename "$src_abs")
    dst_path="$dst_abs/$filename"
  else
    dst_path="$dst_abs"
  fi

  if mv "$src_abs" "$dst_abs"; then
    echo -e "Recording move of:\n  $src_abs\nto:\n  $dst_path"
    echo -e "$Now\t$src_abs\t$dst_path" >> "$LogFile"
  else
    fail "Error: mv command failed."
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
