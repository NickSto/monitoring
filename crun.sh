#!/usr/bin/env bash

USAGE="Usage: \$ $(basename $0) source.c [options for your program]
       \$ $(basename $0) -c 'C source code'
This will compile and execute a C file in one command, so you can make believe
you're still in scripting-land.
As a bonus, it will choose a temporary filename for the binary and delete it
afterward, so you don't overwrite any existing binary.
With the -c option, it will paste your code into the main() function of a
standard C template."

function main {

  fromfile="true"
  if [[ $# -eq 0 ]] || [[ "$1" == '-h' ]]; then
    fail "$USAGE"
  elif [[ "$1" == '-c' ]]; then
    fromfile=0
    die "inline option not yet implemented"
  fi

  i=0
  if [[ $fromfile ]]; then
    source_i=1
    opts_start=2
  else
    source_i=2
    opts_start=3
  fi
  declare -a opts
  for opt in "$@"; do
    i=$((i+1))
    #TODO: allow for options to this script before the source file
    if [[ $i == $source_i ]]; then
      csource="$opt"
    elif [[ $i -gt $source_i ]]; then
      # options for the actual program being executed
      opts[i]="$opt"
    fi
  done

  if [[ ! -s "$csource" ]]; then
    fail "$csource nonexistent or empty"
  fi

  filetype=$(file -b --mime-type "$csource")
  if [[ $filetype != "text/x-c" ]]; then
    fail '"file" reports the source file type as "'$filetype'"'
  fi

  libmath=""
  if grep -q -E '^#include ?<math.h>' $csource >/dev/null 2>/dev/null; then
    libmath="-lm"
  fi

  cbinary="$csource.$RANDOM"
  tries=1
  while [[ -e "$cbinary" ]]; do
    cbinary="$csource.$RANDOM"
    tries=$((tries+1))
    if [[ $tries -gt 50 ]]; then
      fail "could not find  $cbinary already exists"
    fi
  done

  # Compile, execute, and cleanup
  if gcc "$csource" -o "$cbinary" -Wall $libmath; then
    if [[ -z ${opts[@]} ]]; then
      ./"$cbinary" "${opts[@]}"
    else
      ./"$cbinary"
    fi
    rm "$cbinary"
  else
    fail "Compilation failed"
  fi
}

function fail {
  echo "Error: $*" >&2
  exit 1
}

main "$@"
