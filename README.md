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
files for setting up SiliconGraphics and ThinkPad keyboards.

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

## Things to implement in live-key project

### /home on encrypted filesystem image

This requires package cryptsetup on both build host and live system.

Add `persistence persistence-encryption=luks` to boot parameters.

Also add `persistence-media=removable-usb persistence-storage=file` to boot
parameters to make live-boot only consider filesystem image `persistence` on
binary image filesystem.


