#!/usr/bin/env bash
set -euo pipefail

# Build the Lab 3 kernel: Linux 6.12.109 for arm64 with Generic KASAN, KCOV and
# the zjufuzz teaching driver. Output is kernel/kasan/{Image,vmlinux,System.map,
# config} plus a SHA256SUMS manifest under $LAB3_OUT (default ~/lab3-output).
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VERSION=6.12.109
SOURCE_SHA256=5484e552a334e15019f4aeba89e5b58f04651cf2f4e24e04de9f152f1c38e3fa
OUT=${LAB3_OUT:-"$HOME/lab3-output"}
SOURCE=${LAB3_KERNEL_SOURCE:-"$OUT/linux-$VERSION"}
ARCHIVE=${LAB3_KERNEL_ARCHIVE:-"$OUT/linux-$VERSION.tar.xz"}
LLVM_SUFFIX=${LLVM_SUFFIX:--18}
JOBS=${JOBS:-$(nproc)}

mkdir -p "$OUT"
OUT=$(realpath "$OUT")
obj="$OUT/build/kasan"

if [[ ! -d "$SOURCE" ]]; then
    if [[ ! -f "$ARCHIVE" ]]; then
        curl --fail --location --retry 3 \
            "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$VERSION.tar.xz" \
            --output "$ARCHIVE"
    fi
    printf '%s  %s\n' "$SOURCE_SHA256" "$ARCHIVE" | sha256sum --check --status
    tar -xf "$ARCHIVE" -C "$OUT"
    SOURCE="$OUT/linux-$VERSION"
fi

if [[ ! -f "$SOURCE/Makefile" ]]; then
    echo "Invalid Linux source tree: $SOURCE" >&2
    exit 1
fi

for tool in "clang$LLVM_SUFFIX" "ld.lld$LLVM_SUFFIX" "llvm-objdump$LLVM_SUFFIX" \
    make bison flex m4 bc; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done

# Add the teaching driver to the tree (idempotent).
cp "$here/zjufuzz.c" "$SOURCE/drivers/misc/zjufuzz.c"
grep -qxF 'obj-y += zjufuzz.o' "$SOURCE/drivers/misc/Makefile" || \
    printf '\nobj-y += zjufuzz.o\n' >> "$SOURCE/drivers/misc/Makefile"

mkdir -p "$obj" "$OUT/kernel/kasan"
make -C "$SOURCE" O="$obj" ARCH=arm64 LLVM="$LLVM_SUFFIX" defconfig
"$SOURCE/scripts/config" --file "$obj/.config" \
    --enable KASAN --enable KASAN_GENERIC \
    --enable KCOV --enable KCOV_INSTRUMENT_ALL \
    --enable DEBUG_FS --enable DEBUG_INFO --enable DEBUG_INFO_DWARF5 \
    --enable KALLSYMS --enable KALLSYMS_ALL \
    --enable IKCONFIG --enable IKCONFIG_PROC --set-val FRAME_WARN 0
make -C "$SOURCE" O="$obj" ARCH=arm64 LLVM="$LLVM_SUFFIX" olddefconfig

for sym in 'CONFIG_KASAN=y' 'CONFIG_KASAN_GENERIC=y' 'CONFIG_KCOV=y' \
    'CONFIG_KCOV_INSTRUMENT_ALL=y' 'CONFIG_DEBUG_FS=y'; do
    grep -qx "$sym" "$obj/.config" || {
        echo "kernel config was not applied: $sym" >&2
        exit 1
    }
done

make -C "$SOURCE" O="$obj" ARCH=arm64 LLVM="$LLVM_SUFFIX" -j "$JOBS" Image vmlinux
cp "$obj/arch/arm64/boot/Image" "$obj/vmlinux" "$obj/System.map" "$OUT/kernel/kasan/"
cp "$obj/.config" "$OUT/kernel/kasan/config"
(cd "$OUT" && sha256sum kernel/kasan/Image kernel/kasan/vmlinux kernel/kasan/System.map \
    kernel/kasan/config > SHA256SUMS)
echo "Built the Lab 3 KASAN kernel and SHA256SUMS in $OUT"
echo "Next: create a rootfs with syzkaller's create-image.sh, then fuzz with syzkaller/manager.cfg"
