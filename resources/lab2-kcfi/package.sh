#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=${LAB2_KCFI_OUT:-"$HOME/lab2-kcfi-output"}
out=$(realpath "$out")
for variant in nocfi kcfi; do
    [[ -f "$out/kernel/$variant/Image" && -f "$out/kernel/$variant/vmlinux" ]] || {
        echo "Missing built $variant kernel in $out" >&2
        exit 1
    }
done
[[ -f "$out/SHA256SUMS" ]] || { echo "Missing SHA256SUMS in $out" >&2; exit 1; }

archive="$out/lab2-kcfi-6.12.109.tar.xz"
tar -cJf "$archive" -C "$out" kernel SHA256SUMS -C "$here" README.md run.sh
sha256sum "$archive" > "$archive.sha256"
echo "Upload $archive and $archive.sha256"
