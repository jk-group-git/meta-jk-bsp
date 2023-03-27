#!/bin/bash

shopt -s nullglob

IDENTIFIER="systemupdate script"
ROOTFS_NAME="rootfs-pl161.tar.gz"
ROOTFS_SHA="rootfs-pl161.tar.gz.sgn"
UBOOT_NAME="u-boot.bin"
KERNEL_NAME="uImage"
DTB_NAME="dtb"
PENV_NAME="penv"
UBOOT_SHA="u-boot.bin.sgn"
KERNEL_SHA="uImage.sgn"
DTB_SHA="dtb.sgn"
PENV_SHA="penv.sgn"

publickey=""

KEYS=("/usr/share/keys/update/*")

TTYNO=2
TTY="/dev/tty$TTYNO"

usage="$(basename "$0") [-d dir] pulls updates from dir and tries to install them

where:
    -d  the directory where the updates reside"

while getopts "d:" opt; do
	case $opt in
		d)
			mountpath_usb="${OPTARG}"
			;;
		:)
			echo $usage
			exit 1
			;;
		\?)
			echo $usage
			exit 1
			;;
		*)
			echo $usage
			exit 1
			;;
	esac
done

if [ x"${mountpath_usb}" = x ]; then
	echo $usage
	exit 1
fi

if [ ! -d "${mountpath_usb}" ]; then
	echo $usage
	exit 1
fi

function cleanup {
	echo "Cleaning up." >> $TTY
	umount -l /boot
	umount -l "${future_root_node}"
	umount -l "${mountpath_usb}"
	echo "Unmounted all used mountpoints." >> $TTY
	echo -n "Syncing..." >> $TTY
	echo "Synced." >> $TTY
}

function handle_error {
	cleanup
	echo "There was an error installing the update. Please reset the device." >> $TTY
	exit 1
}

function determine_root {
	readonly current_root_partuuid=`findmnt -n --raw --evaluate --output=PARTUUID /`
	readonly current_root_node=`findmnt -n --raw --evaluate --output=source PARTUUID=$current_root_partuuid`
	echo -n "Searching partition to install..." >> $TTY
	case $current_root_partuuid in
		0cc66cc0-02)
			readonly future_root_node=`realpath /dev/disk/by-partuuid/0cc66cc0-03`
			;;
		0cc66cc0-03)
			readonly future_root_node=`realpath /dev/disk/by-partuuid/0cc66cc0-02`
			;;
		*)
			echo We are running from eMMC with strange UUID. Aborting in confusion. >> $TTY
			echo We are running from eMMC with strange UUID. Aborting in confusion. | systemd-cat -t $IDENTIFIER
			handle_error
			;;
	esac
	echo "ok." >> $TTY
}

function find_update {
	test -f "$1" && test -s "$1"
}

function check_update {
	u="${1}"
	s="${2}"
	k="${3}"
	openssl dgst -sha256 -verify "${k}" -signature "${s}" "${u}"
	if  [ $? -eq 0 ]; then
		echo "$u" verified with key "${k}" | systemd-cat -t $IDENTIFIER
		return 0
	else
		echo "$u" did not verify with key "${k}" | systemd-cat -t $IDENTIFIER
		return 255
	fi
}

