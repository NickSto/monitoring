#!/usr/bin/env bash

USAGE="Usage: \$ $(basename $0) source.c [options for your program]
This will compile and execute a C file in one command, so you can make believe
you're still in scripting-land.
As a bonus, it will choose a temporary filename for the binary and delete it
afterward, so you don't overwrite any existing binary."

function main {
  if [[ $# -lt 1 ]]; then
    fail "$USAGE"
  fi

  i=0
  declare -a opts
  for opt in "$@"; do
    i=$((i+1))
    #TODO: allow for options to this script before the source file
    if [[ $i == 1 ]]; then
      csource="$opt"
    else
      # options for the actual program being executed
      opts[i]="$opt"
    fi
  done

  if [[ ! -s "$csource" ]]; then
    fail "Error: $csource nonexistent or empty"
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
      fail "Error: could not find  $cbinary already exists"
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
    fail "Compilation error"
  fi
}

function fail {
  echo "$*" >&2
  exit 1
}

main "$@"
