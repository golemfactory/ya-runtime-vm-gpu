#!/bin/bash

set -e

VERSION=$1
SELF_TEST_IMG=$2

tmp_dir=.debpkg/usr/lib/yagna/plugins/ya-runtime-vm-nvidia/runtime

mkdir -p ${tmp_dir}
mkdir -p .debpkg/DEBIAN

cp "$SELF_TEST_IMG" "${tmp_dir}/self-test.gvmi"
for file in bios-256k.bin efi-virtio.rom initramfs.cpio.gz kvmvapic.bin linuxboot_dma.bin vmlinuz-virt vmrt; do
    ln -s ../../ya-runtime-vm/runtime/$file ${tmp_dir}/
done

cp debian/* .debpkg/DEBIAN/

VERSION="$(echo "$VERSION" | sed -E "s,^refs/tags/,,")"
FIXED_VERSION="$(echo "$VERSION" | sed -E 's/^v//')"
sed -i "s/#version/${FIXED_VERSION}/g" .debpkg/DEBIAN/control

DEB_FILE="ya-runtime-vm-nvidia_${VERSION}.deb"

dpkg-deb --build .debpkg "$DEB_FILE"
echo "deb=$DEB_FILE" >> "${GITHUB_OUTPUT}"
