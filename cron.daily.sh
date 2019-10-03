#!/usr/bin/env bash

USER=me
HOME=/home/me
SHELL=/bin/bash
PATH=/home/me/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/home/me/.local/bin
MAILTO=""
DESKTOP_SESSION=ubuntu
DISPLAY=:0
LANG=en_US.UTF-8
LANGUAGE=en_US
GDMSESSION=ubuntu
LOGNAME=me
DEFAULTS_PATH=/usr/share/gconf/ubuntu.default.path
MANDATORY_PATH=/usr/share/gconf/ubuntu.mandatory.path
SESSION=ubuntu

# Record a log of how many tabs I have open.
#bash $HOME/code/bash/single/tab-log.sh -l $HOME/aa/computer/logs/tabs.tsv >> $HOME/aa/computer/logs/tabs.tsv
# Back up custom dconf settings.
dconf dump / > "$HOME/aa/misc/backups/dconf.txt"

# Save a survey of my files.
snap_dir="$HOME/aa/misc/backups/0historical-record/dir-snapshots/live"
"$HOME/code/python/files/file-metadata.py" -p low -r -a crc32 "$HOME/"{aa,annex,aux,bin,code,Desktop,Dropbox,src,Templates,vbox,Videos,.config,.local,.mozilla,.ssh} \
  | gzip -c - > "$snap_dir/snapshot-selected.tmp.tsv.gz"
if [[ "$?" == 0 ]]; then
  "$HOME/bin/archive-file.py" --min-size 500000 "$snap_dir/snapshot-selected.tsv.gz" -e .tsv.gz
  mv "$snap_dir/snapshot-selected.tmp.tsv.gz" "$snap_dir/snapshot-selected.tsv.gz"
fi
