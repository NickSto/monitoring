#!/usr/bin/env bash
if [ "x$BASH" = x ] || [ ! "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

DataDir="$HOME/.local/share/nbsdata"
CriticalStats='5,187,188,197,198'
AwkScript='
BEGIN {
  split(IdsStr, ids_arr, ",")
  for (i in ids_arr) {
    ids[ids_arr[i]] = 1
  }
}
$2 in ids {
  if ($1 == LastTime && $4 > 0 && (! OnlyDiff || $4 != last_values[$2])) {
    print $2, $3, $4
  }
  last_values[$2] = $4
}'
Usage="Usage: \$ $(basename "$0") [-g] [-s id1,id2,etc] smart-log.tsv
Raise alert if critical SMART stat values appear.
Exits with 0 if a bad stat is detected, 1 otherwise.
It will also print any bad SMART values.
Give the path to a log of smart values as output by smart-format.py -t.
Options:
-s: The ids of the stats to check (comma-separated list). If any of these
    are > 0, the alert will be raised. Default: $CriticalStats
-d: Only alert for stats which have changed since the previous measurement.
-g: Also show GUI alert window.
List of critical SMART stats taken from:
https://www.computerworld.com/article/2846009/the-5-smart-stats-that-actually-predict-hard-drive-failure.html"


function main {

  # Get arguments.
  gui=
  only_diff=
  stats="$CriticalStats"
  while getopts "gds:h" opt; do
    case "$opt" in
      g) gui="true";;
      d) only_diff="true";;
      s) stats="$OPTARG";;
      [h?]) fail "$Usage";;
    esac
  done
  log="${@:$OPTIND:1}"

  if ! [[ "$log" ]]; then
    fail "$Usage"
  fi

  last_time=$(cut -f 1 "$log" | uniq | tail -n 1)

  results=$(awk -F '\t' -v OFS='\t' -v LastTime="$last_time" -v IdsStr="$stats" \
            -v OnlyDiff="$only_diff" "$AwkScript" "$log")

  if [[ "$results" ]]; then
    echo "$results"
    if [[ "$gui" ]] && which zenity >/dev/null 2>/dev/null; then
      echo "$results" > "$DataDir/smart-alert.tmp"
      zenity --list --window-icon=warning --title='Critical SMART stats appeared!' \
        --column=ID --column=Statistic --column=Value $(cat "$DataDir/smart-alert.tmp")
      if which gtk-launch >/dev/null 2>/dev/null && \
          [[ -f "$HOME/.local/share/applications/smartmon.desktop" ]]; then
        gtk-launch smartmon
      fi
    fi
    return 0
  else
    return 1
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
