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
dconf dump / > $HOME/aa/misc/backups/dconf.txt

# Save a survey of my files.
$HOME/bin/archive-file.py --min-size 500000 $HOME/aa/misc/backups/0historical-record/dir-snapshots/live/snapshot-selected.tsv.gz -e .tsv.gz
$HOME/code/python/files/file-metadata.py -p low -r -a crc32 $HOME/aa $HOME/annex $HOME/aux $HOME/bin $HOME/code $HOME/Desktop $HOME/Dropbox $HOME/src $HOME/Templates $HOME/vbox $HOME/Videos $HOME/.config $HOME/.local $HOME/.mozilla $HOME/.ssh | gzip -c - > $HOME/aa/misc/backups/0historical-record/dir-snapshots/live/snapshot-selected.tsv.gz
