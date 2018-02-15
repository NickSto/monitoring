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

Usage="Usage: \$ $(basename $0) [tabs_log.tsv [firefox/profile/dir]]
Print records of how many tabs I've had open in recent sessions in Firefox.
This will read the Session Manager backup files from the default Firefox profile, parse them with
my Python script, find how many tabs were open in each, and print the numbers in the format I use
in my tabs log (e.g. ~/aa/computer/logs/tabs.tsv).
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
  session_dir=
  if [[ $# -ge 2 ]]; then
    session_dir="$2/sessionstore-backups"
  fi

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

  session_file="$session_dir/previous.jsonlz4"

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
  echo -e "$modified\t$main\t$total\t$humantime"
}

function get_default_profile {
  profiles_ini="$1"
  while read line; do
    if [[ "${line:0:8}" == '[Profile' ]]; then
      path=
    fi
    if [[ "${line:0:5}" == 'Path=' ]]; then
      path="${line:5}"
    fi
    if [[ "${line:0:8}" == 'Default=' ]] && [[ "${line:8}" == 1 ]] && [[ "$path" ]]; then
      echo "$path"
      return
    fi
  done < "$profiles_ini"
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
