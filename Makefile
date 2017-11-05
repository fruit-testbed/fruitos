.PHONY: build build.img rootfs clean clean.rootfs clean.losetup

IMAGE ?= disk.img
TEMPLATE ?= template.img.gz
APKS ?= /data/apks/target/packages
MACHINE ?= rpi2
ARCH ?= armhf


PACKAGES = \
	rpi-firmware \
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
	wireless-tools \
	wpa_supplicant \
	dnsmasq \
	docker \
	singularity \

ifeq ($(MACHINE),raspberrypi)
	MACHINE := rpi
else ifeq ($(MACHINE),raspberrypi2)
	MACHINE := rpi2
endif

PACKAGES += $(MACHINE)-boot-linux

SERVICES = devfs.sysinit dmesg.sysinit mdev.sysinit hwdrivers.sysinit \
	hwclock.boot modules.boot sysctl.boot hostname.boot bootmisc.boot syslog.boot networking.boot \
	sshd.default ntpd.default crond.default local.default \
	mount-ro.shutdown killprocs.shutdown savecache.shutdown \


build: rootfs clean.rootfs clean.losetup

build.gz: build
	@echo "Compressing $(IMAGE) to $(IMAGE).gz..."
	@gzip -c $(IMAGE) > $(IMAGE).gz
	@rm -f $(IMAGE)

$(IMAGE):
	@echo "Copying $(TEMPLATE) to $(IMAGE)..."
	@zcat $(TEMPLATE) > $(IMAGE)

# <image-file>:<partition-number>:<loop-device>:losetup
# e.g. disk.img:1:loop3:losetup
%.losetup:
	@apk add util-linux 1>/dev/null
	@image=$(shell echo $* | cut -d',' -f1); \
		partnum=$(shell echo $* | cut -d',' -f2); \
		loop=$(shell echo $* | cut -d',' -f3); \
		echo "Attaching $${image}$${partnum} to /dev/$${loop}..."; \
		losetup -o $$(( $$( fdisk -l $${image} | grep $${image}$${partnum} | awk '{print $$2}' ) * 512 )) /dev/$${loop} $${image}

# <root-device>.<boot-device>.mount
# e.g. loop4.loop3.mount
%.mount:
	@echo "Mounting root & boot devices onto $*..."
	mkdir -p $*
	mount /dev/$(shell echo $* | cut -d'-' -f1) $*
	mkdir -p $*/boot
	mount /dev/$(shell echo $* | cut -d'-' -f2) $*/boot
	mkdir -p $*/dev $*/proc $*/sys
	mount -o bind /proc $*/proc
	mount -o bind /dev $*/dev
	mount -o bind /sys $*/sys

# <root-device>.<boot-device>.rootfs
# e.g. loop4.loop3.rootfs
%.rootfs:
	@echo "Installing root filesystem onto $*..."
	@apk -X $(APKS) -U --allow-untrusted --root $* --initdb add $(PACKAGES)
	@for svc in $(SERVICES); do \
		name=$$(echo $$svc | cut -d'.' -f1); \
		level=$$(echo $$svc | cut -d'.' -f2); \
		chroot $* /sbin/rc-update add $$name $$level; \
	done
	@if [ "$$(grep ttyS0 $*/etc/securetty)" = "" ]; then \
		echo "ttyS0" >> $*/etc/securetty; \
	fi

rootfs: $(IMAGE) \
	$(IMAGE),1,loop3.losetup \
	$(IMAGE),2,loop4.losetup \
	loop4-loop3.mount \
	loop4-loop3.rootfs \
	loop4-loop3.boot \


uboot: boot.cmd
	@echo "Setting up U-Boot..."
	@apk add uboot-tools 1>/dev/null
	mkimage -C none -A arm -T script -d boot.cmd boot.scr


%.boot: initramfs-init cmdline.txt config.txt
	@echo "Setting up boot files..."
	@cp -f initramfs-init $*/usr/share/mkinitfs/initramfs-init
	@chroot $* /sbin/mkinitfs -o /boot/initramfs-$(MACHINE) \
		$$(cat $*/usr/share/kernel/$(MACHINE)/kernel.release)
	@cp -f cmdline.txt $*/boot/
	@cp -f config.txt $*/boot/
	@sed -i 's/<kernel>/vmlinuz-$(MACHINE)/' $*/boot/config.txt
	@sed -i 's/<initramfs>/initramfs-$(MACHINE)/' $*/boot/config.txt

clean: clean.rootfs clean.losetup
	@rm -f $(IMAGE) $(IMAGE).gz

clean.rootfs: loop4-loop3.umount

clean.losetup: clean.3.losetup clean.4.losetup

%.umount:
	@echo "Unmounting $*..."
	@umount -f $*/dev 1>/dev/null 2>/dev/null || true
	@umount -f $*/sys 1>/dev/null 2>/dev/null || true
	@umount -f $*/proc 1>/dev/null 2>/dev/null || true
	@if [ "$$(mount | grep '$*/boot ')" != "" ]; then umount -f $*/boot; fi
	@if [ "$$(mount | grep '$* ')" != "" ]; then umount -f $*; fi
	@if [ -d $* ]; then rmdir $*; fi

clean.%.losetup:
	@echo "Detaching /dev/loop$*..."
	@[ "$$(losetup -a | grep '/dev/loop' | grep '$*:')" != "" ] && losetup -d /dev/loop$* || true
