#!/bin/sh

PERSISTENCE=$1

# Read password
#echo "To setup a new $PERSISTENCE image You need to provide a password."
#echo -n "New password: "
#STTY_ORIG=`stty -g`
#stty -echo
#IFS= read -r PASSWORD
#stty "$STTY_ORIG"

# Create a 128MiB image for persistence.
dd if=/dev/null of=$PERSISTENCE bs=1 count=0 seek=128M

# Setup and open LUKS encryption on persistence.
sudo cryptsetup -y luksFormat $PERSISTENCE
sudo cryptsetup luksOpen $PERSISTENCE persistence

# Create and mount filesystem
sudo mkfs.ext4 -L persistence /dev/mapper/persistence
sudo mount /dev/mapper/persistence /mnt

# Create persistence.conf
sudo sh -c "echo \"/home\" > /mnt/persistence.conf"

# Unmount filesystem and close LUKS container
sudo umount /mnt
sudo cryptsetup luksClose persistence

