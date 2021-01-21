#!/bin/bash

trap "err_reboot" ERR

parse_cmdline() {
    root=
    proxdebug=0
    for par in $(cat /proc/cmdline); do 
	case $par in
	    root=*)
		root=${par#root=}
		;;
	    proxdebug)
		proxdebug=1
		;;
	esac
    done;
}

debugsh() {
    /bin/bash
}

real_reboot() {

    trap - ERR 

    /etc/init.d/networking stop 

    # stop udev (release file handles)
    /etc/init.d/udev stop

    echo -n "Deactivating swap..."
    swap=$(grep /dev /proc/swaps);
    if [ -n "$swap" ]; then
       set $swap
       swapoff $1
    fi
    echo "done."

    umount -l -n /target >/dev/null 2>&1
    umount -l -n /dev
    umount -l -n /run
    [ -d /sys/firmware/efi/efivars ] && umount -l -n /sys/firmware/efi/efivars
    umount -l -n /sys
    umount -l -n /proc

    exit 0
}

err_reboot() {

    echo "\nInstallation aborted - unable to continue (type exit or CTRL-D to reboot)"
    debugsh || true
    real_reboot
}

echo "Starting Proxmox installation"

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin

# ensure udev isn't snippy and ignores our request
export SYSTEMD_IGNORE_CHROOT=1

mount -n -t proc proc /proc
mount -n -t sysfs sysfs /sys
if [ -d /sys/firmware/efi/efivars ]; then
    echo "EFI boot mode detected, mounting efivars filesystem"
    mount -n -t efivarfs efivarfs /sys/firmware/efi/efivars
fi
mount -n -t tmpfs tmpfs /run

parse_cmdline

# always load most common input drivers
modprobe -q psmouse || /bin/true
modprobe -q sermouse || /bin/true
modprobe -q usbhid || /bin/true

# load device mapper - used by lilo
modprobe -q dm_mod || /bin/true

echo "Installing additional hardware drivers"
export RUNLEVEL=S 
export PREVLEVEL=N
/etc/init.d/udev start

mkdir -p /dev/shm
mount -t tmpfs tmpfs /dev/shm

# allow pseudo terminals for debuggin in X
mkdir -p /dev/pts
mount -vt devpts devpts /dev/pts -o gid=5,mode=620

if [ $proxdebug -ne 0 ]; then
    /sbin/agetty -o '-p -- \\u' --noclear tty9 &
    echo "Dropping in debug shell inside chroot before starting installation"
    echo "type exit or CTRL-D to start installation wizard"
    debugsh || true
fi

# set the hostname 
hostname proxmox

echo "Starting a root shell on tty3."
setsid /sbin/agetty -a root --noclear tty3 &

xinit -- -dpi 96 >/dev/tty2 2>&1

# just to be sure everything is on disk
sync

if [ $proxdebug -ne 0 ]; then 
    echo "Debugging mode (type exit or CTRL-D to reboot)"
    debugsh || true
fi

echo "Installation done, rebooting... "
#mdadm -S /dev/md0 >/dev/tty2 2>&1
real_reboot

# never reached
exit 0
