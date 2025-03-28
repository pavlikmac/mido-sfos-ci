#!/bin/sh
export PLATFORM_SDK_ROOT="/srv/mer"
export ANDROID_ROOT="/parentroot/srv/hadk"
export VENDOR="xiaomi"
export DEVICE="mido"
export PORT_ARCH="armv7hl"
export EXTRA_NAME=-devel
export RELEASE="5.0.0.62"

sudo mkdir -p /proc/sys/fs/binfmt_misc/
sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
sudo mic create fs --arch=$PORT_ARCH \
--tokenmap=ARCH:$PORT_ARCH,RELEASE:$RELEASE,EXTRA_NAME:$EXTRA_NAME \
--record-pkgs=name,url \
--outdir=sfe-$DEVICE-$RELEASE$EXTRA_NAME \
--pack-to=sfe-$DEVICE-$RELEASE$EXTRA_NAME.tar.bz2 \
Jolla-@RELEASE@-$DEVICE-@ARCH@.ks
