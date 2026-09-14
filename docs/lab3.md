# Lab 3（Optional Bonus）：Linux 内核模糊测试、KASAN 与崩溃分析

Lab 1、Lab 2 从已知内存错误出发研究利用与防护；本实验从自动发现和诊断出发，练习“发现 → 复现 → 最小化 → 定位 → 修复”。本实验**选做**：完成最多在课程总评上加 5 分，最终成绩不超过 100 分；未参加不扣分，可以按任务部分得分。

!!! info "资源状态"
    本页的 KASAN 报告分析练习和脚本已经提供，可直接运行。Task 2–4 需要的 ARM64 QEMU + Linux 6.12.109 + KASAN/KCOV 内核与 `zjufuzz` 教学驱动，可由[助教构建套件](https://github.com/syssec-labhub/syssec-labhub/tree/main/resources/lab3)一键构建；预编译镜像、syzkaller 与 rootfs 由助教通过课程网盘发布。**发布前请勿把 Lab 1/2 的 5.15 镜像当作 Lab 3 环境。**

## 目标与评分

| Task | 内容 | 本实验内占比 |
| --- | --- | ---: |
| 0 | 阅读 KASAN 报告并运行示例分析脚本 | 教程 |
| 1 | 标注错误类型、越界/释放对象、分配与访问调用栈 | 20% |
| 2 | 用预配置 syzkaller + KCOV 运行定向 fuzzing，保存覆盖率和崩溃记录 | 30% |
| 3 | 复现并最小化一个崩溃，提交最小 reproducer | 25% |
| 4 | 定位根因，给出修复补丁，重新运行 reproducer 和回归测试 | 25% |

各任务只在隔离的课程虚拟机内运行。报告中记录镜像 SHA256、内核版本、syzkaller commit、配置、命令、运行时长、原始日志和修复前后的结果。

## Task 0–1：KASAN 崩溃报告入门

下载[入门练习包](lab3_assets/lab3-triage-starter.zip)（也可单独下载[练习报告](lab3_assets/sample_kasan_report.txt)与[解析脚本](lab3_assets/triage.py)），解压后在本地运行：

    python3 triage.py sample_kasan_report.txt

这是一份**合成的教学样例**，仅用于熟悉报告字段，不是实际 fuzzing 的发现。Task 1 的正式提交要在镜像包发布后使用真实 KASAN 报告，回答：

1. KASAN 报告的错误类型、访问方向和字节数是什么？
2. 触发访问的调用栈与对象的分配、释放调用栈分别在哪里？
3. 依据这些证据，根因更接近越界、释放后使用，还是重复释放？哪一行代码需要进一步检查？
4. 什么证据表明修复后原 reproducer 不再触发同一错误？

可参考 [Linux 6.12 KASAN 文档](https://docs.kernel.org/6.12/dev-tools/kasan.html)。课程镜像预期采用 Generic KASAN；它在 ARM64 上可用，适合调试越界和释放后使用问题。

## Task 2：覆盖率引导的模糊测试

完整资源包发布后，助教会提供匹配的 Linux 6.12.109 Image、vmlinux、内核配置、QEMU rootfs、syzkaller 可执行文件、manager 配置与教学驱动源码（`zjufuzz`）。内核与驱动的构建方法见[助教构建套件](https://github.com/syssec-labhub/syssec-labhub/tree/main/resources/lab3)。学生只需核验清单中的 SHA256、运行提供的环境检查脚本和 manager 启动脚本，不需要从零编译 syzkaller。记录目标设备接口、运行时长、执行次数、覆盖率变化及所有崩溃条目。

Syzkaller 的[Linux host / QEMU / ARM64 官方指南](https://github.com/google/syzkaller/blob/master/docs/linux/setup_linux-host_qemu-vm_arm64-kernel.md)说明了 KASAN、KCOV、debugfs、SSH 和 QEMU 镜像的要求；自建环境可按该指南操作，但提交结果必须说明与课程固定环境的差异。

## Task 3：复现与最小化

从 Task 2 的崩溃中选取一个，先在干净快照上独立复现，再使用 syzkaller 提供的最小化工具缩减系统调用序列。提交原始程序、最小 reproducer、复现命令、KASAN 报告及最小化前后的对比。若没有发现新崩溃，可使用资源包随附的固定样例，评分重点仍是复现与解释过程。

## Task 4：定位、修复与回归

根据源码和分配/释放/访问调用栈写出根因假设，提交最小补丁和解释。对比修复前后同一 reproducer 的结果，再继续运行定向 fuzzing，说明是否出现同类崩溃。修复未通过复现或引入新错误时，可以提交失败分析获取部分分数。

## 提交

提交 PDF 报告、原始日志、最小 reproducer、补丁和可复现的运行说明。Task 0 不计分；Task 1–4 按上表占比换算为最多 5 分的课程加分，允许部分得分，总评封顶 100 分。
