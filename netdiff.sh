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
-c: Processes(s) to watch exclusively. Give in a comma-separated list, like \"firefox,chrome\".
-S: Ignore connections to these services. Give as a comma-separated list. You must use either the
    port number or the service name according to what netstat uses. Default: \"$IgnorePortsDefault\"."

function main {

  sleep="$SleepDefault"
  watch_ports=$(echo "$WatchPortsDefault" | tr ',' '|')
  watch_progs=$(echo "$WatchProgsDefault" | tr ',' '|')
  watch_procs=$(echo "$WatchProcsDefault" | tr ',' '|')
  ignore_ports=$(echo "$IgnorePortsDefault" | tr ',' '|')
  ignore_progs=$(echo "$IgnoreProgsDefault" | tr ',' '|')
  ignore_procs=$(echo "$IgnoreProcsDefault" | tr ',' '|')
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

  #TODO: Finish implementing watches and ignores
  #TODO: Inclulde --program in every output
  while true; do
    if [[ $watch_progs ]]; then
      netstat --inet --program -W 2>/dev/null | \
        awk -v OFS='\t' '$6 == "ESTABLISHED" {split($7,prog,"/"); if (prog[2] ~ /^('$watch_progs')$/) {print prog[2], $5}}' > $new
    elif [[ $watch_ports ]]; then
      netstat --inet -W | awk '$6 == "ESTABLISHED" {print $5}' | grep -E ":($watch_ports)$" > $new
    else
      netstat --inet -W | awk '$6 == "ESTABLISHED" {print $5}' | grep -vE ":($ignore_ports)$" > $new
    fi
    diff=$(diff $old $new | sed -En -e 's/^>/+/p' -e 's/^</-/p')
    if [[ "$diff" ]]; then
      echo "$diff"
      echo '--------------'
    fi
    mv $new $old
    sleep $sleep
  done
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
