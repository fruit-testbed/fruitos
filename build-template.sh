#!/bin/sh
set -xe

IMAGE="$1"

if [ -z "$IMAGE" ]
then
    echo "Usage: ./build-template.sh <imagefilename>" >&2
    exit 1
fi

rm -f ${IMAGE}
truncate -s 1179648K ${IMAGE}
parted ${IMAGE} mktable msdos
parted -a none -s ${IMAGE} mkpart primary fat32 16s 125055s
parted -a none -s ${IMAGE} mkpart primary ext2 125056s 1125119s
parted -a none -s ${IMAGE} mkpart primary ext2 1125120s 2125183s
