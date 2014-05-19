#!/usr/bin/env bash
set -ue

# N.B.: These path names cannot contain spaces!
PATHS="
misc/DVDs
misc/isos
misc/offsite-backup
misc/oldversions
misc/podcasts
misc/ROFLCon
misc/DesertBusHomestretch.m4v
misc/gmail-backup-theqwerty0-2013-03-03.dat
misc/lrrcraft_old_creative.tgz
misc/Redneck-Rampage-GOG.exe
backup.sh"

BACKUP_DIR="2TB-backup"
SOURCE_ROOT='/media/truecrypt4'
DEST_ROOT='/media/truecrypt5'
SOURCE_SIZE=1953511744 # bytes
DEST_SIZE=488383744    # bytes

USAGE="Usage: \$ $(basename $0)
This will backup certain files from the 2TB external drive to the 500GB external drive. The drives must be mounted at $SOURCE_ROOT and $DEST_ROOT, respectively. It uses rsync to do the backup, and will not start unless there is enough free space. The files and directories to be backed up are: $PATHS"

function fail {
  echo "$@" >&2
  exit 1
}

if [[ $# -gt 0 ]]; then
  fail "$USAGE"
fi

# Are the two drives mounted in the right place?
if [[ $(df | awk '$6 == "'$SOURCE_ROOT'" {print $2}') != $SOURCE_SIZE ]]; then
  fail "Error: 2TB drive must be mounted on $SOURCE_ROOT"
fi
if [[ $(df | awk '$6 == "'$DEST_ROOT'" {print $2}') != $DEST_SIZE ]]; then
  fail "Error: 500GB drive must be mounted on $DEST_ROOT"
fi

# Do the right directories exist?
for path in $PATHS; do
  if [[ ! -e $SOURCE_ROOT/$path ]]; then
    fail "Error: backup target \"$SOURCE_ROOT/$path\" not found."
  fi
done
if [[ ! -d $DEST_ROOT/$BACKUP_DIR ]]; then
  fail "Error: destination backup directory \"$DEST_ROOT/$BACKUP_DIR\" not found."
fi

# Check disk space
free_size=$(df | awk '$6 == "'$DEST_ROOT'" {print $4}')
free=$((1024 * $free_size))
bytes_todo=0
# sum up size of source paths
for path in $PATHS; do
  dir_size=$(du -sb $SOURCE_ROOT/$path | awk '{print $1}')
  bytes_todo=$(($bytes_todo + $dir_size))
done
# subtract existing size of destination directory
dest_size=$(du -sb $DEST_ROOT/$BACKUP_DIR | awk '{print $1}')
bytes_todo=$(($bytes_todo - $dest_size))
if [[ $bytes_todo -gt $free ]]; then
  fail "Error: Not enough free space on destination drive. Existing: $free bytes, needed: $bytes_todo bytes."
fi

# Do the actual backup
for path in $PATHS; do
  # Make sure there's a parent directory at the destination
  dest_parent=$(dirname $DEST_ROOT/$BACKUP_DIR/$path)
  if [[ ! -d $dest_parent ]]; then
    mkdir -p $dest_parent
  fi
  if [[ -d $SOURCE_ROOT/$path ]]; then
    # if it's a directory
    rsync --delete -zavXA $SOURCE_ROOT/$path/ $DEST_ROOT/$BACKUP_DIR/$path/
  else
    # if it's a file
    rsync --delete -zavXA $SOURCE_ROOT/$path $dest_parent/
  fi
done
