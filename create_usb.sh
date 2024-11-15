#!/bin/sh

set -eu

printUsage () {
	echo "
Usage: $0 <ISO IMAGE> <USB DEVICE>
Write the iso image to the usb device and create third and fourth partitions.

After a successful creation the device should have four partitions in an MBR
 partition table.
The first and second maps into the ISO IMAGE for BIOS and EFI boot purposes.
The end of the third partition and the start of the fourth partition are aligned
 with the first free GiB after the ISO IMAGE.

Some postconditions.
The third partition on the usb device contains a LUKS encrypted filesystem which
live-boot will mount on /home.
The fourth partition on the usb device contains a filesystem which live-boot
will mount on /mnt/transfer.
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

# Write ISO to USB device
echo "Writing $ISO_IMAGE to $USB_DEVICE ..."
sudo dd if=$ISO_IMAGE of=$USB_DEVICE bs=1M oflag=sync status=progress

# Sanity check
PT_JSON=`sudo sfdisk -J $USB_DEVICE | jq '.partitiontable'`
if [ `echo $PT_JSON | jq '.partitions|length'` -ne 2 ]; then
	echo "Unexpected number of partitions on $USB_DEVICE after writing $ISO_IMAGE."
	exit 1
fi

SECTOR_SIZE=`echo $PT_JSON | jq '.sectorsize'`

# Get size of iso image in sectors rounded up to next MiB.
SECTORS_PER_MIB=$((1048576 / $SECTOR_SIZE))
ISO_SIZE=$((((`stat -c %s $ISO_IMAGE` - 1) / 1048576 + 1) * $SECTORS_PER_MIB))
PST_SIZE=$((128 * $SECTORS_PER_MIB))

# Align P4 at first free GiB after ISO and PST
SECTORS_PER_GIB=$(($SECTORS_PER_MIB * 1024))
P4_START=$(((($ISO_SIZE + $PST_SIZE - 1) / $SECTORS_PER_GIB + 1) * $SECTORS_PER_GIB))
# Position PST just before P4
PST_START=$(($P4_START - $PST_SIZE))

# Setup PST and P4 partitions
echo 'Writing third and fourth partition table entries...'
echo "
$PST_START,$PST_SIZE
$P4_START
" | sudo sfdisk -a $USB_DEVICE

# Reread partition table
PT_JSON=`sudo sfdisk -J $USB_DEVICE | jq '.partitiontable'`
PST_PART=`echo $PT_JSON | jq -r '.partitions[2].node'`
P4_PART=`echo $PT_JSON | jq -r '.partitions[3].node'`

# Create PST
echo "Setting up LUKS container on $PST_PART ..."
sudo cryptsetup -q luksFormat $PST_PART

DEVNAME=`mktemp -u persistence_XXX`

echo "Opening $PST_PART and mapping to /dev/mapper/$DEVNAME ..."
sudo cryptsetup luksOpen $PST_PART $DEVNAME

echo 'Creating ext4 filesystem ...'
sudo mkfs.ext4 -L persistence /dev/mapper/$DEVNAME

echo 'Mounting filesystem on /mnt ...'
sudo mount /dev/mapper/$DEVNAME /mnt

echo "Creating /mnt/persistence.conf ..."
sudo sh -c 'echo /home > /mnt/persistence.conf'

echo 'Unmounting filesystem ...'
sudo umount /mnt

echo "Unmapping /dev/mapper/$DEVNAME and closing $PST_PART ..."
sudo cryptsetup luksClose $DEVNAME

# Create P4
echo 'Creating transfer partition...'
sudo mkfs.ext4 -L persistence $P4_PART
sudo mount $P4_PART /mnt
sudo sh -c "echo '/mnt/transfer source=.' > /mnt/persistence.conf"
sudo umount /mnt

echo 'Enjoy.'
