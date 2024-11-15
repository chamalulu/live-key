#!/bin/sh

set -eu

printUsage () {
	echo "
Usage: $0 <ISO IMAGE> <USB DEVICE>
Write the iso image to the usb device preserving third and fourth partitions.

Some preconditions.
The third partition on the usb device contains a LUKS encrypted filesystem.
The fourth partition on the usb device contains a filesystem.

The third partition will be backed up and preserved on the device (, but never
 unlocked). If necessary, because of bigger ISO IMAGE, the third partition is
 moved.
The contents of the fourth partition will be backed up and preserved on the
 device. If the third partition is moved the fourth partition may be shrunk.
After a successful update the device should have four partitions in an MBR
 partition table.
The first and second maps into the ISO IMAGE for BIOS and EFI boot purposes.
The end of the third partition and the start of the fourth partition are aligned
 with the first free GiB after the ISO IMAGE.
"
}

if [ $# -ne 2 ]; then
	echo 'Unexpected number of parameters.'
	printUsage
	exit 1
fi

ISO_IMAGE=$1
USB_DEVICE=`realpath $2`

if [ $USB_DEVICE != $2 ]; then
	echo "Real path of $2 is $USB_DEVICE ."
fi

PT_JSON=`sudo sfdisk -J $USB_DEVICE | jq '.partitiontable'`
SECTOR_SIZE=`echo $PT_JSON | jq '.sectorsize'`

getPart () {
	echo $PT_JSON | jq ".partitions[]|select(.node == \"$1\")"
}

getStart () {
	getPart $1 | jq '.start'
}

getSize () {
	getPart $1 | jq '.size'
}

PST_PART=`echo $PT_JSON | jq -r '.partitions[2].node'`
P4_PART=`echo $PT_JSON | jq -r '.partitions[3].node'`

PST_START=`getStart $PST_PART`
PST_SIZE=`getSize $PST_PART`
P4_START=`getStart $P4_PART`

if [ -z "$PST_START" -o -z "$PST_SIZE" -o -z "$P4_START" ]; then
	echo "Unexpected number of partitions on $USB_DEVICE ."
	printUsage
	exit 1
fi

# Backup PST
PST_BACKUP=`mktemp pst_XXX.backup`
echo "Backing up encrypted persistence partition to $PST_BACKUP ..."
sudo dd if=$PST_PART of=$PST_BACKUP bs=1M oflag=sync status=progress

# Backup contents of P4
P4_BACKUP=`mktemp p4_XXX.tar.gz`
echo "Backing up contents of fourth partition to $P4_BACKUP ..."
sudo mount -r $P4_PART /mnt
sudo tar -caf $P4_BACKUP -C /mnt .
sudo umount /mnt
P4_LABEL=`sudo e2label $P4_PART`

# Get size of iso image in sectors rounded up to next MiB.
SECTORS_PER_MIB=$((1048576 / $SECTOR_SIZE))
ISO_SIZE=$((((`stat -c %s $ISO_IMAGE` - 1) / 1048576 + 1) * $SECTORS_PER_MIB))

if [ $ISO_SIZE -gt $PST_START ]; then
	echo 'Size of iso image is greater than start of encrypted persistence partition.'
	echo 'Encrypted persistence partition will be moved and fourth partition may be shrunk.'
	# Align P4 at first free GiB after ISO and PST
	SECTORS_PER_GIB=$(($SECTORS_PER_MIB * 1024))
	NEW_P4_START=$(((($ISO_SIZE + $PST_SIZE - 1) / $SECTORS_PER_GIB + 1) * $SECTORS_PER_GIB))
	# Position PST just before P4
	NEW_PST_START=$(($NEW_P4_START - $PST_SIZE))
fi

# Write ISO to USB device
echo "Writing $ISO_IMAGE to $USB_DEVICE ..."
sudo dd if=$ISO_IMAGE of=$USB_DEVICE bs=1M oflag=sync status=progress

# Sanity check
PT_JSON=`sudo sfdisk -J $USB_DEVICE | jq '.partitiontable'`
if [ `echo $PT_JSON | jq '.partitions|length'` -ne 2 ]; then
	echo "Unexpected number of partitions on $USB_DEVICE after writing $ISO_IMAGE."
	exit 1
fi

# Setup PST and P4 partitions
echo 'Writing third and fourth partition table entries...'
echo "
${NEW_PST_START:-$PST_START},$PST_SIZE
${NEW_P4_START:-$P4_START}
" | sudo sfdisk -a $USB_DEVICE

if [ ${NEW_PST_START:-$PST_START} != $PST_START ]; then
	# Restore PST
	echo 'Encrypted persistence partition was moved. Restoring from backup...'
	sudo dd if=$PST_BACKUP of=$PST_PART bs=1M oflag=sync status=progress
else
	# Checksum PST
	echo 'Comparing checksum of backup and encrypted persistence partition...'
	BUP_CS=`cksum $PST_BACKUP | cut -d ' ' -f -2`
	PST_CS=`sudo cksum $PST_PART | cut -d ' ' -f -2`
	if [ "$BUP_CS" != "$PST_CS" ]; then
		echo "Bad checksum of $PST_PART . Meh."
		exit 1
	fi
fi

echo 'Removing backup of encrypted persistence partition...'
sudo rm $PST_BACKUP

if [ ${NEW_P4_START:-$P4_START} != $P4_START ]; then
	# Restore P4
	echo 'Fourth partition was shrunk. Restoring contents from backup...'
	sudo mkfs.ext4 -L $P4_LABEL $P4_PART
	sudo mount $P4_PART /mnt
	sudo tar -xf $P4_BACKUP -C /mnt
	sudo umount /mnt
else
	# Diff with archive
	echo 'Diffing backup archive with contents of fourth partition...'
	sudo mount -r $P4_PART /mnt
	sudo tar -df $P4_BACKUP -C /mnt
	sudo umount /mnt
fi

echo 'Removing backup archive of contents of fourth partition...'
sudo rm $P4_BACKUP

echo 'Enjoy.'
