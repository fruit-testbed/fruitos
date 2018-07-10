.PHONY: build build.gz rootfs clean clean.rootfs clean.losetup

IMAGE ?= fruitos.img
TEMPLATE ?= template.img.gz
APKS ?= $(shell pwd)/apks/target/packages  # absolute path please!
MACHINE ?= rpi
ARCH ?= $(shell apk --print-arch)
VERSION ?= 0.4.0

REPO_FILE = $(shell pwd)/repositories
APK = apk --repositories-file $(REPO_FILE) -U --allow-untrusted

ifeq ($(MACHINE),raspberrypi)
	MACHINE := rpi
else ifeq ($(MACHINE),raspberrypi2)
	MACHINE := rpi2
endif

PACKAGES = \
	fruit-$(MACHINE)-linux \
	rpi-firmware \
	rpi-devicetree \
	fruit-rpi-bootloader \
	fruit-u-boot \
	alpine-conf \
	alpine-keys \
	apk-repositories \
	apk-tools \
	avahi \
	avahi-tools \
	bind-tools \
	btrfs-progs \
	busybox \
	busybox-initscripts \
	busybox-suid \
	curl \
	dbus \
	dnsmasq \
	docker \
	fruit-agent \
	fruit-baselayout \
	fruit-keys \
	kbd-bkeymaps \
	libc-utils \
	openrc \
	openssh \
	openssh-server \
	openvpn \
	parted \
	python3 \
	tlsdate \
	tzdata \
	uboot-tools \
	wireless-tools \
	wpa_supplicant \

SERVICES = devfs.sysinit dmesg.sysinit mdev.sysinit hwdrivers.sysinit \
	hwclock.boot modules.boot sysctl.boot hostname.boot bootmisc.boot syslog.boot networking.boot tlsdate.boot \
	sshd.default ntpd.default crond.default tlsdated.default local.default \
	dbus.default avahi-daemon.default \
	mount-ro.shutdown killprocs.shutdown savecache.shutdown \


build: isclean build.image $(IMAGE).gz $(IMAGE).gz.sha512
	@echo "Finished"

build.image: .apks rootfs clean.rootfs clean.losetup

release:
	mkdir -p release
	IMAGE=release/fruitos-$(VERSION)-raspberrypi1.img MACHINE=rpi make
	IMAGE=release/fruitos-$(VERSION)-raspberrypi1.img MACHINE=rpi make clean
	IMAGE=release/fruitos-$(VERSION)-raspberrypi2.img MACHINE=rpi2 make
	IMAGE=release/fruitos-$(VERSION)-raspberrypi2.img MACHINE=rpi2 make clean
	cd release && ln fruitos-$(VERSION)-raspberrypi1.img.gz fruitos-$(VERSION)-raspberrypi0.img.gz
	cd release && ln fruitos-$(VERSION)-raspberrypi2.img.gz fruitos-$(VERSION)-raspberrypi3.img.gz
	cd release && sha512sum fruitos-$(VERSION)-raspberrypi0.img.gz > fruitos-$(VERSION)-raspberrypi0.img.gz.sha512
	cd release && sha512sum fruitos-$(VERSION)-raspberrypi1.img.gz > fruitos-$(VERSION)-raspberrypi1.img.gz.sha512
	cd release && sha512sum fruitos-$(VERSION)-raspberrypi2.img.gz > fruitos-$(VERSION)-raspberrypi2.img.gz.sha512
	cd release && sha512sum fruitos-$(VERSION)-raspberrypi3.img.gz > fruitos-$(VERSION)-raspberrypi3.img.gz.sha512

rsync: release
	rsync -avz --progress \
		-e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
		release/ "fruit@fruit-testbed.org:fruitos/images/"

clean.release:
	rm -rf release

isclean:
	@if [ "$$(git diff --shortstat 2> /dev/null | tail -n1)" != "" ]; then \
		echo "This repository is not clean!"; \
		false; \
	else \
		true; \
	fi

.apks:
	cd apks && make
	touch .apks

%.sha512: $*
	@echo "Generating $*.sha512..."
	@sha512sum $* > $*.sha512

$(IMAGE).gz: $(IMAGE)
	@echo "Compressing $(IMAGE) to $(IMAGE).gz..."
	@if [ -f /usr/bin/pigz ]; then \
		pigz -c $(IMAGE) > $(IMAGE).gz; \
	else \
		gzip -c $(IMAGE) > $(IMAGE).gz; \
	fi

$(IMAGE):
	@echo "Copying $(TEMPLATE) to $(IMAGE)..."
	@[ -f /usr/bin/pigz ] && pigz -cd $(TEMPLATE) > $(IMAGE) || zcat $(TEMPLATE) > $(IMAGE)

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
	$(APK) --root $* --initdb add $(PACKAGES)
	$(APK) --no-script --root $* add fruit-initramfs mkinitfs
	@for svc in $(SERVICES); do \
		name=$$(echo $$svc | cut -d'.' -f1); \
		level=$$(echo $$svc | cut -d'.' -f2); \
		chroot $* /sbin/rc-update add $$name $$level; \
	done
	@if [ "$$(grep ttyS0 $*/etc/securetty)" = "" ]; then \
		echo "ttyS0" >> $*/etc/securetty; \
	fi
	@sed -i 's/^VERSION=.*/VERSION="$(VERSION)"/g' /etc/os-release
	@sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="FruitOS v$(VERSION)"/g' /etc/os-release
	@echo "BUILT_TIMESTAMP=$$(date +%s)" >> $*/etc/os-release
	@echo "COMMIT=$$(git rev-parse HEAD)" >> $*/etc/os-release
	@cp -f $*/usr/share/fruit/fruit.json $*/media/mmcblk0p1/fruit.json

%.initramfs:
	@echo "Generating U-Boot initramfs..."
	@chroot $* mkinitfs -o /boot/initramfs-$(MACHINE) \
		$$(cat $*/usr/share/kernel/$(MACHINE)/kernel.release)
	@chroot $* mkimage -A arm -T ramdisk -C none -n initramfs \
		-d /boot/initramfs-$(MACHINE) /boot/initramfs
	@rm -f $*/boot/initramfs-$(MACHINE)

%.clone:
	@src=/dev/$(shell echo $* | cut -d'-' -f1); \
		dest=/dev/$(shell echo $* | cut -d'-' -f2); \
		echo "Cloning $$src to $$dest..."; \
		result=false; \
		mount -o remount,ro $$src && dd if=$$src of=$$dest 2>/dev/null && result=true; \
		mount -o remount,rw /dev/$(shell echo $* | cut -d'-' -f1); \
		${result}

rootfs: $(IMAGE) \
	$(IMAGE),1,loop3.losetup \
	$(IMAGE),2,loop4.losetup \
	loop4-loop3.mount \
	loop4-loop3.rootfs \
	loop4-loop3.initramfs \
	$(IMAGE),3,loop5.losetup \
	loop4-loop5.clone \

cleanall: clean clean.apks

clean: clean.rootfs clean.losetup
	@rm -f $(IMAGE)
	@rm -f $(IMAGE).sha512 $(IMAGE).sha512

clean.gz:
	@rm -f $(IMAGE).gz $(IMAGE).gz.sha512 $(IMAGE).gz.sha512

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
