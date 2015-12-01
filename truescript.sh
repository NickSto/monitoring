#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

MntDir=/media

Usage="\$ $(basename $0) truecrypt-file [mount point]
Simple command to mount or dismount a truecrypt file.
It mostly keeps you from having to type out all the options like
  \$ truecrypt -t -k '' --protect-hidden=no encrypted.dat $MntDir/truecrypt1
If the file is not currently mounted, this will automatically mount it at the
first available mount point (e.g. $MntDir/truecrypt1). If it's currently mounted,
it will unmount it. You can optionally specify the mount point manually."

function main {

  if [[ $# -lt 1 ]] || [[ $1 == '-h' ]]; then
    fail "$Usage"
  fi

  file="$(abspath "$1")"

  mount_point=''
  if [[ $# -ge 2 ]]; then
    mount_point="$2"
    if truecrypt --text --list 2>/dev/null | grep -q "$mount_point" >/dev/null 2>/dev/null; then
      fail "Error: mount point $mount_point already in use."
    fi
  fi

  # Is the file currently mounted?
  if truecrypt --text --list 2>/dev/null | grep -q "$file" >/dev/null 2>/dev/null; then
    mount=''
  else
    mount=true
  fi

  if [[ $mount ]]; then
    if ! ([[ -f "$file" ]] || [[ -b "$file" ]]); then
      fail "Error: $file does not exist or is not a regular file or block device."
    fi
    if ! [[ -d $MntDir ]]; then
      fail "Error: $MntDir directory does not exist."
    fi
    # Check for open mount points.
    if ! [[ "$mount_point" ]]; then
      for i in {1..64}; do
        mount_point=$MntDir/truecrypt$i
        if [[ -d $mount_point ]]; then
          if [[ $(find $mount_point -maxdepth 1 | wc -l) -gt 1 ]]; then
            continue  # mount point in use
          elif [[ $(mount | awk '$3 == "'$mount_point'" {print $0;}') ]]; then
            continue  # mount point in use
          else
            break  # mount point not in use
          fi
        else
          break  # mount point not in use
        fi
      done
      if [[ $i == 64 ]]; then
        fail "Error: cannot find a free mount point."
      fi
    fi
    truecrypt -t -k '' --protect-hidden=no "$file" "$mount_point"
  else
    #TODO: Handle filenames with spaces.
    if has_spaces "$file"; then
      fail "Error: encrypted file path contains spaces."
    fi
    mount_point="$(truecrypt --text --list | awk '$2 == "'"$file"'" {print $4}')"
    if ! [[ $mount_point ]]; then
      fail "Error: file $file not found in list of mounted volumes."
    fi
    truecrypt -d "$mount_point"
  fi
}

function abspath {
  local inpath="$1"
  if readlink -m dummy >/dev/null 2>/dev/null; then
    readlink -m "$inpath"
  else
    unset CDPATH
    if [[ -d "$inpath" ]]; then
      echo $(cd "$inpath"; pwd)
    else
      echo $(cd $(dirname "$inpath"); pwd)/$(basename "$inpath");
    fi
  fi
}

function has_spaces {
  with=$(echo -n "$1" | wc -c)
  without=$(echo -n "$1" | tr -d ' \t\n\r' | wc -c)
  if [[ $with == $without ]]; then
    return 1
  else
    return 0
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
