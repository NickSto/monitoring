#!/usr/bin/env bash

DEFAULT_INCLUDES="#include <stdio.h>
"
C_TEMPLATE="%s
int main(int argc, char *argv[]) {
  %s;
  return(0);
}"

USAGE="Usage: \$ $(basename $0) [script args] source.c [program args]
       \$ $(basename $0) [script args] -c 'C source code' [program args]
This will compile and execute a C file in one command, so you can make believe
you're still in scripting-land.
As a bonus, it will choose a temporary filename for the binary and delete it
afterward, so you don't overwrite any existing binary.
    [program args] are any arguments to pass to your C program.
    [script args] are arguments for this script:
-c: \"Inline\" option. Instead of giving a source file, give some literal C code
    to be executed. The code will be pasted into the main() function of a
    generic C template.
-p: Print the full C source to stdout before executing. Most useful for -c
    inline code, but will also print source files.
-i: Headers to #include in the inline source. It will not add the angle brackets
    for you, so do that yourself. Use once for each header to include.
    Example: \"-i '<string.h>'\" will result in the line \"#include <string.h>\"
    at the top of the resulting source.
    Default headers:
$DEFAULT_INCLUDES"

function main {

  if [[ $# -eq 0 ]] || [[ "$1" == '-h' ]]; then
    echo -n "$USAGE" >&2
    exit 1
  fi

  include_text="$DEFAULT_INCLUDES"

  # Read arguments
  # Will read arguments to the program into "prog_args" array
  declare -a prog_args
  i=0
  print_source=''
  get_value=''
  state='script_args'
  for arg in "$@"; do
    if [[ "$arg" == '-c' ]]; then
      inline='true'
    elif [[ "$arg" == '-p' ]]; then
      print_source='true'
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
    printf "$C_TEMPLATE" "$include_text" "$csource" > "$source_file"
  else
    source_file=$(make_filename "$csource" ".c")
    cp "$csource" "$source_file"
  fi

  # Check source file
  libmath=""
  if [[ ! $inline ]]; then
    if ! check_file "$source_file"; then
      rm "$source_file"
      exit 1;
    fi
    # If math.h is included, -lm needs to be added to the gcc command
    if grep -q -E '^#include ?<math.h>' "$source_file" >/dev/null 2>/dev/null; then
      libmath="-lm"
    fi
  fi

  # print source
  if [[ $print_source ]]; then
    cat "$source_file"
    echo
  fi

  cbinary=$(make_filename "$source_file")

  # Compile, execute, and cleanup
  if gcc "$source_file" -o "$cbinary" -Wall $libmath; then
    if [[ -n ${prog_args[@]} ]]; then
      ./"$cbinary" "${prog_args[@]}"
    else
      ./"$cbinary"
    fi
    ret=$?
    rm "$cbinary"
  else
    fail "Compilation failed"
  fi

  rm "$source_file"

  exit $ret
}


#################### FUNCTIONS ####################

# Check if the source file exists and is the correct type.
function check_file {
  csource="$1"
  if [[ ! -s "$csource" ]]; then
    echo "$csource nonexistent or empty" >&2
    return 1
  fi
  filetype=$(file -b --mime-type "$csource")
  if [[ $filetype != "text/x-c" ]]; then
    echo '"file" reports the source file type as "'$filetype'"' >&2
    return 1
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
