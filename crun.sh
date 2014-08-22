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

  if [[ $# -eq 0 ]] || [[ "$1" == '-h' ]]; then
    fail "$USAGE"
  fi

  # Read arguments
  # Detect '-c' argument. Means the rest of the arguments will be shifted by 1.
  i=0
  if [[ "$1" == '-c' ]]; then
    fail 'inline option not yet implemented'
    inline='true'
    source_i=2
  else
    inline=0
    source_i=1
  fi
  # Will read options to the program into "opts" array
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

  if [[ !$inline ]]; then
    check_file "$csource"
    libmath=""
    if grep -q -E '^#include ?<math.h>' $csource >/dev/null 2>/dev/null; then
      libmath="-lm"
    fi
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
    if [[ -n ${opts[@]} ]]; then
      ./"$cbinary" "${opts[@]}"
    else
      ./"$cbinary"
    fi
    rm "$cbinary"
  else
    fail "Compilation failed"
  fi
}

# check if the source file exists and is the correct type
function check_file {
  csource="$1"
  if [[ ! -s "$csource" ]]; then
    fail "$csource nonexistent or empty"
  fi
  filetype=$(file -b --mime-type "$csource")
  if [[ $filetype != "text/x-c" ]]; then
    fail '"file" reports the source file type as "'$filetype'"'
  fi
}

function fail {
  echo "Error: $*" >&2
  exit 1
}

main "$@"
