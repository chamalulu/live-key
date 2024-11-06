ISO_IMAGE := live-image-amd64.hybrid.iso
CONFIG_SENTINEL := config/.sentinel
AUTO_CONFIG := auto/config

# target: help - Display callable targets
help:
	@grep -E "^# target:" Makefile

# target: clean - Clean
clean:
	sudo lb clean
	@rm -f $(CONFIG_SENTINEL)

$(CONFIG_SENTINEL): $(AUTO_CONFIG)
	# Always clean before config
	sudo lb clean
	@rm -f $(CONFIG_SENTINEL)
	lb config
	@touch $(CONFIG_SENTINEL)

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

.PHONY: help clean config build test
