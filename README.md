# Live-key

The goal of this project is to set up a live-system primarily to host my GPG
signing key.

The live system should be as vanilla as possible with a few modifications.

- Network interfaces should be down by default. They can be manually set up
  from within the live system after boot.
- /home should reside on an encrypted filesystem image in the binary. It should
  survive rebuilds of the live system.
- If other filesystems exist on the medium, they are mounted under
  /mnt/live-key/<label> after boot.
- Other block devices (e.g. local disks) can be mounted under
  /mnt/target-host/ .

## Modifications

### Keyboard layout files

Package console-setup is installed in live system and /etc/default contains
keyboard files for setting up SiliconGraphics and ThinkPad keyboards.

```sh
# setupcon -k -v ThinkPad
```
or
```sh
# setupcon -k -v SiliconGraphics
```

### Bring down all network devices except loopback

To airgap the live system all network interfaces except loopback will be
brought down.
There are of course much more secure and/or robust ways to isolate a live
system but we'll start here.

live-config runs the component `9999-down-links` in late userspace boot.

```sh
#!/bin/sh

for LINK in `ls /sys/class/net/ | grep --invert-match lo`; do
    ip link set $LINK down
done
```

### /home on encrypted filesystem image

Package cryptsetup is installed in live system.

`persistence persistence-encryption=luks persistence-media=removable-usb` is
added to boot parameters to make live-boot only consider luks encrypted
filesystem on removable usb.

The image of the encrypted filesystem is created by the script
`create_persistence.sh` given the name of the image to create.

## Testing in virtual machine

The Makefile has two phony test targets, `test` and `ptest`.

`test` dependes on the iso image. It starts a VM with the iso image attached to the cdrom drive.

`ptest` depends on the iso image and an image of an encrypted peristence block device.
It starts a VM with the iso image as in `test` and also the persistence image attached as removable usb storage.

## Things to implement in live-key project

