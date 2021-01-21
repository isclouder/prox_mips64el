#!/bin/sh

i=$(grep iso9660 /proc/mounts);

for try in 5 4 3 2 1; do
    echo "unmounting cdrom"
    if umount /mnt; then 
	break
    fi
    if test -n $try; then
	echo "unmount failed -trying again in 5 seconds"
	sleep 5
    fi
done

if [ -n "$i" ]; then
    set $i
    eject $1
fi

echo "rebooting - please remove the CD"
sleep 3
echo b > /proc/sysrq-trigger
sleep 100
