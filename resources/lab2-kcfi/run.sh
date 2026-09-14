#!/usr/bin/env bash
set -euo pipefail

variant=${1:?"usage: $0 nocfi|kcfi ROOTFS_IMG [OUTPUT_DIRECTORY]"}
rootfs=${2:?"usage: $0 nocfi|kcfi ROOTFS_IMG [OUTPUT_DIRECTORY]"}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=${3:-${LAB2_KCFI_OUT:-$here}}

case "$variant" in nocfi|kcfi) ;; *) echo "Expected nocfi or kcfi" >&2; exit 1 ;; esac
[[ -f "$rootfs" ]] || { echo "Missing rootfs: $rootfs" >&2; exit 1; }
[[ -f "$out/kernel/$variant/Image" ]] || { echo "Build the kernels first: $out" >&2; exit 1; }

# QEMU's snapshot mode leaves the existing disk image unchanged.
exec qemu-system-aarch64 \
    -M virt -cpu cortex-a57 -smp 1 -m 2G \
    -kernel "$out/kernel/$variant/Image" \
    -append 'noinitrd console=ttyAMA0 root=/dev/vda rootfstype=ext4 rw init=/bin/sh loglevel=8' \
    -drive "if=none,file=$rootfs,format=raw,id=hd0" \
    -device virtio-blk-device,drive=hd0 \
    -snapshot -nographic -no-reboot
