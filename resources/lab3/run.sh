#!/usr/bin/env bash
set -euo pipefail

# Boot the Lab 3 KASAN kernel for manual crash reproduction.
# Usage: ./run.sh ROOTFS_IMG [OUTPUT_DIRECTORY]
# QEMU snapshot mode leaves the disk image unchanged; work inside the guest is
# discarded when QEMU exits. Quit QEMU with Ctrl-A then X.
rootfs=${1:?"usage: $0 ROOTFS_IMG [OUTPUT_DIRECTORY]"}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=${2:-${LAB3_OUT:-$here}}

[[ -f "$rootfs" ]] || { echo "Missing rootfs: $rootfs" >&2; exit 1; }
[[ -f "$out/kernel/kasan/Image" ]] || { echo "Build the kernel first: $out" >&2; exit 1; }

exec qemu-system-aarch64 \
    -M virt -cpu cortex-a57 -smp 2 -m 2G \
    -kernel "$out/kernel/kasan/Image" \
    -append 'noinitrd console=ttyAMA0 root=/dev/vda rootfstype=ext4 rw init=/bin/sh loglevel=7 kasan_multi_shot' \
    -drive "if=none,file=$rootfs,format=raw,id=hd0" \
    -device virtio-blk-device,drive=hd0 \
    -snapshot -nographic -no-reboot
