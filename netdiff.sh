#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -u

SleepDefault=5
WatchPortsDefault=''
WatchProgsDefault=''
WatchProcsDefault=''
IgnorePortsDefault='http,https'
IgnoreProgsDefault=''
IgnoreProcsDefault=''

USAGE="Usage: \$ $(basename $0) [options]
Monitor when IP connections are opened or closed. New connections are marked \"+\", closed ones \"-\".
Options:
-w: How long to wait between checks. Default: $SleepDefault seconds.
-s: Port(s) to watch exclusively. Give in a comma-separated list, like \"http,3785\". You must use
    either the port number or the service name according to what netstat uses.
    Default: \"$IgnorePortsDefault\".
-c: Processes name(s) to watch exclusively.
-p: Process id(s) to watch exclusively.
-S: Port(s) to ignore. Give as a comma-separated list.
-C: Process name(s) to ignore.
-P: Process id(s) to ignore."

function main {

  dir=$(real_dir)
  if ! [[ -s $dir/netdiff.awk ]]; then
    fail "Error: cannot locate netdiff.awk."
  fi

  sleep="$SleepDefault"
  watch_ports="$WatchPortsDefault"
  watch_progs="$WatchProgsDefault"
  watch_procs="$WatchProcsDefault"
  ignore_ports="$IgnorePortsDefault"
  ignore_progs="$IgnoreProgsDefault"
  ignore_procs="$IgnoreProcsDefault"
  while getopts ":w:s:c:p:S:C:P:h" opt; do
    case "$opt" in
      w) sleep="$OPTARG";;
      s) watch_ports="$OPTARG";;
      c) watch_progs="$OPTARG";;
      p) watch_procs="$OPTARG";;
      S) ignore_ports="$OPTARG";;
      C) ignore_progs="$OPTARG";;
      P) ignore_procs="$OPTARG";;
      h) fail "$USAGE";;
    esac
  done

  old=$(tempfile)
  new=$(tempfile)
  touch $old
  trap cleanup SIGINT SIGHUP SIGQUIT SIGKILL

  while true; do
    netstat -A inet,inet6 --program -W 2>/dev/null | \
        awk -f $dir/netdiff.awk -v watch_ports=$watch_ports \
        -v watch_progs=$watch_progs -v watch_procs=$watch_procs \
        -v ignore_ports=$ignore_ports -v ignore_progs=$ignore_progs \
        -v ignore_procs=$ignore_procs > $new
    diff=$(diff $old $new | sed -En -e 's/^>/+/p' -e 's/^</-/p')
    if [[ "$diff" ]]; then
      echo "$diff"
      echo '--------------'
    fi
    mv $new $old
    sleep $sleep
  done
}


function real_dir {
  if readlink -f test >/dev/null 2>/dev/null; then
    dirname $(readlink -f $0)
  else
    # If readlink -f doesn't work (like on BSD).
    # Read the link destination from the output of ls -l and cd to it.
    # Have to cd to the link's directory first, to handle relative links.
    # Currently only works with one level of linking.
    cd $(dirname $0)
    script=$(basename $0)
    link=$(ls -l $script | awk '{print $NF}')
    cd $(dirname $link)
    pwd
  fi
}


function cleanup {
  rm $old 2>/dev/null
  rm $new 2>/dev/null
  exit
}


function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
