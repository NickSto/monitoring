#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Usage="Usage: \$ $(basename $0) [-t timeout] 'entry command' ['exit command']
Run a command, then when the user hits enter, run a second command.
Optionally, give a time to -t and the script will automatically run the second
command after the given time.
You can always skip the second command by exiting with Ctrl+C."

function main {

  # Read arguments.
  if [[ $# -lt 1 ]]; then
    fail "$Usage"
  fi

  timeout=
  while getopts ":t:h" opt; do
  case "$opt" in
      t) timeout=$OPTARG;;
      h) echo "$USAGE"
         exit;;
    esac
  done
  entry_cmd="${@:$OPTIND:1}"
  exit_cmd="${@:$OPTIND+1:1}"

  if ! [[ "$exit_cmd" ]]; then
    exit_cmd="$entry_cmd"
  fi

  if [[ $timeout ]]; then
    if ! echo $timeout | grep -qE '^[0-9]+[smhd]?$'; then
      fail "Error: -t timeout must be an integer, plus a unit \"sleep\" understands, like \"s\", \
\"m\", \"h\", or \"d\"."
    fi
  fi

  # For $timeout, set up a function to execute the $exit_cmd when this script receives a SIGALRM
  # signal (which it will send itself the specified amount of time in the future).
  function exit_fxn {
    eval "$exit_cmd"
    exit
  }
  trap exit_fxn SIGALRM

  # Run the $entry_cmd.
  echo "Running entry command \"$entry_cmd\".."
  eval "$entry_cmd"
  echo
  # Pause, and print info on the user's options.
  if [[ $timeout ]]; then
    echo "Pausing for $timeout.."
  else
    echo "Pausing."
  fi
  echo "Press  [enter] to run the exit command."
  echo "Or hit [Ctrl+C] to exit without running the exit command (\"$exit_cmd\")"
  echo
  # If $timeout, set up a timer which will make the script wake up and execute the $exit_cmd.
  if [[ $timeout ]]; then
    # The following is executed in a subshell (child process).
    (
      # Sleep for the specified amount of time.
      sleep $timeout;
      # Check that this script is still running.
      if [[ $(ps -o comm= -p $$) == bash ]]; then
      # Send the SIGALRM signal.
        kill -s SIGALRM $$
      fi
    ) &
  fi
  # This will pause the script until the user hits [enter].
  read
  # Run the $exit_cmd.
  eval "$exit_cmd"

}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
