#!/bin/sh
#
# Run this script after the packages are available in
# apks/target/packages.

set -xe

TEMPLATE=${TEMPLATE:-template.img.gz}
IMAGE=${IMAGE:-fruitos.img}
MOUNTPOINT=${MOUNTPOINT:-targetroot}
NATIVE_COMMANDS=${NATIVE_COMMANDS:-no}
DOCKER_ARCH=${DOCKER_ARCH:-armhf}
REPO_FILE=${REPO_FILE:-}
ALPINE_VERSION=${ALPINE_VERSION:-v3.8}
DEVICE=${DEVICE:-$(losetup --find)}
VERSION=${VERSION:-}
MACHINE=${MACHINE:-}

PACKAGES=${PACKAGES:-}
SERVICES=${SERVICES:-}

# For speedy (de)compression, install `pigz`.
GZIP=$(which pigz || which gzip)

die () {
    echo "$1" >&2
    exit 1
}

die_if_empty () {
    [ ! -z "$2" ] || die "No $1 specified."
}

[ ! -z "$DEVICE" ] || die "Could not find free /dev/loop* device."
[ ! -e "$MOUNTPOINT" ] || die "Mount point ${MOUNTPOINT} already exists."
die_if_empty PACKAGES "$PACKAGES"
die_if_empty SERVICES "$SERVICES"
die_if_empty VERSION "$VERSION"
die_if_empty MACHINE "$MACHINE"

invoke_command () {
    # Shell quoting is a nightmare. Beware spaces.
    #
    if [ "$NATIVE_COMMANDS" = "yes" ]
    then
        $@
    else
        tmpscript=$(mktemp tmpscript.XXXXXXXXXX)
        echo "$@" > $tmpscript
        docker run -it --rm -v `pwd`:`pwd` multiarch/alpine:${DOCKER_ARCH}-${ALPINE_VERSION} \
               /bin/sh -c "cd `pwd`; sh $tmpscript"
        rm -f $tmpscript
    fi
}

###########################################################################

TMP_REPO_FILE=$(mktemp repositories.XXXXXXXXXX)

cleanup () {
    sync
    umount ${MOUNTPOINT}/dev || echo "warning: unmount of ${MOUNTPOINT}/dev failed" >&2
    umount ${MOUNTPOINT}/sys || echo "warning: unmount of ${MOUNTPOINT}/sys failed" >&2
    umount ${MOUNTPOINT}/proc || echo "warning: unmount of ${MOUNTPOINT}/proc failed" >&2
    umount ${MOUNTPOINT}/media/mmcblk0p1 || echo "warning: unmount of ${MOUNTPOINT}/media/mmcblk0p1 failed" >&2
    mount -o remount,ro ${MOUNTPOINT} || echo "warning: remount ro of ${MOUNTPOINT} failed" >&2
    sync
    blockdev --flushbufs ${DEVICE} || echo "warning: flush of buffers for ${DEVICE} failed" >&2
    python -c 'import os; os.fsync(open("'${DEVICE}'", "r+b"))' \
        || echo "warning: fsync of ${DEVICE} failed" >&2
    sleep 1
    umount ${MOUNTPOINT} || echo "warning: unmount of ${MOUNTPOINT} failed" >&2
    rmdir ${MOUNTPOINT} || true
    sync
    sleep 1
    losetup -d ${DEVICE} || echo "warning: losetup removal of ${DEVICE} failed" >&2
    sleep 1
    rm -f ${TMP_REPO_FILE} || true
}

trap cleanup 0

if [ -z "$REPO_FILE" ]
then
    cat < /dev/null > ${TMP_REPO_FILE}
    echo "@fruit `pwd`/apks/target/packages" >> ${TMP_REPO_FILE}
    echo "`pwd`/apks/target/packages" >> ${TMP_REPO_FILE}
    echo "https://dl-4.alpinelinux.org/alpine/${ALPINE_VERSION}/main" >> ${TMP_REPO_FILE}
    echo "https://dl-4.alpinelinux.org/alpine/${ALPINE_VERSION}/community" >> ${TMP_REPO_FILE}
