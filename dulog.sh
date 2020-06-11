#!/usr/bin/env bash
if [[ "$#" -lt 1 ]] || [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]]; then
  echo "Usage: $(basename $0) path/to/dir
Print the disk usage of a file or directory, along with a timestamp.
Useful for simple environments like cron where you can't rely on shell features to write a
one-liner.
Prints a tab-delimited line with 3 fields:
the current Unix timestamp (date +%s), the size of the target in bytes (du -sb), and the absolute
path to the target." >&2
  exit 1
else
  path="$1"
fi
function realpath {
  cd "$(dirname "$1")"
  dirname=$(pwd -P)
  basename=$(basename "$1")
  echo "$dirname/$basename"
}
now=$(date +%s)
bytes=$(du -sb "$path" | awk '{print $1}')
abspath=$(realpath "$path")
printf '%d\t%d\t%s\n' "$now" "$bytes" "$abspath"
