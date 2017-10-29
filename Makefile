.PHONY: build boot clean cleanall clean.rootfs clean.losetup

SIZE = 640  # in MBytes
IMAGE_FILE = disk.img
APKS = /data/apks/target/packages
#APKS = http://dl-4.alpinelinux.org/alpine/v3.6/main
MACHINE = raspberrypi2
ARCH = armhf

PACKAGES = \
	rpi2-boot-linux \
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


ROOT_DIR1 = $(shell pwd)/rootfs1
ROOT_DIR2 = $(shell pwd)/rootfs2

TEMPLATE_IMAGE = template-disk.img.gz

build: .rootfs boot

build.gz: build $(IMAGE_FILE).gz

$(IMAGE_FILE):
	zcat $(TEMPLATE_IMAGE) > $(IMAGE_FILE)


.losetup: $(IMAGE_FILE)
	@apk add util-linux
	losetup -o $$(( $$(fdisk -lu $(IMAGE_FILE) | grep $(IMAGE_FILE)1 | awk '{print $$3}') * 512)) /dev/loop3 $(IMAGE_FILE)
	losetup -o $$(( $$(fdisk -lu $(IMAGE_FILE) | grep $(IMAGE_FILE)2 | awk '{print $$2}') * 512)) /dev/loop4 $(IMAGE_FILE)
	#losetup -o $$(( $$(fdisk -lu $(IMAGE_FILE) | grep $(IMAGE_FILE)3 | awk '{print $$2}') * 512)) /dev/loop5 $(IMAGE_FILE)
	#losetup -o $$(( $$(fdisk -lu $(IMAGE_FILE) | grep $(IMAGE_FILE)4 | awk '{print $$2}') * 512)) /dev/loop6 $(IMAGE_FILE)
	touch .losetup


.rootfs1:
	mkdir -p $(ROOT_DIR1)
	mount /dev/loop4 $(ROOT_DIR1)
	mkdir -p $(ROOT_DIR1)/boot
	mount /dev/loop3 $(ROOT_DIR1)/boot
	mkdir -p $(ROOT_DIR1)/dev $(ROOT_DIR1)/proc $(ROOT_DIR1)/sys
	mount -o bind /proc $(ROOT_DIR1)/proc
	mount -o bind /dev $(ROOT_DIR1)/dev
	mount -o bind /sys $(ROOT_DIR1)/sys
	apk -X $(APKS) -U --allow-untrusted --root $(ROOT_DIR1) --initdb add $(PACKAGES)
	chroot $(ROOT_DIR1) /sbin/rc-update add devfs sysinit
	chroot $(ROOT_DIR1) /sbin/rc-update add dmesg sysinit
	chroot $(ROOT_DIR1) /sbin/rc-update add mdev sysinit
	chroot $(ROOT_DIR1) /sbin/rc-update add hwdrivers sysinit
	chroot $(ROOT_DIR1) /sbin/rc-update add hwclock boot
	chroot $(ROOT_DIR1) /sbin/rc-update add modules boot
	chroot $(ROOT_DIR1) /sbin/rc-update add sysctl boot
	chroot $(ROOT_DIR1) /sbin/rc-update add hostname boot
	chroot $(ROOT_DIR1) /sbin/rc-update add bootmisc boot
	chroot $(ROOT_DIR1) /sbin/rc-update add syslog boot
	chroot $(ROOT_DIR1) /sbin/rc-update add networking boot
	chroot $(ROOT_DIR1) /sbin/rc-update add sshd default
	chroot $(ROOT_DIR1) /sbin/rc-update add ntpd default
	chroot $(ROOT_DIR1) /sbin/rc-update add crond default
	chroot $(ROOT_DIR1) /sbin/rc-update add local default
	chroot $(ROOT_DIR1) /sbin/rc-update add mount-ro shutdown
	chroot $(ROOT_DIR1) /sbin/rc-update add killprocs shutdown
	chroot $(ROOT_DIR1) /sbin/rc-update add savecache shutdown
	if [ "$$(grep ttyS0 $(ROOT_DIR1)/etc/securetty)" = "" ]; then \
		echo "ttyS0" >> $(ROOT_DIR1)/etc/securetty; \
	fi

.rootfs: .losetup .rootfs1
	touch .rootfs


boot:
	cp -f initramfs-init /usr/share/mkinitfs/initramfs-init
	cp -f mkinitfs.conf /etc/mkinitfs/mkinitfs.conf
	chroot $(ROOT_DIR1) /sbin/mkinitfs -o /boot/initramfs-rpi2 $$(cat $(ROOT_DIR1)/usr/share/kernel/rpi2/kernel.release)
	cp -f cmdline.txt $(ROOT_DIR1)/boot/
	cp -f config.txt $(ROOT_DIR1)/boot/


gz: clean.rootfs clean.losetup
	gzip -c $(IMAGE_FILE) > $(IMAGE_FILE).gz


clean: clean.rootfs clean.losetup
	rm -f $(IMAGE_FILE) $(IMAGE_FILE).gz


clean.rootfs:
	umount -f $(ROOT_DIR1)/dev 1>/dev/null 2>/dev/null || true
	umount -f $(ROOT_DIR1)/sys 1>/dev/null 2>/dev/null || true
	umount -f $(ROOT_DIR1)/proc 1>/dev/null 2>/dev/null || true
	if [ $$(mount | grep ' on $(ROOT_DIR1)/boot ' | wc -l) -ne 0 ]; then umount -f $(ROOT_DIR1)/boot; fi
	if [ $$(mount | grep ' on $(ROOT_DIR1) ' | wc -l) -ne 0 ]; then umount -f $(ROOT_DIR1); fi
	if [ -e $(ROOT_DIR1) ]; then rmdir $(ROOT_DIR1); fi
	rm -f .rootfs


clean.losetup:
	[ "$$(losetup -a | grep '/dev/loop' | grep '3:')" != "" ] && losetup -d /dev/loop3 || true
	[ "$$(losetup -a | grep '/dev/loop' | grep '4:')" != "" ] && losetup -d /dev/loop4 || true
	[ "$$(losetup -a | grep '/dev/loop' | grep '5:')" != "" ] && losetup -d /dev/loop5 || true
	[ "$$(losetup -a | grep '/dev/loop' | grep '6:')" != "" ] && losetup -d /dev/loop6 || true
	rm -f .losetup
