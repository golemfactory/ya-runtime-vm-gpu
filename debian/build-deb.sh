#!/bin/bash

set -e

VERSION=$1
SELF_TEST_IMG=$2

tmp_dir=.debpkg/usr/lib/yagna/plugins/ya-runtime-vm-nvidia

mkdir -p ${tmp_dir}/runtime
mkdir -p .debpkg/DEBIAN

cp "$SELF_TEST_IMG" "${tmp_dir}/runtime/self-test.gvmi"
for file in vgabios-stdvga.bin bios-256k.bin efi-virtio.rom kvmvapic.bin linuxboot_dma.bin vmrt; do
    ln -s ../../ya-runtime-vm/runtime/$file ${tmp_dir}/runtime/
done

ln -s ../ya-runtime-vm/ya-runtime-vm ${tmp_dir}/ya-runtime-vm-nvidia
cp conf/ya-runtime-vm-nvidia.json ${tmp_dir}.json

cp debian/* .debpkg/DEBIAN/

VERSION="$(echo "$VERSION" | sed -E "s,^refs/tags/,,")"
if [[ "$VERSION" = "pre-rel-"* ]]; then
    FIXED_VERSION="$(echo "$VERSION" | sed -E 's/^pre-rel-v//')"
else
    FIXED_VERSION="$(echo "$VERSION" | sed -E 's/^v//')"
fi
sed -i "s/#version/${FIXED_VERSION/-rc/~rc}/g" .debpkg/DEBIAN/control
sed -i "s/__VERSION__/${FIXED_VERSION}/g" ${tmp_dir}.json

DEB_FILE="ya-runtime-vm-nvidia_${VERSION}.deb"

dpkg-deb --root-owner-group --build .debpkg "$DEB_FILE"
echo "deb=$DEB_FILE" >> "${GITHUB_OUTPUT}"
