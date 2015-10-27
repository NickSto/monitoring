#!/bin/sh
set -ue

TEMPS="/home/me/.mymisc/temp.log"
DATA="/home/me/.mymisc/templot.tmp"
IMAGE="/tmp/rplot-temp-a63e7e2.png"
PTS_DEFAULT=250

R_SCRIPT='temps = read.table("'$DATA'");
png(filename="'$IMAGE'");
plot(temps[,4],temps[,1]);
dev.off()'

pts=${1:-$PTS_DEFAULT}
echo "Showing $pts timepoints"

tail -n $pts $TEMPS | sed -r 's/[^0-9\t]//g' > $DATA

r -e "$R_SCRIPT"

eog $IMAGE 2>/dev/null &
