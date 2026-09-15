# Lab 3（Optional）：Linux 内核模糊测试、KASAN 与崩溃分析

Lab 1、Lab 2 从一个**已知**的内存错误出发，研究如何利用它以及内核如何防护；本实验从**自动发现和诊断**出发，练习完整的漏洞处理流程：**发现 → 复现 → 最小化 → 定位 → 修复**。本实验为选做实验，成绩评定方式以课程通知为准。

!!! info "资源状态"
    本页的 KASAN 报告分析练习和脚本已经提供，可直接运行。Task 2–4 需要的 ARM64 QEMU + Linux 6.12.109 + KASAN/KCOV 内核与 `zjufuzz` 教学驱动，可由[助教构建套件](https://github.com/syssec-labhub/syssec-labhub/tree/main/resources/lab3)一键构建；预编译镜像、syzkaller 与 rootfs 由助教通过课程网盘发布。**发布前请勿把 Lab 1/2 的 5.15 镜像当作 Lab 3 环境。**

## 1. 实验目的

* 理解 KASAN（Kernel Address Sanitizer）检测内存错误的原理，学会逐字段阅读 KASAN 崩溃报告
* 理解 KCOV 内核覆盖率采集机制，以及覆盖率引导模糊测试（coverage-guided fuzzing）的基本思想
* 了解 syzkaller 的系统架构（manager / executor / syscall description / 覆盖率反馈循环），并能操作其管理界面
* 掌握崩溃复现（reproduce）、最小化（minimize）与根因定位的完整流程，并给出最小修复补丁

## 2. 实验工具

* qemu-system-aarch64
* syzkaller（syz-manager、syz-executor，课程网盘提供预编译二进制）
* python3（用于运行报告解析脚本）
* 文本编辑器与 diff 工具（用于阅读源码和编写补丁）

## 3. 背景介绍

### 3.1 KASAN

KASAN（Kernel Address Sanitizer）是 Linux 内核自带的动态内存错误检测器。它的核心思想是**影子内存（shadow memory）**：内核将可用内存按 8 字节为一组映射到一片影子区域，每个影子字节记录对应 8 字节中有多少字节是可访问的。分配器（slab）在每块分配的内存前后额外填充**红区（redzone）**，并把红区对应的影子字节标记为不可访问。这样，每次访存指令在被编译器插桩后，都会先查询影子内存：一旦访问落在红区（越界）、已释放的内存（UAF）或未初始化区域，KASAN 就打印一份详细的崩溃报告并终止当前任务。

KASAN 有多种实现，课程镜像使用 **Generic KASAN**（`CONFIG_KASAN_GENERIC`），它在 ARM64 上可用，适合调试越界读写和释放后使用问题。可参考 [Linux 内核 KASAN 文档](https://docs.kernel.org/6.12/dev-tools/kasan.html)。

一份典型的 KASAN 报告如下（即本页入门练习使用的[合成教学样例](lab3_assets/sample_kasan_report.txt)）：

```
BUG: KASAN: slab-out-of-bounds in zjufuzz_write+0x40/0x80
Write of size 4096 at addr ffff00000012f000 by task sample/42

CPU: 0 PID: 42 Comm: sample Not tainted 6.12.109 #1
Call Trace:
 zjufuzz_write+0x40/0x80
 vfs_write+0xa0/0x260
 ksys_write+0x64/0xc0

Allocated by task 42:
 zjufuzz_open+0x18/0x60
 chrdev_open+0x90/0x160

The buggy address belongs to the object at ffff00000012f000
 which belongs to the cache kmalloc-64 of size 64
The buggy address is located 4032 bytes inside of
 64-byte region [ffff00000012f000, ffff00000012f040)
```

阅读报告时关注以下字段：

* **`BUG:` 行**：错误类型（如 `slab-out-of-bounds`、`use-after-free`、`double-free`）和触发访问的函数。
* **`Write/Read of size N at addr ... by task ...`**：访问方向、字节数、被访问的地址和发起访问的任务。
* **`Call Trace:`**：触发这次**访问**的调用栈，最上层是出错指令所在的函数。
* **`Allocated by task ...`**：出错的内存块当初是在哪个调用栈上**分配**的。
* **`Freed by task ...`**（如果存在）：内存块在哪个调用栈上被**释放**。释放后使用（UAF）和重复释放（double-free）的报告里会有这一段，纯越界的报告里通常没有。
* **`belongs to the cache ... of size N` 与 `N-byte region [start, end)`**：该地址落在哪个 slab 缓存、对象多大、地址相对对象的偏移。偏移超出对象范围即可确认越界；偏移仍在对象内则更可能是 UAF 或野指针。

把「访问栈 + 分配栈 + 释放栈 + 偏移」四类证据合在一起，通常就能区分错误类型并圈定可疑代码行。

### 3.2 KCOV

KCOV 是内核内置的覆盖率采集机制。开启 `CONFIG_KCOV`（并配合 `CONFIG_KCOV_INSTRUMENT_ALL`）后，编译器在每个基本块插入 `__sanitizer_cov_trace_pc` 调用，把执行到的 PC 记录到**按任务隔离**的缓冲区中，用户态程序可以通过 debugfs（`/sys/kernel/debug/kcov`）读取。与 KASAN 只在出错时报告不同，KCOV 回答的是"**这段测试输入执行了内核里的哪些代码**"，这正是覆盖率引导模糊测试的基础。

### 3.3 syzkaller

[syzkaller](https://github.com/google/syzkaller) 是 Google 开源的内核模糊测试框架，其架构分为三部分：

* **syz-manager**：运行在宿主机上的管理进程。它维护一个程序（即系统调用序列）语料库，负责变异、拼接程序，生成新输入，并统计覆盖率；同时负责创建/销毁 QEMU 虚拟机、汇总所有崩溃。它自带一个 **Web 管理界面**（默认监听 `127.0.0.1:56741`），可以实时查看覆盖率曲线、执行数、崩溃列表和每个崩溃对应的日志与复现程序。
* **syz-executor**：manager 在每台虚拟机内部署的执行器，负责在客户机里逐条执行系统调用序列，并通过 KCOV 把覆盖率回报给 manager。
* **syscall description（syzlang）**：位于 `sys/linux/` 下的一组 `.txt` 文件，用结构化语法描述"哪些系统调用、哪些参数取值是合法/值得测试的"。fuzzer 生成的每条程序都由这些描述约束。

覆盖率反馈循环如下：manager 生成一个系统调用序列 → executor 在虚拟机里执行 → KCOV 记录这次执行覆盖到的内核代码 → 若覆盖了**此前没到过的代码**，该序列被保留进语料库，作为后续变异的种子；否则丢弃。这样测试会自动向"能触达新代码"的方向进化。当某条序列触发内核崩溃（配合 KASAN 则包括内存错误）时，manager 记录一次 crash，并可进一步用 `syz-repro` 把触发崩溃的序列**最小化**、用 `syz-prog2c` 把它转换为可独立编译运行的 C 程序（reproducer）。

syzkaller 的 [Linux host / QEMU / ARM64 官方指南](https://github.com/google/syzkaller/blob/master/docs/linux/setup_linux-host_qemu-vm_arm64-kernel.md)说明了 KASAN、KCOV、debugfs、SSH 和 QEMU 镜像的完整要求，自建环境可按该指南操作。

## 4. 实验环境与介绍

### 4.1 实验环境

本实验使用与 Lab 1/2 **不同的内核环境**：ARM64 QEMU + **Linux 6.12.109 + Generic KASAN + KCOV**。完整资源包发布后，助教会通过课程网盘提供：`Image`、`vmlinux`、`System.map`、内核 `config`、`SHA256SUMS` 清单、ARM64 rootfs 与 SSH key、`syz-manager`/`syz-executor` 二进制、适配好的 `manager.cfg`，以及待修复的驱动源码 `zjufuzz.c`。

下载后首先核验镜像完整性：

```bash
sha256sum -c SHA256SUMS
```

内核与驱动的构建方法见[助教构建套件](https://github.com/syssec-labhub/syssec-labhub/tree/main/resources/lab3)。学生不需要从零编译内核或 syzkaller。

### 4.2 zjufuzz 教学驱动

实验提供一个名为 `zjufuzz` 的字符设备驱动（源码 `zjufuzz.c`），向用户态暴露以下接口：

* **open**：打开 `/dev/zjufuzz`，驱动在内核中为设备分配一块 **64 字节**的缓冲区。
* **read / write**：读写该缓冲区。
* **ioctl**：命令号 `ZJU_RESIZE`（`_IO('Z', 1)`），释放当前缓冲区并按指定大小重新分配。

该驱动中植入了**一个堆越界写漏洞**，作为本实验 fuzzing 的目标。和 Lab 2 的 zjudev 类似，对同一个设备文件多次 open 会得到指向同一块缓冲区的多个引用，ioctl 可以改变缓冲区大小以影响 slab 分配行为——思考这些接口组合起来能怎样踩到 64 字节缓冲区的边界之外。

### 4.3 手工启动与复现

不使用 syzkaller 时，可以直接用 QEMU 快照模式启动内核，手工复现崩溃（`-snapshot` 保证磁盘镜像不被修改，退出 QEMU 按 `Ctrl-A` 再按 `X`）：

```bash
./run.sh rootfs.img
```

进入客户机后挂载伪文件系统，然后触发驱动漏洞：

```bash
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
dd if=/dev/zero of=/dev/zjufuzz bs=4096 count=1   # 一次超出 64 字节缓冲区的写入
```

`zjufuzz_write()` 未对用户提供的长度做边界检查，KASAN 会在控制台打印一份 slab-out-of-bounds 报告（格式同 3.1 节）。命令行参数 `kasan_multi_shot` 允许 KASAN 连续报告多个错误而不在第一次报告后挂起系统。

## 5. 实验任务

本实验共 5 个 Task，难度逐层递进。**请先自己动手，再对照工具输出检查**——直接用脚本生成答案无法达到练习目的。

### Task 0：KASAN 报告入门

下载[入门练习包](lab3_assets/lab3-triage-starter.zip)（也可单独下载[练习报告](lab3_assets/sample_kasan_report.txt)与[解析脚本](lab3_assets/triage.py)），解压后运行：

```bash
python3 triage.py sample_kasan_report.txt
```

这是一份**合成的教学样例**，仅用于熟悉报告字段，不是实际 fuzzing 的发现。请先**不借助脚本**、对照 3.1 节的字段说明手工阅读报告，再运行脚本核对你的理解是否一致。

### Task 1：手工解析 KASAN 报告

Task 1 的正式提交要在镜像包发布后使用**真实** KASAN 报告（自己 fuzz 出来的，或资源包随附的），先手工标注以下内容，再用 `triage.py` 自查：

1. KASAN 报告的错误类型、访问方向和字节数是什么？
2. 触发访问的调用栈与对象的分配、释放调用栈分别在哪里？
3. 依据这些证据，根因更接近越界、释放后使用，还是重复释放？哪一行代码需要进一步检查？
4. 什么证据表明修复后原 reproducer 不再触发同一错误？

### Task 2：覆盖率引导的模糊测试

确认 `manager.cfg` 中的 `kernel_obj`、`image`、`sshkey` 路径与本机一致后，启动 manager：

```bash
./syz-manager -config manager.cfg
```

然后在浏览器打开 `http://127.0.0.1:56741` 查看 Web 界面。实验内容：

* 观察首页的 **coverage / execs 曲线**，理解"覆盖率增长 → 语料库增长"的正反馈；在报告中记录目标设备接口、运行时长（建议不少于 1 小时）、执行次数与覆盖率变化。
* 打开 **Crashes** 页面查看崩溃列表：每个崩溃有一个标题（通常是第一帧内核符号），点击可查看原始日志。记录所有崩溃条目及其标题。
> 提示：内核崩溃后对应虚拟机会被 manager 自动重启，不需要人工干预；KASAN 报告中出现的 `kasan_multi_shot` 相关行为属于预期。
>
> Question 1：为什么 fuzzing 早期覆盖率增长很快，之后逐渐变慢？这和语料库的保留策略有什么关系？
>
> Question 2：`zjufuzz` 的漏洞是一次普通的堆越界写，为什么 KASAN 能在**没有崩溃**的情况下发现它？

### Task 3：复现与最小化

从 Task 2 的崩溃中选取一个，先在干净快照上独立复现（可用 4.3 节的 `run.sh`，把复现程序放进 rootfs 或通过共享目录传入），再使用 syzkaller 提供的最小化工具缩减系统调用序列：

* 在 dashboard 的崩溃详情页，带有 `repro` 标记的崩溃表示 manager 已自动完成复现与最小化，可直接查看最小化后的 syzlang 程序。
* 使用 `syz-prog2c` 可把 syzlang 程序转换为可独立编译的 C reproducer（Lab 1/2 中我们一直是手写 PoC，这一步就是它的自动化版本）。

提交原始程序、最小 reproducer、复现命令、KASAN 报告及最小化前后的对比。若运行时间内没有发现新崩溃，可使用资源包随附的固定样例，重点是复现与解释过程。

> Question 3：为什么"最小化"对定位根因很重要？一个 200 行的复现程序和一个 3 行的复现程序，对 patch 作者意味着什么？

### Task 4：定位、修复与回归

根据 `zjufuzz.c` 源码和分配/访问调用栈写出根因假设，提交**最小补丁**和解释（提示：问题出在一次没有做边界检查的拷贝，思考正确的修复位置是拷贝点还是分配点，以及为什么）。

对比修复前后同一 reproducer 的结果：修复后重新编译驱动（只需编译模块，无需重编内核）并运行 reproducer，确认 KASAN 不再报告同一错误；再继续运行一段定向 fuzzing，说明是否出现同类崩溃。修复未通过复现或引入新错误时，可以提交失败分析获取部分反馈。

## 6. 实验提交

请同学们在学在浙大上提交实验报告。格式要求为 pdf，命名为学号+姓名+lab3.pdf。实验报告需要包含以下内容：

* Task 1 的 KASAN 报告手工标注（错误类型、三个调用栈、偏移分析）与自查结果
* Task 2 的运行记录（时长、执行数、覆盖率变化、崩溃列表）
* Task 3 的原始程序、最小 reproducer、复现命令与最小化前后对比
* Task 4 的最小补丁、根因分析和修复前后的对比结果
* 回答 Question 1~3
* 报告中记录所用镜像的 SHA256、内核版本、syzkaller 版本、配置与关键命令，保证结果可复现
