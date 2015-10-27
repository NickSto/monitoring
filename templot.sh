#!/bin/sh
set -ue

TEMPS="/home/me/.mymisc/temp.log"
DATA="/home/me/.mymisc/templot.tmp"
IMAGE="/tmp/rplot-temp-a63e7e2.png"

R_SCRIPT='temps = read.table("'$DATA'");
png(filename="'$IMAGE'");
plot(temps[,4],temps[,1]);
dev.off()'

tail -n 1000 $TEMPS | sed -r 's/[^0-9\t]//g' > $DATA

r -e "$R_SCRIPT"

eog $IMAGE &