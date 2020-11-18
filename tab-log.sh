#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

SessionScript=${SessionScript:-$HOME/code/python/single/firefox-sessions.py}
FirefoxDir=${FirefoxDir:-$HOME/.mozilla/firefox}
AwkScript='{
  for (i = 1; i <= NF; i++) {
    tot += $i
    if ($i > max) {
      max = $i
    }
  }
  print max, tot
}'

Usage="Usage: \$ $(basename $0) [options] [tabs_log.tsv]
Print records of how many tabs I've had open in Firefox.
This will use my Python script to parse the session file in my default Firefox profile,
find how many tabs are open, and print the numbers in the format I use in my tabs log
(e.g. ~/aa/computer/logs/tabs.tsv).
If you give a tabs log as the first argument, it will omit sessions already in the log.
Options:
-p: Your Firefox profile directory.
-n: Read your current, open session (from recovery.jsonlz4, updated while your session is open).
-l: Read your last closed session (default) (from previous.jsonlz4, updated at the end of every
    session)."

function main {

  # Read arguments.
  stage="last"
  session_dir=
  while getopts ":p:nlh" opt; do
  case "$opt" in
      n) stage="now";;
      l) stage="last";;
      p) session_dir="$OPTARG/sessionstore-backups";;
      h) fail "$Usage";;
    esac
  done
  # Get positionals.
  tabs_log="${@:$OPTIND:1}"

  # Check that required paths exist
  if [[ "$tabs_log" ]] && ! [[ -f "$tabs_log" ]]; then
    fail "Error: tabs log $tabs_log missing."
  fi
  if ! [[ -x "$SessionScript" ]]; then
    fail "Error: script $SessionScript missing."
  fi

  # Find the sessions directory for the default profile.
  if ! [[ "$session_dir" ]]; then
    if ! [[ -f "$FirefoxDir/profiles.ini" ]]; then
      fail "Error: Cannot find file \"$FirefoxDir/profiles.ini\"."
    fi
    profile_dir=$(get_default_profile "$FirefoxDir/profiles.ini")
    if ! [[ "$profile_dir" ]] || ! [[ -d "$FirefoxDir/$profile_dir" ]]; then
      fail "Error: Could not find the default profile."
    fi
    session_dir=$(ls -d "$FirefoxDir/$profile_dir/sessionstore-backups")
    if ! [[ -d "$session_dir" ]]; then
      fail "Error: Sessions directory $session_dir missing."
    fi
  fi

  if [[ "$stage" == now ]]; then
    session_file="$session_dir/recovery.jsonlz4"
  elif [[ "$stage" == last ]]; then
    session_file="$session_dir/previous.jsonlz4"
  fi

  if ! [[ -f "$session_file" ]]; then
    fail "Error: Could not find session file $session_file"
  fi
  modified=$(stat -c "%Y" "$session_file")

  # Check if this file is already in the tabs log.
  if [[ "$tabs_log" ]]; then
    if [[ $(awk "\$1 == $modified" "$tabs_log") ]]; then
      echo "Session already in log." >&2
      return
    fi
  fi

  # Get the number of tabs in the main (biggest) window, and in all windows.
  read main total <<< $("$SessionScript" -T "$session_file" | awk "$AwkScript")

  humantime=$(date -d @$modified)
  echo -e "$modified\t$main\t$total\t$humantime\t$stage"
}

function get_default_profile {
  profiles_ini="$1"
  section=$(sed -En 's/^\[(Install.*)\]$/\1/p' "$profiles_ini")
  if [[ $(printf '%s\n' "$section" | wc -l) != 1 ]]; then
    fail "Error finding install section in $profiles_ini. Saw: $section"
  fi
  config.py "$profiles_ini" "$section" Default
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
