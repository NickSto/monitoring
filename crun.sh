#!/usr/bin/env bash

USAGE="Usage: \$ $(basename $0) [script args] source.c [program args]
       \$ $(basename $0) [script args] -c 'C source code' [program args]
This will compile and execute a C file in one command, so you can make believe
you're still in scripting-land.
As a bonus, it will choose a temporary filename for the binary and delete it
afterward, so you don't overwrite any existing binary.
With the -c flag (\"inline\" option), it will paste your code into the main()
function of a standard C template.
[program args] are any arguments to pass to your C program.
[script args] are arguments for this script:
-i: headers to #include in the inline source. It will not add the angle brackets
    for you, so do that yourself. Use once for each header to include.
    Example: \"-i '<string.h>'\" will result in the line \"#include <string.h>\"
    at the top of the resulting source."
#TODO: allow specifying arbitrary #includes

DEFAULT_INCLUDES="#include <stdio.h>
"
C_TEMPLATE="
#include <stdio.h>
int main(int argc, char *argv[]) {
  %s;
  return 0;
}"

function main {

  if [[ $# -eq 0 ]] || [[ "$1" == '-h' ]]; then
    fail "$USAGE"
  fi

  include_text="$DEFAULT_INCLUDES"

  # Read arguments
  # Will read arguments to the program into "prog_args" array
  declare -a prog_args
  i=0
  state='script_args'
  get_value=''
  for arg in "$@"; do
    if [[ "$arg" == '-c' ]]; then
      inline='true'
    elif [[ "$arg" == '-i' ]]; then
      # flag requires a value
      get_value='include'
    elif [[ $get_value ]]; then
      # preceding flag needs a value, so this should be it
      if [[ $get_value == 'include' ]]; then
        include_text="${include_text}#include $arg
"
      fi
      get_value=''
    elif [[ $state == 'script_args' ]]; then
      csource="$arg"
      state='prog_args'
    elif [[ $state == 'prog_args' ]]; then
      prog_args[i]="$arg"
      i=$((i+1))
    else
      fail "invalid state in argument reading"
    fi
  done
  # You can't add #includes to source files with -i
  if [[ ! $inline ]] && [[ "$include_text" != "$DEFAULT_INCLUDES" ]]; then
    fail '-i flag given without -c flag. -i only works for inline source.'
  fi

  # For inline code, create a temporary file and paste the code into it, then
  # we'll rm it at the end. Also make a copy of non-inline code to work from.
  # Why? The filename for the C source is stored in the same variable in both
  # cases, but sometimes it's rm'd at the end. Even with an "if [[ $inline ]]"
  # check around that, I'm paranoid about rm-ing a variable which *could* be the
  # filename of precious source code. Just so no bug ever results in that, even
  # for non-inline source, I'll make a copy of the file and just work with that.
  if [[ $inline ]]; then
    source_file=$(make_filename "inline.tmp" ".c")
    [[ ! -e "$source_file" ]] && printf "$C_TEMPLATE" "$csource" > "$source_file"
  else
    source_file=$(make_filename "$csource" ".c")
    cp "$csource" "$source_file"
  fi

  if [[ ! $inline ]]; then
    check_file "$source_file"
    libmath=""
    if grep -q -E '^#include ?<math.h>' "$source_file" >/dev/null 2>/dev/null; then
      libmath="-lm"
    fi
  fi

  cbinary=$(make_filename "$source_file")

  # Compile, execute, and cleanup
  if gcc "$source_file" -o "$cbinary" -Wall $libmath; then
    if [[ -n ${prog_args[@]} ]]; then
      ./"$cbinary" "${prog_args[@]}"
    else
      ./"$cbinary"
    fi
    rm "$cbinary"
  else
    fail "Compilation failed"
  fi

  rm "$source_file"
}


#################### FUNCTIONS ####################

# Check if the source file exists and is the correct type.
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

# Return a random, nonexisting filename from "$1.$RANDOM$ext".
# Fails after 50 tries.
function make_filename {
  base="$1"
  ext="$2"
  filename="$base.$RANDOM$ext"
  tries=1
  while [[ -e "$filename" ]]; do
    filename="$base.$RANDOM$ext"
    tries=$((tries+1))
    if [[ $tries -gt 50 ]]; then
      fail 'could not find available temp filename for "'$base'"'
    fi
  done
  echo "$filename"
}

function fail {
  echo "Error: $*" >&2
  exit 1
}

main "$@"
