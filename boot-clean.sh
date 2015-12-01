#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

USAGE="Usage: \$ $(basename $0)
Uninstall all previous ubuntu packages for the linux kernel version currently in use.
Note: Requires a 3.x-generic kernel."

function main {

  y=''
  if [[ $# -gt 0 ]]; then
    if [[ $1 == '-h' ]]; then
      fail "$USAGE"
    elif [[ $1 == '-f' ]]; then
      y='-y'
    fi
  fi

  if [[ $EUID != 0 ]]; then
    fail "Error: Must run with root permissions."
  fi

  current=$(uname -r)
  if ! [[ "$current" =~ ^3\.[0-9]+\.[0-9]+-[0-9]+-generic$ ]]; then
    fail "Error: Current kernel ($current) not of the expected format."
  else
    echo "Kernel currently in use is $current"
  fi

  #TODO: Just find and remove the linux-image-* and linux-headers-* packages and then autoremove to
  #      clean up the rest?

  # Turn current kernel version number into regex for matching packages for the same release.
  # Turns "3.16.0-46-generic" into "^linux-.*-3\.16\.0-46(-generic|$)".
  exact_regex=$(echo "$current" \
    | sed -E -e 's/\./\\./g' -e 's/^/^linux-.*-/' -e 's/-generic$/(-generic|$)/g')

  # Turn exact kernel version regex into one matching any ubuntu release of the current kernel.
  # Turns "^linux-.*-3\.16\.0-46(-generic|$)" into "^linux-.*-3\.16\.0-[0-9]{1,3}(-generic|$)"
  releases_regex=$(echo "$exact_regex" \
    | sed -E 's/-[0-9]+\(-generic/-[0-9]{1,3}(-generic/')

  # Note: Both regexes match these types of kernel packages:
  # linux-headers-3.13.0-46
  # linux-headers-3.13.0-46-generic
  # linux-image-3.13.0-45-generic
  # linux-image-extra-3.13.0-45-generic
  # linux-signed-image-3.13.0-45-generic

  remove_todo=''
  for package in $(dpkg --get-selections | awk '$2 == "install" {print $1}'); do
    if echo "$package" | grep -qE "$releases_regex"; then
      if ! echo "$package" | grep -qE "$exact_regex"; then
        remove_todo="$remove_todo $package"
      fi
    fi
  done

  if ! [[ $remove_todo ]]; then
    echo "No old releases found!"
    exit 0
  fi

  echo "Packages to be removed:"
  for package in $remove_todo; do
    echo -e "\t$package"
  done

  # Do the actual uninstallation.
  #TODO: Add -y option to skip the prompt.
  #TODO: apt-get purge instead?
  apt-get remove $y $remove_todo
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
