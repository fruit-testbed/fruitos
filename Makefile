.PHONY: build build.gz rootfs clean clean.rootfs clean.losetup

IMAGE ?= fruitos.img
TEMPLATE ?= template.img.gz
APKS ?= $(shell pwd)/apks/target/packages  # absolute path please!
MACHINE ?= rpi2
ARCH ?= armhf

ALPINE_VERSION ?= 3.7
ALPINE_REPO = http://dl-cdn.alpinelinux.org/alpine/v$(ALPINE_VERSION)
ALPINE_MAIN = $(ALPINE_REPO)/main
ALPINE_COMMUNITY = $(ALPINE_REPO)/community


ifeq ($(MACHINE),raspberrypi)
	MACHINE := rpi
else ifeq ($(MACHINE),raspberrypi2)
	MACHINE := rpi2
endif

PACKAGES = \
	fruit-$(MACHINE)-linux \
	rpi-firmware \
	fruit-rpi-bootloader \
	fruit-u-boot \
	fruit-initramfs \
	fruit-baselayout \
	fruit-keys \
	fruit-agent \
	alpine-conf \
	alpine-keys \
	apk-tools \
	busybox \
	busybox-initscripts \
	busybox-suid \
	libc-utils \
	openrc \
	mkinitfs \
	openssh \
	openssh-server \
	tzdata \
	kbd-bkeymaps \
	btrfs-progs \
	nfs-utils \
	curl \
	parted \
	tlsdate \
	wireless-tools \
	wpa_supplicant \
	dnsmasq \
	docker \
	singularity \

SERVICES = devfs.sysinit dmesg.sysinit mdev.sysinit hwdrivers.sysinit \
	hwclock.boot modules.boot sysctl.boot hostname.boot bootmisc.boot syslog.boot networking.boot tlsdate.boot \
	sshd.default ntpd.default crond.default tlsdated.default local.default \
	mount-ro.shutdown killprocs.shutdown savecache.shutdown \


build: build.image $(IMAGE).gz $(IMAGE).gz.sha256
	@rm -f $(IMAGE)
	@echo "Finished"

build.image: .apks rootfs clean.rootfs clean.losetup

.apks:
	cd apks && make
	touch .apks

%.sha256: $*
	@echo "Generating $*.sha256..."
	@sha256sum $* > $*.sha256

$(IMAGE).gz: $(IMAGE)
	@echo "Compressing $(IMAGE) to $(IMAGE).gz..."
	@if [ -f /usr/bin/pigz ]; then \
		pigz -c $(IMAGE) > $(IMAGE).gz; \
	else \
		gzip -c $(IMAGE) > $(IMAGE).gz; \
	fi

$(IMAGE):
	@echo "Copying $(TEMPLATE) to $(IMAGE)..."
	@zcat $(TEMPLATE) > $(IMAGE)

# <image-file>,<partition-number>,<loop-device>.losetup
# e.g. disk.img,1,loop3.losetup
%.losetup:
	@apk add util-linux 1>/dev/null
	@image=$(shell echo $* | cut -d',' -f1); \
		partnum=$(shell echo $* | cut -d',' -f2); \
		loop=$(shell echo $* | cut -d',' -f3); \
		echo "Attaching $${image}$${partnum} to /dev/$${loop}..."; \
		losetup -o $$(( $$( fdisk -l $${image} | grep $${image}$${partnum} | awk '{print $$2}' ) * 512 )) /dev/$${loop} $${image}

# <root-device>-<boot-device>.mount
# e.g. loop4-loop3.mount
%.mount:
	@echo "Mounting root & boot devices onto $*..."
	mkdir -p $*
	mount /dev/$(shell echo $* | cut -d'-' -f1) $*
	mkdir -p $*/media/mmcblk0p1
	mount /dev/$(shell echo $* | cut -d'-' -f2) $*/media/mmcblk0p1
	mkdir -p $*/dev $*/proc $*/sys
	mount -o bind /proc $*/proc
	mount -o bind /dev $*/dev
	mount -o bind /sys $*/sys

