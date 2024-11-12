AUTO_CONFIG := auto/config
CONFIG_SENTINEL := config/.sentinel
ISO_IMAGE := live-image-amd64.hybrid.iso
PERSISTENCE := persistence

# target: help - Display callable targets
help:
	@grep -E "^# target:" Makefile

# target: clean - Clean
clean:
	rm -f $(CONFIG_SENTINEL)
	sudo lb clean

$(CONFIG_SENTINEL): $(AUTO_CONFIG)
	# Always clean before config
	rm -f $(CONFIG_SENTINEL)
	sudo lb clean
	lb config
	touch $(CONFIG_SENTINEL)

# target: config - Repopulate config directory (from auto/config)
config: $(CONFIG_SENTINEL)

$(ISO_IMAGE): $(CONFIG_SENTINEL)
	sudo lb build
	# Update timestamp of image
	sudo touch $(ISO_IMAGE)

# target: build - Build the image
build: $(ISO_IMAGE)

# target: test - Boot image in virtual machine
test: $(ISO_IMAGE)
	kvm -m 4G -cdrom $(ISO_IMAGE)

$(PERSISTENCE):
	./create_persistence.sh $(PERSISTENCE)

# target: ptest - Boot image in virtual machine with attached encrypted persistence
ptest: $(ISO_IMAGE) $(PERSISTENCE)
	kvm -m 4G -usb \
	-cdrom $(ISO_IMAGE) \
	-blockdev driver=file,node-name=persistencedrive,filename=$(PERSISTENCE) \
	-device usb-storage,drive=persistencedrive,removable=true

.PHONY: help clean config build test ptest
