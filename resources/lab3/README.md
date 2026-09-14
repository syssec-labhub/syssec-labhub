# Lab 3 fuzzing kit (Linux 6.12.109 + KASAN + KCOV + zjufuzz)

This is the teaching-assistant kit behind the optional **Lab 3: Automated
Vulnerability Discovery**. It builds the kernel and driver that make the
fuzzing tasks runnable. Students are not expected to build any of this: they
receive the prebuilt `Image`, `vmlinux`, rootfs and syzkaller binary from the
course netdisk link, and only analyze crashes and write patches.

Everything here is built from **unmodified upstream Linux 6.12.109** plus one
seeded teaching driver, so it does not touch the original Lab 1 / Lab 2
resources.

## Contents

| File | Purpose |
| --- | --- |
| `zjufuzz.c` | Character driver with one seeded heap out-of-bounds write |
| `build.sh` | Downloads 6.12.109, adds the driver, enables KASAN/KCOV, builds `Image`/`vmlinux` |
| `run.sh` | Boots the built kernel for manual crash reproduction (QEMU snapshot mode) |
| `syzkaller/manager.cfg` | syzkaller manager template pointing at the built kernel |

## 1. Install build dependencies (Ubuntu 24.04)

```sh
sudo apt update
sudo apt install clang-18 lld-18 llvm-18 make bc bison flex m4 libssl-dev libelf-dev \
    qemu-system-arm
```

## 2. Build the kernel

Build outside the Git checkout so large artifacts never reach GitHub Pages:

```sh
git clone https://github.com/syssec-labhub/syssec-labhub.git
cd syssec-labhub/resources/lab3
export LAB3_OUT="$HOME/lab3-output"
./build.sh
```

The script verifies the SHA-256 of the official source archive, copies
`zjufuzz.c` into `drivers/misc/`, enables `KASAN_GENERIC`, `KCOV`,
`KCOV_INSTRUMENT_ALL`, debugfs and the symbols needed for triage, then writes
`kernel/kasan/{Image,vmlinux,System.map,config}` and a `SHA256SUMS` manifest.
Use `JOBS=4` to limit parallelism; `LAB3_KERNEL_SOURCE` can point to an already
extracted 6.12.109 tree.

## 3. Reproduce the seeded crash by hand

Boot any rootfs with `run.sh` (see the main Lab 2 `rootfs.img`, or a syzkaller
image). Inside the guest:

```sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
dd if=/dev/zero of=/dev/zjufuzz bs=4096 count=1   # write > 64-byte buffer
```

`zjufuzz_write()` copies the user length without bounding it against the 64-byte
allocation, so Generic KASAN reports an out-of-bounds write with the access,
allocation and free stacks. This is exactly the report format practiced in the
[Lab 3 triage exercise](../../docs/lab3.md).

## 4. Coverage-guided fuzzing with syzkaller

Follow the official
[Linux host / QEMU / arm64 guide](https://github.com/google/syzkaller/blob/master/docs/linux/setup_linux-host_qemu-vm_arm64-kernel.md)
to build syzkaller and its arm64 image (`tools/create-image.sh`), then adapt
`syzkaller/manager.cfg` to your paths and run `syz-manager`. The `kernel_obj`
must point at the built `kernel/kasan` directory and the `image` at the arm64
rootfs.

To let syzkaller reach the driver, add a description for `/dev/zjufuzz` under
`sys/linux/` (open/read/write plus the `ZJU_RESIZE` ioctl, `_IO('Z', 1)`) before
rebuilding syzkaller's extracted descriptions with `make generate`. Keep this
file under version control in the TA repository, not in the student handout.

## 5. Distribute to students

Run `build.sh`, build the syzkaller binary, and package the following for the
course netdisk:

* `kernel/kasan/{Image,vmlinux,System.map,config}` and `SHA256SUMS`
* the arm64 syzkaller rootfs image and SSH key
* the `syz-manager` binary and an adapted `manager.cfg`
* the `zjufuzz.c` source students must patch in Task 4

Students verify the recorded SHA-256 values, run the provided environment check
and manager scripts, and reproduce/minimize triage the crashes.
