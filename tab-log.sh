#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

SESSION_SCRIPT=$HOME/code/python/single/session-manager.py
FIREFOX_DIR=$HOME/.mozilla/firefox

Usage="Usage: \$ $(basename $0) [tabs_log.tsv]
Print records of how many tabs I've had open in recent sessions in Firefox.
This will read the Session Manager backup files from the default Firefox profile, parse them with
my Python script, find how many tabs were open in each, and print the numbers in the format I use
in my tabs log (e.g. ~/aa/misc/computerthings/logs/tabs.tsv).
If you give a tabs log as the first argument, it will omit sessions already in the log."

function main {

  # Read arguments.
  tabs_log=
  if [[ $# -ge 1 ]]; then
    if [[ $1 == '-h' ]]; then
      fail "$Usage"
    else
      tabs_log="$1"
    fi
  fi

  # Check that required paths exist
  if [[ "$tabs_log" ]] && ! [[ -f "$tabs_log" ]]; then
    fail "Error: tabs log $tabs_log missing."
  fi
  if ! [[ -x $SESSION_SCRIPT ]]; then
    fail "Error: script $SESSION_SCRIPT missing."
  fi
  if ! [[ -d $FIREFOX_DIR ]]; then
    fail "Error: Firefox directory $FIREFOX_DIR missing."
  fi

  # Find the sessions directory for the default profile.
  if [[ $(ls -d1 $FIREFOX_DIR/*.default | wc -l) != 1 ]]; then
    fail "Error: Need exactly one match for $FIREFOX_DIR/*.default"
  fi
  session_dir=$(ls -d $FIREFOX_DIR/*.default/sessions)
  if ! [[ -d $session_dir ]]; then
    fail "Error: Sessions directory $session_dir missing."
  fi

  # Read existing entries from the tabs log.
  declare -A entries
  if [[ "$tabs_log" ]]; then
    while read timestamp rest; do
      entries[$timestamp]=1
    done < "$tabs_log"
  fi

  # Read the number of tabs in each session and print the ones not already in the tabs log.
  for session in $session_dir/backup*.session; do
    # Get the timestamp of the session file.
    # Each file includes a line like "timestamp=1478232825328", so we can just eval that.
    if time_line=$(grep -E '^timestamp=[0-9]+$' $session); then
      eval "$time_line"
      # It's in milliseconds, so divide by 1000.
      unixtime=$((timestamp/1000))
    else
      echo "Warning: No timestamp found in session $session" >&2
      continue
    fi
    humantime=$(date -d @$unixtime)
    # If an entry already exists for this session (identified by its timestamp), don't add it again.
    # Have to unset -u to avoid an unbound variable error when $unixtime isn't in $entries. 
    set +u
    if [[ -n ${entries[$unixtime]} ]]; then
      continue
    fi
    set -u
    # Get the number of tabs in the session: Total, and in the main (biggest) window.
    # The Python script will print a tab-delimited list of the number of tabs in each window.
    # Awk will find the biggest window and the total.
    read main total <<< $($SESSION_SCRIPT -T $session \
      | awk '{for (i=1; i<=NF; i++) {tot+=$i; if ($i > max) {max=$i}} print max, tot}')
    if [[ $main ]] && [[ $total ]]; then
      echo -e "$unixtime\t$main\t$total\t$humantime"
    fi
  done | sort -g -k 1
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
