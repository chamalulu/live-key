#!/bin/sh

set -eu

while [ $# -gt 0 ]; do
	case "$1" in
		'-c')
			CONF=$2; shift 2; continue;;
		'-s')
			SIZE=$2; shift 2; continue;;
		'--')
			shift; break;;
		*)
			break;;
	esac
done

CONF=${CONF:-/home}
SIZE=${SIZE:-128M}
FILE=${1:-./persistence}

if [ $# -gt 1 ]; then
	echo "Unexpected parameter '$2'.

Usage: $0 [-c CONF] [-s SIZE] [--] [FILE]
Create LUKS encrypted filesystem image for live system persistence.
  -c CONF  Set contents of /persistence.conf in filesystem. Default is '/home'.
  -s SIZE  Set image size. Same format as dd seek with bs=1. Default is 128M.
  FILE     File to write image to. Default is './persistence'."
	exit 1
fi

echo "I will create LUKS encrypted filesystem image in $FILE of size $SIZE.
It will contain a /persistence.conf file containing '$CONF'.
sudo will be used to gain root privileges required for device mapping and
mounting.
You'll be asked for the encryption passphrase twice; once for formatting the
LUKS container and once for opening it.
"

echo "Creating $FILE of size $SIZE ..."
dd if=/dev/null of=$FILE bs=1 count=0 seek=$SIZE conv=excl

echo "Formatting $FILE ..."
sudo cryptsetup -q luksFormat $FILE

DEVNAME=`mktemp -u persistence_XXX`

echo "Opening $FILE and mapping to /dev/mapper/$DEVNAME ..."
sudo cryptsetup luksOpen $FILE $DEVNAME

echo 'Creating ext4 filesystem ...'
sudo mkfs.ext4 -L persistence /dev/mapper/$DEVNAME

echo 'Mounting filesystem on /mnt ...'
sudo mount /dev/mapper/$DEVNAME /mnt

echo "Writing '$CONF' to /mnt/persistence.conf ..."
sudo sh -c "echo '$CONF' > /mnt/persistence.conf"

echo 'Unmounting filesystem ...'
sudo umount /mnt

echo "Unmapping /dev/mapper/$DEVNAME and closing $FILE ..."
sudo cryptsetup luksClose $DEVNAME

echo 'Enjoy.'
