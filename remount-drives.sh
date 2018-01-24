#!/usr/bin/env bash
if [ x$BASH = x ] || [ ! $BASH_VERSINFO ] || [ $BASH_VERSINFO -lt 4 ]; then
  echo "Error: Must use bash version 4+." >&2
  exit 1
fi
set -ue

Usage="Usage: \$ $(basename $0)
Unmount and remount all 3 of my external hard drives with Veracrypt."

function main {
  if [[ $# -ge 1 ]] && ([[ $1 == '-h' ]] || [[ $1 == '--help' ]]); then
    fail "$Usage"
  fi

  # Get the password for all the volumes.
  printf 'Enter drive encryption password: '
  # Don't echo it to the screen.
  # read -s is only a bash feature, so let's belt-and-suspenders to make sure it isn't shown.
  stty -echo
  read -s password
  stty echo
  echo

  # Obtain sudo so it's cached for the mount/unmount operations later.
  # The mount commands are --non-interactive, so they'll just fail without sudo permissions, instead
  # of prompting the user.
  sudo echo -ne

  # First, unmount everything.
  echo 'Unmounting all drives..'
  for i in {1..3}; do
    vc_unmount "/media/veracrypt$i"
  done

  # Then, mount all the drives.
  echo 'Mounting all drives..'
  while read name majmin rm size ro type mount; do
    if [[ $size == 4000787030016 ]] && [[ ${name:${#name}-1:1} != 1 ]]; then
      # The 4TB drive.
      echo 'Starting on 4TB drive..'
      echo "$password" | vc_mount /dev/$name /media/veracrypt1
    elif [[ $size == 2000396289024 ]] && [[ ${name:${#name}-1:1} == 1 ]]; then
      # The 2TB drive.
      echo 'Starting on 2TB drive..'
      echo "$password" | vc_mount /dev/$name /media/veracrypt2 truecrypt
    elif [[ $size == 500105217024 ]] && [[ ${name:${#name}-1:1} == 1 ]]; then
      # The 500GB drive.
      echo 'Starting on 500GB drive..'
      echo "$password" | vc_mount /dev/$name /media/veracrypt3 truecrypt
    fi
  done < <(lsblk -lb)
}


function vc_unmount {
  mount=$1
  set +e
  mounted_volumes=$(veracrypt -t -l 2>/dev/null)
  set -e
  echo "$mounted_volumes" | while read slot device mapper this_mount; do
    if [[ $this_mount == $mount ]]; then
      echo "Unmounting $device from $mount.."
      veracrypt -t -d $mount
      return
    fi
  done
}


function vc_mount {
  # Password is passed via stdin to this function.
  device=$1
  mount=$2
  if [[ $# -ge 3 ]]; then
    tc_arg=--truecrypt
  else
    tc_arg=
  fi
  slot=$(find_slot)
  echo "Mounting $device on $mount in slot $slot.."
  set +e
  err=$(veracrypt -t $tc_arg --stdin --non-interactive --slot=$slot -k '' --protect-hidden=no \
        $device $mount 2>&1)
  set -e
  while [[ "$err" == 'Error: Volume slot unavailable.' ]] && [[ "$slot" -le 64 ]]; do
    slot=$((slot+1))
    echo "Warning: slot $((slot-1)) occupied. Retrying with slot $slot.."
    set +e
    err=$(veracrypt -t $tc_arg --stdin --non-interactive --slot=$slot -k '' --protect-hidden=no \
          $device $mount 2>&1)
    set -e
  done
}


function find_slot {
  # Find a free veracrypt mount slot.
  # First, read in the used slots from the veracrypt command.
  declare -a used_slots
  set +e
  while read slot rest; do
    # Remove trailing :.
    slot=${slot%:}
    used_slots[$slot]=true
  done < <(veracrypt -t -l 2>/dev/null)
  set -e
  # Then look for one that isn't used.
  set +u
  candidate=1
  while [[ ${used_slots[$candidate]} ]]; do
    candidate=$((candidate+1))
  done
  set -u
  if [[ $candidate -gt 64 ]]; then
    return 1
  else
    echo "$candidate"
  fi
}

function fail {
  echo "$@" >&2
  exit 1
}

main "$@"