# <root-device>-<boot-device>.rootfs
# e.g. loop4-loop3.rootfs
%.rootfs:
	@echo "Installing root filesystem onto $*..."
	apk -X $(APKS) -X $(ALPINE_MAIN) -X $(ALPINE_COMMUNITY) -U --allow-untrusted --root $* --initdb add $(PACKAGES)
	@for svc in $(SERVICES); do \
		name=$$(echo $$svc | cut -d'.' -f1); \
		level=$$(echo $$svc | cut -d'.' -f2); \
		chroot $* /sbin/rc-update add $$name $$level; \
	done
	@if [ "$$(grep ttyS0 $*/etc/securetty)" = "" ]; then \
		echo "ttyS0" >> $*/etc/securetty; \
	fi
	@echo "BUILT_TIMESTAMP=$$(date +%s)" >> $*/etc/os-release

%.initramfs:
	@echo "Generating U-Boot initramfs..."
	@chroot $* mkinitfs -o /boot/initramfs-$(MACHINE) \
		$$(cat $*/usr/share/kernel/$(MACHINE)/kernel.release)
	@chroot $* mkimage -A arm -T ramdisk -C none -n initramfs \
		-d /boot/initramfs-$(MACHINE) /boot/initramfs
	@rm -f $*/boot/initramfs-$(MACHINE)

%.devicetree:
	@echo "Copying Device Tree files to /media/mmcblk0p1..."
	@cp -r $*/usr/lib/linux-$$(cat $*/usr/share/kernel/$(MACHINE)/kernel.release)/* \
		$*/media/mmcblk0p1/

%.clone:
	@src=/dev/$(shell echo $* | cut -d'-' -f1); \
		dest=/dev/$(shell echo $* | cut -d'-' -f2); \
		echo "Cloning $$src to $$dest..."; \
		result=false; \
		mount -o remount,ro $$src && dd if=$$src of=$$dest && result=true; \
		mount -o remount,rw /dev/$(shell echo $* | cut -d'-' -f1); \
		${result}

rootfs: $(IMAGE) \
	$(IMAGE),1,loop3.losetup \
	$(IMAGE),2,loop4.losetup \
	loop4-loop3.mount \
	loop4-loop3.rootfs \
	loop4-loop3.initramfs \
	loop4-loop3.devicetree \
	$(IMAGE),3,loop5.losetup \
	loop4-loop5.clone \

cleanall: clean clean.apks

clean: clean.rootfs clean.losetup clean.checksum
	@rm -f $(IMAGE) $(IMAGE).gz

clean.checksum:
	@rm -f $(IMAGE).sha256 $(IMAGE).sha512 $(IMAGE).gz.sha256 $(IMAGE).gz.sha512

clean.apks:
	cd apks && make cleanall cleancache
	rm -f .apks

clean.rootfs: loop4-loop3.umount

clean.losetup: clean.3.losetup clean.4.losetup clean.5.losetup

%.umount:
	@echo "Unmounting $*..."
	@umount -f $*/dev 1>/dev/null 2>/dev/null || true
	@umount -f $*/sys 1>/dev/null 2>/dev/null || true
	@umount -f $*/proc 1>/dev/null 2>/dev/null || true
	@if [ "$$(mount | grep '$*/media/mmcblk0p1 ')" != "" ]; then umount -f $*/media/mmcblk0p1; fi
	@if [ "$$(mount | grep '$* ')" != "" ]; then umount -f $*; fi
	@if [ -d $* ]; then rmdir $*; fi

clean.%.losetup:
	@echo "Detaching /dev/loop$*..."
	@[ "$$(losetup -a | grep '/dev/loop' | grep '$*:')" != "" ] && losetup -d /dev/loop$* || true
