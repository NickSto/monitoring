#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

LogDefault="$HOME/aa/misc/backups/0historical-record/mv.tsv"
Usage="Usage: \$ $(basename $0) [-n] [-v] [-l log.tsv] src dst
Move the src path to dst and record the move in a log.
-l: The log file to record it in.
    Default: $LogDefault
-v: Verbose. Show the move it executes and what it records in the log.
-n: Simulate only. Do not actually move or record anything.
    Implies -v."

function main {
  if [[ $# -lt 2 ]] || [[ $1 == '-h' ]] || [[ $1 == '--help' ]]; then
    fail "$Usage"
  fi

  verbose=
  simulate=
  log="$LogDefault"
  while getopts ":l:vnh" opt; do
  case "$opt" in
      l) log="$OPTARG";;
      v) verbose=true;;
      n) simulate=true
         verbose=true;;
      h) fail "$Usage";;
    esac
  done

  src="${@:$OPTIND:1}"
  dst="${@:$OPTIND+1:1}"
  abs_src=$(abspath "$src")
  abs_dst=$(abspath "$dst")

  if ! [[ -f "$log" ]]; then
    fail "Error: log file \"$log\" not found."
  fi
  if ! ([[ -f "$abs_src" ]] || [[ -d "$abs_src" ]]); then
    fail "Error: given source path is not a regular file or directory: \"$abs_src\""
  fi
  if [[ -e "$abs_dst" ]]; then
    fail "Error: given destination path already exists: \"$abs_dst\""
  fi

  now=$(date +%s)

  if [[ $verbose ]]; then
    echo 'mv "'$abs_src'" "'$abs_dst'"'
  fi
  if ! [[ $simulate ]]; then
    mv "$abs_src" "$abs_dst"
  fi

  if [[ $verbose ]]; then
    printf "%d\t%s\t%s\n" $now "$abs_src" "$abs_dst"
  fi
  if ! [[ $simulate ]]; then
    printf "%d\t%s\t%s\n" $now "$abs_src" "$abs_dst" >> "$log"
  fi

}

function abspath {
  local inpath="$1"
  if readlink -m dummy >/dev/null 2>/dev/null; then
    readlink -m "$inpath"
  else
    # no readlink -m on BSD
    unset CDPATH
    if [[ -d "$inpath" ]]; then
      echo $(cd "$inpath"; pwd)
    else
      echo $(cd $(dirname "$inpath"); pwd)/$(basename "$inpath");
    fi
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