function check_updates {
	if [ ${#KEYS[*]} -eq 0 ]; then
		return 255;
	fi
	ret=255;
	echo -n "checking updates..." >> $TTY
	for key in ${KEYS[*]}; do
		if test -n "${rootfs}" && test -n "${rootfs_signature}"; then
			check_update "${rootfs}" "${rootfs_signature}" "${key}"
			if [ $? -ne 0 ]; then
				continue;
			fi
		fi
		if test -n "${penv}" && test -n "${penv_signature}"; then
			check_update "${penv}" "${penv_signature}" "${key}"
			if [ $? -ne 0 ]; then
				continue;
			fi
		fi
		if test -n "${kernel}" && test -n "${kernel_signature}"; then
			check_update "${kernel}" "${kernel_signature}" "${key}"
			if [ $? -ne 0 ]; then
				continue;
			fi
		fi
		if test -n "${dtb}" && test -n "${dtb_signature}"; then
			check_update "${dtb}" "${dtb_signature}" "${key}"
			if [ $? -ne 0 ]; then
				continue;
			fi
		fi
		if test -n "${uboot}" && test -n "${uboot_signature}"; then
			check_update "${uboot}" "${uboot_signature}" "${key}"
			if [ $? -ne 0 ]; then
				continue;
			fi
		fi
		ret=0
		publickey=$key
		break;
	done
	if [ $ret -eq 0 ]; then
		echo "ok." >> $TTY
		echo update set verified with key "${k}" | systemd-cat -t $IDENTIFIER
		return 0
	else
		echo "fail." >> $TTY
		echo update set did not verify | systemd-cat -t $IDENTIFIER
		return 255
	fi
}

function find_updates {
	echo -n "Searching Updates..." >> $TTY
	if find_update "${mountpath_usb}"/$ROOTFS_SHA; then
		readonly rootfs_signature="${mountpath_usb}"/$ROOTFS_SHA
	fi
	if find_update "${mountpath_usb}"/$ROOTFS_NAME; then
		readonly rootfs="${mountpath_usb}"/$ROOTFS_NAME
	fi
	if find_update "${mountpath_usb}"/$PENV_NAME; then
		readonly penv="${mountpath_usb}"/$PENV_NAME
	fi
	if find_update "${mountpath_usb}"/$KERNEL_NAME; then
		readonly kernel="${mountpath_usb}"/$KERNEL_NAME
	fi
	if find_update "${mountpath_usb}"/$DTB_NAME; then
		readonly dtb="${mountpath_usb}"/$DTB_NAME
	fi
	if find_update "${mountpath_usb}"/$PENV_SHA; then
		readonly penv_signature="${mountpath_usb}"/$PENV_SHA
	fi
	if find_update "${mountpath_usb}"/$KERNEL_SHA; then
		readonly kernel_signature="${mountpath_usb}"/$KERNEL_SHA
	fi
	if find_update "${mountpath_usb}"/$DTB_SHA; then
		readonly dtb_signature="${mountpath_usb}"/$DTB_SHA
	fi
	if find_update "${mountpath_usb}"/$UBOOT_SHA; then
		readonly uboot_signature="${mountpath_usb}"/$UBOOT_SHA
	fi
	if find_update "${mountpath_usb}"/$UBOOT_NAME; then
		readonly uboot="${mountpath_usb}"/$UBOOT_NAME
	fi

	echo "ok." >> $TTY
}

function prepare_future_root {
	echo -n "Formatting new rootpartition..." >> $TTY
	if [ -b "${future_root_node}" ]; then
		mkfs.ext4 "${future_root_node}"
		if [ $? -ne 0 ];then
			echo Failed to create Ext4 Filesystem on "${future_root_node}". | systemd-cat -t $IDENTIFIER
			echo Failed to create Ext4 Filesystem on "${future_root_node}". >> $TTY
			handle_error
		else
			echo "ok." >> $TTY
		fi
	else
		echo Failed to create Ext4 Filesystem on "${future_root_node}". Not a block device. | systemd-cat -t $IDENTIFIER
		echo Failed to create Ext4 Filesystem on "${future_root_node}". Not a block device. >> $TTY
		handle_error
	fi
}

function mount_future_root {
	echo -n "mounting new root..." >> $TTY
	if [ -b "${future_root_node}" ];then
		readonly mountpath_future_root=`mktemp -d`
		mount "${future_root_node}" "${mountpath_future_root}"
		if [ $? -ne 0 ];then
			echo Failed to mount "${future_root_node}" on "${mountpath_future_root}". | systemd-cat -t $IDENTIFIER
			echo Failed to mount "${future_root_node}" on "${mountpath_future_root}". >> $TTY
			handle_error
		else
			echo "ok." >> $TTY
		fi
	else
		echo Failed to mount "${future_root_node}" on "${mountpath_future_root}". Not a block device. | systemd-cat -t $IDENTIFIER
		echo Failed to mount "${future_root_node}" on "${mountpath_future_root}". Not a block device.  >> $TTY
		handle_error
	fi
}

function untar_update {
	echo "Installing files..." >> $TTY
	if [ -d ]; then
		tar -xamf "${rootfs}" -C "${mountpath_future_root}" >> $TTY
		if [ $? -ne 0 ]; then
			echo Failed to untar "${rootfs}" into "${mountpath_future_root}". | systemd-cat -t $IDENTIFIER
			echo Failed to untar "${rootfs}" into "${mountpath_future_root}". >> $TTY
			handle_error
		fi
	else
		echo Failed to untar "${rootfs}" into "${mountpath_future_root}". Not a directory. | systemd-cat -t $IDENTIFIER
		echo Failed to untar "${rootfs}" into "${mountpath_future_root}". Not a directory. >> $TTY
		handle_error
	fi
	echo "Files installed" >> $TTY
}

function copy_bootfile {
	mount `realpath /dev/disk/by-partuuid/0cc66cc0-01` /boot/
	pushd /boot
	cp "$1" .
	while !(openssl dgst -sha256 -verify $publickey -signature "$2" "$1") do
		echo "Error writing. retrying..." >> $TTY
		cp "$1" .
	done
	popd
}

function update_commandline {
	echo -n "Changing bootloader environment..." >> $TTY
	if [ -b `realpath /dev/disk/by-partuuid/0cc66cc0-01` ]; then
		mount `realpath /dev/disk/by-partuuid/0cc66cc0-01` /boot/
		if [ $? -ne 0 ];then
			echo "Failed to mount `realpath /dev/disk/by-partuuid/0cc66cc0-01` on /boot/." | systemd-cat -t $IDENTIFIER
			echo "Failed to mount `realpath /dev/disk/by-partuuid/0cc66cc0-01` on /boot/." >> $TTY
			handle_error
		else
			echo "ok." >> $TTY
		fi
	else
		echo "Failed to mount `realpath /dev/disk/by-partuuid/0cc66cc0-01` on /boot/. Not a blockdevice." | systemd-cat -t $IDENTIFIER
		echo "Failed to mount `realpath /dev/disk/by-partuuid/0cc66cc0-01` on /boot/. Not a blockdevice." >> $TTY
		handle_error
	fi
	echo "update_pending=1" > /boot/env
}

function restart_system {
	echo "Update procedure ended. Please remove the update medium and reset the device!" >> $TTY
	exit 0
}

function copy_dtb {
	if test -n "${dtb}" && test -n "$dtb_signature"; then
		pushd "${mountpath_usb}"
		echo -n "copying devicetree..." >> $TTY
		copy_bootfile "${dtb}" "$dtb_signature"
		echo "ok." >> $TTY
		popd
	fi
}

function copy_kernel {
	if test -n "${kernel}" && test -n "$kernel_signature"; then
		pushd "${mountpath_usb}"
		echo -n "copying kernel..." >> $TTY
		copy_bootfile "${kernel}" "$kernel_signature"
		echo "ok." >> $TTY
		popd
	fi
}

function copy_penv {
	if test -n "${penv}" && test -n "$penv_signature"; then
		pushd "${mountpath_usb}"
		echo -n "copying u-boot environment..." >> $TTY
		copy_bootfile "${penv}" "$penv_signature"
		echo "ok." >> $TTY
		popd
	fi
}

function copy_uboot {
	if test -n "${uboot}" && test -n "$uboot_signature"; then
		pushd "${mountpath_usb}"
		echo -n "copying u-boot..." >> $TTY
		copy_bootfile "${uboot}" "$uboot_signature"
		echo "ok." >>$TTY
		popd
	fi
}

function update_rootfs {
	if test -n "${rootfs}" && test -n "$rootfs_signature"; then
		pushd "${mountpath_usb}"
		determine_root
		prepare_future_root
		mount_future_root
		untar_update
		update_commandline
		popd
	fi
}

function remove_lcdenv {

	mount `realpath /dev/disk/by-partuuid/0cc66cc0-01` /boot/
	if test -f "/boot/lcdenv"; then
		rm "/boot/lcdenv"
	fi
}

{
	find_updates
	check_updates
	if [ $? -eq 0 ]; then
		update_rootfs
		copy_uboot
		copy_penv
		copy_kernel
		copy_dtb
		remove_lcdenv
	fi
	cleanup
	restart_system
}>/dev/null 2>/dev/null
