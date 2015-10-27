#!/bin/sh
set -ue

TEMPS="/home/me/.local/share/nbsdata/temp.log"
PTS_DEFAULT=250
#DATA="/tmp/templot-a63e7e2.tmp"
#IMAGE="/tmp/rplot-temp-a63e7e2.png"
datafile=$(mktemp)
imgfile=$(mktemp)

R_SCRIPT='temps = read.table("'$datafile'");
png(filename="'$imgfile'");
plot(temps[,4],temps[,1]);
dev.off()'

pts=${1:-$PTS_DEFAULT}
echo "Showing $pts timepoints"

tail -n $pts $TEMPS | sed -r 's/[^0-9\t]//g' > $datafile

r -e "$R_SCRIPT"

(eog $imgfile 2>/dev/null; rm $imgfile; rm $datafile) &
