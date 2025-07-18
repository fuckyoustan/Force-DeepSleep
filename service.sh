#!/system/bin/sh

MODDIR=${0%/*}

while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 5
done

sh $MODDIR/deepsleep.sh