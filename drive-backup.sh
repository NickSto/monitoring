#!/usr/bin/env bash
set -ue

# N.B.: These path names cannot contain spaces!
DIRECTORIES="misc/DVDs misc/isos misc/offsite-backup misc/oldversions misc/podcasts misc/ROFLCon"

BACKUP_DIR="2TB-backup"
SOURCE_ROOT='/media/truecrypt4'
DEST_ROOT='/media/truecrypt5'
SOURCE_SIZE=1953511744 # bytes
DEST_SIZE=488383744    # bytes

USAGE="Usage: \$ $(basename $0)
This will backup certain directories from the 2TB external drive to the 500GB external drive. The drives must be mounted at $SOURCE_ROOT and $DEST_ROOT, respectively. It uses rsync to do the backup, and will not start unless there is enough free space. The directories are:
$DIRECTORIES"

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
for dir in $DIRECTORIES; do
  if [[ ! -d $SOURCE_ROOT/$dir ]]; then
    fail "Error: directory \"$SOURCE_ROOT/$dir\" not found."
  fi
done
if [[ ! -d $DEST_ROOT/$BACKUP_DIR ]]; then
  fail "Error: destination directory \"$DEST_ROOT/$BACKUP_DIR\" not found."
fi

# Check disk space
free_size=$(df | awk '$6 == "'$DEST_ROOT'" {print $4}')
free=$((1024 * $free_size))
bytes_todo=0
# sum up size of source directories
for dir in $DIRECTORIES; do
  dir_size=$(du -sb $SOURCE_ROOT/$dir | awk '{print $1}')
  bytes_todo=$(($bytes_todo + $dir_size))
done
# subtract existing size of destination directory
dest_size=$(du -sb $DEST_ROOT/$BACKUP_DIR | awk '{print $1}')
bytes_todo=$(($bytes_todo - $dest_size))
if [[ $bytes_todo -gt $free ]]; then
  fail "Error: Not enough free space on destination drive. Existing: $free bytes, needed: $bytes_todo bytes."
fi

# Do the actual backup
for dir in $DIRECTORIES; do
  dest_path=$DEST_ROOT/$BACKUP_DIR/$dir
  if [[ ! -d $dest_path ]]; then
    mkdir -p $dest_path
  fi
  rsync --delete -zavXA $SOURCE_ROOT/$dir/ $dest_path/
done
