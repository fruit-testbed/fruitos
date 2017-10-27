.PHONY: build boot .mkfs.boot clean cleanall clean.rootfs clean.losetup clean.partition

SIZE = 640  # in MBytes
IMAGE_FILE = disk.img
APKS = /data/fruit-repo/target/packages
#APKS = http://dl-4.alpinelinux.org/alpine/v3.6/main
MACHINE = raspberrypi2
ARCH = armhf

PACKAGES = \
	alpine-base \
	rpi2-boot-linux \
	mkinitfs \
	#fruit-base \
	#rpi2-kernel-modules \
	#fruit-boot-conf	\
	#openssh \
	#openssh-server \
	#docker \
	#singularity \
	#bash \
	#python \
	#e2fsprogs \
	#nfs-utils \
	#curl \
	#parted \
	#btrfs-progs \


ROOT_DIR1 = $(shell pwd)/rootfs1
ROOT_DIR2 = $(shell pwd)/rootfs2

TEMPLATE_IMAGE = template-disk.img.gz

build: .rootfs boot

build.gz: build $(IMAGE_FILE).gz

$(IMAGE_FILE):
	zcat $(TEMPLATE_IMAGE) > $(IMAGE_FILE)


.partition: $(IMAGE_FILE)
	#parted -s $(IMAGE_FILE) mklabel msdos
	#parted -s $(IMAGE_FILE) mkpart primary fat32 8192s 42MB
	#parted -s $(IMAGE_FILE) mkpart primary ext4 50MB 264MB
	#parted -s $(IMAGE_FILE) mkpart primary ext4 272MB 484MB
	#parted -s $(IMAGE_FILE) mkpart primary btrfs 512MB 100%
	touch .partition


.losetup: .partition
	losetup -o $$(( $$(fdisk -lu $(IMAGE_FILE) | grep $(IMAGE_FILE)1 | awk '{print $$3}') * 512)) /dev/loop3 $(IMAGE_FILE)
	losetup -o $$(( $$(fdisk -lu $(IMAGE_FILE) | grep $(IMAGE_FILE)2 | awk '{print $$2}') * 512)) /dev/loop4 $(IMAGE_FILE)
	#losetup -o $$(( $$(fdisk -lu $(IMAGE_FILE) | grep $(IMAGE_FILE)3 | awk '{print $$2}') * 512)) /dev/loop5 $(IMAGE_FILE)
	#losetup -o $$(( $$(fdisk -lu $(IMAGE_FILE) | grep $(IMAGE_FILE)4 | awk '{print $$2}') * 512)) /dev/loop6 $(IMAGE_FILE)
	touch .losetup


.mkfs.boot: .losetup
	#mkfs.vfat /dev/loop3


.rootfs1: .losetup
	mkdir -p $(ROOT_DIR1)
	#mkfs.ext4 -F /dev/loop4
	mount /dev/loop4 $(ROOT_DIR1)
	mkdir -p $(ROOT_DIR1)/boot
	mount /dev/loop3 $(ROOT_DIR1)/boot
	apk -X $(APKS) -U --allow-untrusted --root $(ROOT_DIR1) --initdb add $(PACKAGES)
	mount -o bind /proc $(ROOT_DIR1)/proc
	mount -o bind /dev $(ROOT_DIR1)/dev
	mount -o bind /sys $(ROOT_DIR1)/sys
	chroot $(ROOT_DIR1) /sbin/rc-update add devfs sysinit
	chroot $(ROOT_DIR1) /sbin/rc-update add dmesg sysinit
	chroot $(ROOT_DIR1) /sbin/rc-update add mdev sysinit
	chroot $(ROOT_DIR1) /sbin/rc-update add hwclock boot
	chroot $(ROOT_DIR1) /sbin/rc-update add modules boot
	chroot $(ROOT_DIR1) /sbin/rc-update add sysctl boot
	chroot $(ROOT_DIR1) /sbin/rc-update add hostname boot
	chroot $(ROOT_DIR1) /sbin/rc-update add bootmisc boot
	chroot $(ROOT_DIR1) /sbin/rc-update add syslog boot
	chroot $(ROOT_DIR1) /sbin/rc-update add local default
	chroot $(ROOT_DIR1) /sbin/rc-update add mount-ro shutdown
	chroot $(ROOT_DIR1) /sbin/rc-update add killprocs shutdown
	chroot $(ROOT_DIR1) /sbin/rc-update add savecache shutdown
	if [ "$$(grep '^ttyS0' $(ROOT_DIR1)/etc/inittab)" = "" ]; then \
		echo "ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100" >> $(ROOT_DIR1)/etc/inittab; \
	fi
	if [ "$$(grep ttyS0 $(ROOT_DIR1)/etc/securetty)" = "" ]; then \
		echo "ttyS0" >> $(ROOT_DIR1)/etc/securetty; \
	fi

.rootfs: .mkfs.boot .rootfs1
	touch .rootfs


boot:
	cp -f initramfs-init /usr/share/mkinitfs/initramfs-init
	cp -f mkinitfs.conf /etc/mkinitfs/mkinitfs.conf
	chroot $(ROOT_DIR1) /sbin/mkinitfs -o /boot/initramfs-rpi2 $$(cat $(ROOT_DIR1)/usr/share/kernel/rpi2/kernel.release)
	cp -f cmdline.txt $(ROOT_DIR1)/boot/
	cp -f config.txt $(ROOT_DIR1)/boot/


$(IMAGE_FILE).gz: clean
	gzip $(IMAGE_FILE)


clean: clean.rootfs clean.losetup clean.partition


cleanall: clean clean.$(IMAGE_FILE)


clean.rootfs:
	umount -f $(ROOT_DIR1)/dev 1>/dev/null 2>/dev/null || true
	umount -f $(ROOT_DIR1)/sys 1>/dev/null 2>/dev/null || true
	umount -f $(ROOT_DIR1)/proc 1>/dev/null 2>/dev/null || true
	if [ $$(mount | grep ' on $(ROOT_DIR1)/boot ' | wc -l) -ne 0 ]; then umount -f $(ROOT_DIR1)/boot; fi
	if [ $$(mount | grep ' on $(ROOT_DIR1) ' | wc -l) -ne 0 ]; then umount -f $(ROOT_DIR1); fi
	if [ -e $(ROOT_DIR1) ]; then rmdir $(ROOT_DIR1); fi
	rm -f .rootfs
	rm -f .mkfs.boot


clean.losetup:
	[ "$$(losetup -a | grep '/dev/loop' | grep '3:')" != "" ] && losetup -d /dev/loop3 || true
	[ "$$(losetup -a | grep '/dev/loop' | grep '4:')" != "" ] && losetup -d /dev/loop4 || true
	[ "$$(losetup -a | grep '/dev/loop' | grep '5:')" != "" ] && losetup -d /dev/loop5 || true
	[ "$$(losetup -a | grep '/dev/loop' | grep '6:')" != "" ] && losetup -d /dev/loop6 || true
	rm -f .losetup


clean.partition:
	rm -f .partition


clean.$(IMAGE_FILE):
	rm -f $(IMAGE_FILE)
