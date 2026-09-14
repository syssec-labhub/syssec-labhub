# Lab 2 KCFI comparison (Linux 6.12.109)

This resource builds **unmodified upstream Linux** twice with identical arm64
`defconfig` settings except `CONFIG_CFI_CLANG`. The built-in upstream LKDTM
`CFI_FORWARD_PROTO` test demonstrates an indirect call with a compatible type,
followed by one with an incompatible type. It does not include the old Lab 2
vulnerable driver. The previous Lab 2 package remains a separate Linux 5.15
environment for Tasks 1–3.

On Ubuntu 24.04 install the build/boot dependencies:

```sh
sudo apt update
sudo apt install clang-18 lld-18 llvm-18 make bc bison flex m4 libssl-dev libelf-dev \
    qemu-system-arm
```

Download the repository, then build outside the Git checkout to keep large artifacts out of Pages:

```sh
git clone https://github.com/syssec-labhub/syssec-labhub.git
cd syssec-labhub/resources/lab2-kcfi
export LAB2_KCFI_OUT="$HOME/lab2-kcfi-output"
./build.sh
```

The script downloads the [official Linux 6.12.109 source archive](https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.109.tar.xz),
checks its SHA-256, then writes `kernel/nocfi` and `kernel/kcfi` images,
symbols, configs, and a `SHA256SUMS` manifest. `JOBS=4` limits parallelism;
`LAB2_KERNEL_SOURCE` can point to an already extracted 6.12.109 tree.

If you received the prebuilt `lab2-kcfi-6.12.109.tar.xz`, extract it
and run `./run.sh` from that directory; the script finds its bundled
`kernel/` folder automatically.

Boot either image with the **existing** Lab 2 `rootfs.img`. The script uses a
temporary QEMU snapshot, so the original image remains unchanged:

```sh
ROOTFS="$HOME/lab2/rootfs.img"  # adjust to the existing Lab 2 image location
./run.sh nocfi "$ROOTFS" "$LAB2_KCFI_OUT"
# or
./run.sh kcfi "$ROOTFS" "$LAB2_KCFI_OUT"
```

Inside the guest root shell (started with `init=/bin/sh`), run
the upstream LKDTM test. It intentionally causes a kernel fault in the KCFI
image; save a QEMU console log or take a screenshot before exiting. Any work
in the snapshot is discarded when QEMU exits. Use QEMU `Ctrl-A`, then `X` to quit;
`exit` terminates PID 1 and causes an expected kernel panic.

```sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
uname -r
zcat /proc/config.gz | grep -E '^(# )?CONFIG_(CFI_CLANG|LKDTM)'
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
echo CFI_FORWARD_PROTO > /sys/kernel/debug/provoke-crash/DIRECT
```

With `nocfi`, the test reaches its `FAIL: survived mismatched prototype
function call!` diagnostic (a *successful comparison* for the unprotected
kernel). With `kcfi`, the mismatched indirect call triggers a CFI fault before
that line. Compare the console logs and inspect a relevant indirect call in
`kernel/kcfi/vmlinux` with `llvm-objdump-18 -d`. Function signatures that
match the call site's static type can still be valid KCFI targets.

For the TA to distribute prebuilt kernels, run `./package.sh` after the build.
Upload the resulting `lab2-kcfi-6.12.109.tar.xz` and `.sha256` file from
`$LAB2_KCFI_OUT`. The existing `rootfs.img` is intentionally not bundled.
