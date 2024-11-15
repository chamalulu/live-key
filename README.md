# Live-key

The goal of this project is to set up a live-system primarily to host my GPG
keys.

There are reasons for not having your primary (certifying) private key stored on
your every-day work machine. The canonical solution is to have another air-
gapped machine where you can sign keys transferred by 5¼" floppy disk.
I think a more practical (albeit less secure) way is to have a live system on an
USB stick without networking which you reboot into when you need to sign a key.

I'm sure this has been solved a thousand times before but I'm all for being the
1,001st guy inventing the wheel all over again.

The live system should be as vanilla as possible with a few modifications.

- Networking is disabled.
  (&#x26a0; Currently implemented in the lamest possible way.)
- `/home` is persisted on an encrypted writable filesystem on the medium and it
  must survive rebuilds of the live system. (&#x2705; Solved)
- A non-encrypted filesystem for transfers also reside on the medium. A rebuild
  of the live system should preserve its contents if space allows. It should be
  mounted under `/mnt/live-key/transfer` after boot. (&#x1f6a7; The mounting is
  not yet done.)
- Block devices on target host may of course also be mounted but this should not
  be done automatically.

## Modifications

### Keyboard layout files

Package console-setup is installed in live system and /etc/default contains
keyboard files for setting up my SiliconGraphics and ThinkPad keyboards.

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

The image of the encrypted filesystem can be created by the script
`create_persistence.sh` given the name of the image to create.

## Testing in virtual machine

The Makefile has two phony test targets, `test` and `ptest`.

`test` dependes on the iso image. It starts a VM with the iso image attached to
the cdrom drive.

`ptest` depends on the iso image and an image of an encrypted peristence block
device. It starts a VM with the iso image as in `test` and also the persistence
image attached as removable usb storage.

### Updating the USB drive

The Makefile has a phony target `update`. It depends on the iso image. It
executes `update_usb.sh` with the iso image and `myUSB` as parameters.

`myUSB` should be a symlink to the usb block device.

## TODOs

### `myUSB` target selection

A target for `myUSB` could be defined in the Makefile which prompts the user for
a target in `/dev/disk/by-id/` to set up the symlink to.

### Bootstrap script and target

The target `update` requires an existing Live-key environment on a USB drive.
Provide a script and target to create one from scratch.
