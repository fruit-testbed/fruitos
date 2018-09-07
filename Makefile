.PHONY: build isclean rsync cleanall clean clean.apks clean.release

IMAGE ?= fruitos.img
TEMPLATE ?= template.img.gz
MACHINE ?= rpi
VERSION ?= $(shell grep '^pkgver=' apks/packages/fruit-baselayout/APKBUILD | cut -d= -f2)

SUDO ?= sudo

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

build: isclean .apks $(IMAGE).gz.sha512

isclean:
	@if [ "$$(git diff --shortstat 2> /dev/null | tail -n1)" != "" ]; then \
		echo "This repository is not clean!"; \
		false; \
	else \
		true; \
	fi

$(IMAGE).gz.sha512:
	$(SUDO) \
		TEMPLATE="$(TEMPLATE)" \
		IMAGE="$(IMAGE)" \
		MACHINE="$(MACHINE)" \
		VERSION="$(VERSION)" \
		PACKAGES="$(PACKAGES)" \
		SERVICES="$(SERVICES)" \
		DOCKER_ARCH="$(DOCKER_ARCH)" \
		./pack-image.sh

release:
	mkdir -p release
	$(MAKE) clean.apks
	DOCKER_ARCH=armhf $(MAKE) IMAGE=release/fruitos-$(VERSION)-raspberrypi1.img MACHINE=rpi
	DOCKER_ARCH=armhf $(MAKE) IMAGE=release/fruitos-$(VERSION)-raspberrypi2.img MACHINE=rpi2
	$(MAKE) clean.apks
	DOCKER_ARCH=aarch64 $(MAKE) IMAGE=release/fruitos-$(VERSION)-raspberrypi3-aarch64.img MACHINE=rpi
	cd release && rm -f *.img
	cd release && sudo ln fruitos-$(VERSION)-raspberrypi1.img.gz fruitos-$(VERSION)-raspberrypi0.img.gz
	cd release && sudo ln fruitos-$(VERSION)-raspberrypi2.img.gz fruitos-$(VERSION)-raspberrypi3.img.gz
	cd release && sha512sum fruitos-$(VERSION)-raspberrypi0.img.gz > fruitos-$(VERSION)-raspberrypi0.img.gz.sha512
	cd release && sha512sum fruitos-$(VERSION)-raspberrypi3.img.gz > fruitos-$(VERSION)-raspberrypi3.img.gz.sha512

rsync: release
	rsync -avz --progress \
		-e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
		release/ "fruit@fruit-testbed.org:fruitos/images/"

.apks:
	./apks/build-via-docker.sh
	touch .apks

cleanall: clean clean.apks

clean:
	rm -f $(IMAGE)
	rm -f $(IMAGE).sha512
	rm -f $(IMAGE).gz
	rm -f $(IMAGE).gz.sha512

clean.apks:
	./apks/build-via-docker.sh clean.packages cleantarget cleancache cleanapks
	rm -f .apks

clean.release:
	rm -rf release
