#!/usr/bin/env bash
set -euo pipefail

# Build the same upstream arm64 kernel twice, changing only the KCFI option.
VERSION=6.12.109
SOURCE_SHA256=5484e552a334e15019f4aeba89e5b58f04651cf2f4e24e04de9f152f1c38e3fa
OUT=${LAB2_KCFI_OUT:-"$HOME/lab2-kcfi-output"}
SOURCE=${LAB2_KERNEL_SOURCE:-"$OUT/linux-$VERSION"}
ARCHIVE=${LAB2_KERNEL_ARCHIVE:-"$OUT/linux-$VERSION.tar.xz"}
LLVM_SUFFIX=${LLVM_SUFFIX:--18}
JOBS=${JOBS:-$(nproc)}

mkdir -p "$OUT"
OUT=$(realpath "$OUT")

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

for variant in nocfi kcfi; do
    obj="$OUT/build/$variant"
    mkdir -p "$obj" "$OUT/kernel/$variant"
    make -C "$SOURCE" O="$obj" ARCH=arm64 LLVM="$LLVM_SUFFIX" defconfig
    "$SOURCE/scripts/config" --file "$obj/.config" \
        --enable DEBUG_FS --enable LKDTM --enable IKCONFIG --enable IKCONFIG_PROC \
        --disable DEBUG_INFO_BTF --disable CFI_PERMISSIVE
    if [[ "$variant" == kcfi ]]; then
        "$SOURCE/scripts/config" --file "$obj/.config" --enable CFI_CLANG
    else
        "$SOURCE/scripts/config" --file "$obj/.config" --disable CFI_CLANG
    fi
    make -C "$SOURCE" O="$obj" ARCH=arm64 LLVM="$LLVM_SUFFIX" olddefconfig
    if [[ "$variant" == kcfi ]]; then
        grep -qx 'CONFIG_CFI_CLANG=y' "$obj/.config"
    else
        grep -qx '# CONFIG_CFI_CLANG is not set' "$obj/.config"
    fi
    grep -qx 'CONFIG_LKDTM=y' "$obj/.config"
    make -C "$SOURCE" O="$obj" ARCH=arm64 LLVM="$LLVM_SUFFIX" -j "$JOBS" Image vmlinux
    cp "$obj/arch/arm64/boot/Image" "$obj/vmlinux" "$obj/System.map" "$OUT/kernel/$variant/"
    cp "$obj/.config" "$OUT/kernel/$variant/config"
done

(cd "$OUT" && sha256sum kernel/{nocfi,kcfi}/{Image,vmlinux,System.map,config} > SHA256SUMS)
echo "Built kernels and SHA256SUMS in $OUT"