else
    cat < ${REPO_FILE} > ${TMP_REPO_FILE}
fi

# ${GZIP} -dc ${TEMPLATE} > ${IMAGE}
./build-template.sh ${IMAGE}

losetup -P ${DEVICE} ${IMAGE}

# Format partitions
mkfs.vfat -n FRUITOS ${DEVICE}p1
mkfs.ext4 ${DEVICE}p2
# (don't format p3 -- it will be cloned from p2 later)

# Mount root partition - assume that the first of the two root
# partitions is to be the initial active root partition.
#
mkdir -p ${MOUNTPOINT}
mount ${DEVICE}p2 ${MOUNTPOINT}

# Mount boot partition within root partition.
#
mkdir -p ${MOUNTPOINT}/media/mmcblk0p1
mount ${DEVICE}p1 ${MOUNTPOINT}/media/mmcblk0p1

# Mount necessary system directories.
#
mkdir -p ${MOUNTPOINT}/dev ${MOUNTPOINT}/sys ${MOUNTPOINT}/proc
mount -o bind /dev ${MOUNTPOINT}/dev
mount -o bind /sys ${MOUNTPOINT}/sys
mount -o bind /proc ${MOUNTPOINT}/proc

# Create root file system.
#
echo "Repositories:"
cat ${TMP_REPO_FILE}
apkcmd="apk --repositories-file `pwd`/${TMP_REPO_FILE} -U --allow-untrusted"
invoke_command ${apkcmd} --root ${MOUNTPOINT} --initdb add ${PACKAGES}
invoke_command ${apkcmd} --no-script --root ${MOUNTPOINT} add fruit-initramfs mkinitfs

# Enable system services and configure various aspects of the image.
#
tmpbatch=$(mktemp tmpbatch.XXXXXXXXXX)
for svc in ${SERVICES}
do
    name=$(echo $svc | cut -d. -f1)
    level=$(echo $svc | cut -d. -f2)
    echo "chroot ${MOUNTPOINT} /sbin/rc-update add $name $level" >> $tmpbatch
done
invoke_command sh ./$tmpbatch
rm -f $tmpbatch

if grep -vq ttyS0 ${MOUNTPOINT}/etc/securetty
then
    echo ttyS0 >> ${MOUNTPOINT}/etc/securetty
fi

sed -i -e 's/^VERSION=.*/VERSION="'"${VERSION}"'"/g' ${MOUNTPOINT}/etc/os-release
sed -i -e 's/^PRETTY_NAME=.*/PRETTY_NAME="FruitOS v'"${VERSION}"'"/g' ${MOUNTPOINT}/etc/os-release
echo "BUILT_TIMESTAMP=$(date +%s)" >> ${MOUNTPOINT}/etc/os-release
echo "COMMIT=$(git rev-parse HEAD)" >> ${MOUNTPOINT}/etc/os-release
cp -f ${MOUNTPOINT}/usr/share/fruit/fruit.json ${MOUNTPOINT}/media/mmcblk0p1/fruit.json

# Create U-boot initramfs.
#
invoke_command chroot ${MOUNTPOINT} mkinitfs -o /boot/initramfs-${MACHINE} \
               $(cat ${MOUNTPOINT}/usr/share/kernel/${MACHINE}/kernel.release)
invoke_command chroot ${MOUNTPOINT} mkimage -A arm -T ramdisk -C none -n initramfs \
               -d /boot/initramfs-${MACHINE} /boot/initramfs
rm -f ${MOUNTPOINT}/boot/initramfs-${MACHINE}

# Clone the new image to the other root partition.
#
mount -o remount,ro ${DEVICE}p2
dd if=${DEVICE}p2 of=${DEVICE}p3

# We're done with the partitions on the image file.
#
trap - 0
cleanup

###########################################################################

${GZIP} -c < ${IMAGE} > ${IMAGE}.gz
(cd $(dirname ${IMAGE}); sha512sum $(basename ${IMAGE}).gz > $(basename ${IMAGE}).gz.sha512)
