#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -u

SleepDefault=5

USAGE="Usage: \$ $(basename $0) [options]
Monitor when IP connections are opened or closed. New connections are marked \"+\", closed ones \"-\".
Options:
-w: How long to wait between checks. Default: $SleepDefault seconds.
-n: Don't look up domain names for ip addresses (pass -n to lsof) (is much faster).
-i: Shorthand for \"-T LISTEN,CLOSE_WAIT -D localhost -r TCP\".
Filters:
Use the lowercase to only watch those connections matching that particular criteria. If you want to
give multiple values (e.g. you want to watch connections to google.com and localhost), give them as
a comma-separated list (e.g. \$ netdiff -d localhost,google.com). It will show any connection
matching any of those criteria. The same goes for using multiple different \"watch\" flags.
Use the uppercase flag to ignore any connection matching the given criteria.
If you give both \"watch\" and \"ignore\" flags, only the \"watch\" ones will be used.
-s/-S: Ports (e.g. \"http\", \"3785\"). You must use either the port number or the service name
       according to what lsof uses.
-c/-C: Processes names (\"command\"). Beware that the OS typically truncates this to 15 characters.
-p/-P: Process ids.
-d/-D: Destinations. Give domain names, ip addresses, or hostnames; whatever lsof reports.
-t/-T: Connection states (e.g. \"LISTEN\", \"ESTABLISHED\", \"SYN_SENT\", \"CLOSE_WAIT\").
-r:    Protocols (pretty much just \"TCP\" or \"UDP\"). No -R ignore option for this one."

function main {

  dir=$(real_dir)
  if ! [[ -s $dir/netdiff.awk ]]; then
    fail "Error: cannot locate netdiff.awk."
  fi

  sleep="$SleepDefault"
  protocols=
  lsof_args=
  watch_ports=
  watch_progs=
  watch_procs=
  watch_dests=
  watch_states=
  ignore_ports=
  ignore_progs=
  ignore_procs=
  ignore_dests=
  ignore_states=
  while getopts ":w:ns:c:p:d:t:r:S:C:P:D:T:ih" opt; do
    case "$opt" in
      w) sleep="$OPTARG";;
      n) lsof_args="$lsof_args -n";;
      r) protocols="$(echo "$OPTARG" | sed 's/,/ -i /')";;
      s) watch_ports="$OPTARG";;
      c) watch_progs="$OPTARG";;
      p) watch_procs="$OPTARG";;
      d) watch_dests="$OPTARG";;
      t) watch_states="$OPTARG";;
      S) ignore_ports="$OPTARG";;
      C) ignore_progs="$OPTARG";;
      P) ignore_procs="$OPTARG";;
      D) ignore_dests="$OPTARG";;
      T) ignore_states="$OPTARG";;
      i) ignore_states="LISTEN,CLOSE_WAIT"; ignore_dests="localhost"; protocols="TCP";;
      h) fail "$USAGE";;
    esac
  done

  old=$(tempfile)
  new=$(tempfile)
  touch $old
  trap cleanup SIGINT SIGHUP SIGQUIT SIGKILL

  echo -e '  program\tpid\tport\tdestination\tprotocol\tstate'

  while true; do
    # Run lsof, format and filter the output, and pipe to a temporary file.
    lsof -i $protocols $lsof_args -F pcnTP 2>/dev/null | \
      # Run output through netdiff.awk, which does the formatting and filtering.
      awk -f $dir/netdiff.awk -v watch_ports=$watch_ports -v watch_progs=$watch_progs \
        -v watch_procs=$watch_procs -v watch_dests=$watch_dests -v watch_states=$watch_states \
        -v ignore_ports=$ignore_ports -v ignore_progs=$ignore_progs -v ignore_procs=$ignore_procs \
        -v ignore_dests=$ignore_dests -v ignore_states=$ignore_states | \
      # Sort by program name.
      sort > $new
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
