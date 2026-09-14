# 课程实验资源（助教用）

本目录存放需要助教构建、再通过课程网盘分发给学生的实验资源。仓库里只保留
可复现的源码、配置和脚本；编译产物（内核镜像、rootfs、syzkaller）体积很大，
不进入 Git 和 GitHub Pages 版本库。

| 目录 | 对应实验 | 内容 | 需上传网盘 |
| --- | --- | --- | --- |
| `lab2-kcfi/` | Lab 2 Task 4 | Linux 6.12.109 `nocfi` / `kcfi` 对照内核的构建、启动与打包脚本 | 是：`lab2-kcfi-6.12.109.tar.xz` |
| `lab3/` | Lab 3（选做） | Linux 6.12.109 Generic KASAN + KCOV 内核与 `zjufuzz` 教学驱动的构建脚本 | 是：内核、rootfs、syzkaller |

## 构建环境

- Ubuntu 24.04 LTS
- `sudo apt install clang-18 lld-18 llvm-18 make bc bison flex m4 libssl-dev libelf-dev qemu-system-arm`
- 在仓库之外构建，例如 `LAB2_KCFI_OUT=$HOME/lab2-kcfi-output`、`LAB3_OUT=$HOME/lab3-output`。

## 与原有资源的关系

Lab 1 / Lab 2 的 5.15 教学镜像与驱动保持原样（见 `~/Downloads/lab1`、`~/Downloads/lab2` 及文档中的网盘链接）。
本目录的 6.12 资源与之并行发布，用于 Lab 2 Task 4 的 KCFI 对照和选做的 Lab 3。
