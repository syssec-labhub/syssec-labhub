# Final Project 列表与要求

## 1.1 利用eBPF实现对Linux内核的Rootkit实战
背景：
eBPF（Extended Berkeley Packet Filter）是Linux内核在3.18版本引入的一项革命性技术。它允许用户在不修改内核源码或加载内核模块的情况下，动态地在内核中加载并执行用户自定义的扩展程序。eBPF依靠即时编译（JIT）技术和严格的静态验证机制（Verifier）来保障这些程序的安全运行。起初，它主要应用于网络数据包的过滤，但如今，其应用范围已经拓展到性能分析、安全监控等多个领域。然而，eBPF的强大功能也可能被攻击者所利用：它能够修改用户空间的内存，hook具有挂载点的内核函数，可被利用来更方便的实现Rootkit。同时，如果Verifier存在漏洞或配置不当，也可能导致内核提权或逃逸。

描述：
利用BPF实现rootkit，对cron无感知地插入后门，可以执行任意命令或向攻击方发起反向连接，并设计利用BPF的，对BPF恶意利用的检测系统框架(基于规则的面向BPF syscall的检测，如非预期用户挂载了敏感类型探针)

里程碑：

1. 理解内核中BPF的作用原理，收集2种已有的eBPF rootkit，阐述其原理（综述）。
2. 扩展已有eBPF rootkit，实现2种新功能（实现）。

中期（第11周）完成：综述  

期末（第16周）完成：实现

参考文档：

1. [What is eBPF？](https://ebpf.io/what-is-ebpf/)
2. [BPF and XDP Reference Guide](https://docs.cilium.io/en/stable/bpf/)
3. [Warping Reality - creating and countering the next generation of Linux rootkits using eBPF](https://defcon.org/html/defcon-29/dc-29-speakers.html#path)
4. [With Friends Like eBPF, Who Needs Enemies?](https://www.blackhat.com/us-21/briefings/schedule/#with-friends-like-ebpf-who-needs-enemies-23619)
5. [内核态eBPF程序实现容器逃逸与隐藏账号rootkit](https://www.cnxct.com/container-escape-in-linux-kernel-space-by-ebpf/)


## 1.2 eBPF的Verify模块的漏洞发现与利用
背景：同上

描述：
eBPF Verifier是Linux内核安全的关键组件，程序在加载之前必须经过Verifier验证，Verifier会检查每个可能执行的程序指令序列，在确保满足所有eBPF安全假设后方可执行。虽然验证器的代码已经经过了层层审查，但随着 eBPF 中不断添加新功能以及Verifier自身功能的复杂性，其中难免存在漏洞，一旦被恶意利用，极可能引发严重后果。

里程碑：

1. 了解Verifier的功能和实现方式，解释Verifier的复杂性以及其中可能存在的漏洞（综述）。
2. 实战利用2~3个Verifier漏洞，实现系统提权、容器逃逸、系统奔溃等任意两个攻击（实现）。
3. （选做）对已有eBPF的自动化漏洞发现程序的复现和改进，尝试发现新的漏洞。

中期（第11周）完成：综述  

期末（第16周）完成：实现

参考文档：

1. [What is eBPF？](https://ebpf.io/what-is-ebpf/)
2. [BPF and XDP Reference Guide](https://docs.cilium.io/en/stable/bpf/)
3. [Warping Reality - creating and countering the next generation of Linux rootkits using eBPF](https://defcon.org/html/defcon-29/dc-29-speakers.html#path)
4. [Hao Sun, Yiru Xu, Jianzhong Liu, Yuheng Shen, Nan Guan, and Yu Jiang. 2024. Finding Correctness Bugs in eBPF Verifier with Structured and Sanitized Program. ](https://doi.org/10.1145/3627703.3629562)
5. [Chaoyuan Peng, Muhui Jiang, Lei Wu, and Yajin Zhou. 2024. Toss a Fault to BpfChecker: Revealing Implementation Flaws for eBPF runtimes with Differential Fuzzing. ]( https://doi.org/10.1145/3658644.3690237)


## 2.基于人工智能的代码漏洞检测

背景：
人工开展代码漏洞挖掘费时费力，传统静态漏洞检测能够实现自动化识别可疑漏洞点，但误报率较高且难以检测复杂的上下文漏洞。基于人工智能的漏洞代码检测定位具有理解代码上下文相关性并对特征进行多层概括和抽象的能力，通过模型的自身泛化能力自动检测代码中相似的漏洞，可代替人工开展疑似漏洞确认，有效提高检测效率。

描述：
本项目旨在使同学们了解漏洞挖掘的基本知识，学习训练多种神经网络模型进行漏洞检测任务。更进一步尝试通过多种模型优化策略提升模型定位漏洞的效果，比如进行更细粒度的程序切片、使用包含更多语义信息的代码标识方法、提高模型识别漏洞根因位置的能力等。

里程碑：

  1. 理解神经网络模型检测源代码漏洞的技术原理，调研三篇现有源代码漏洞检测工作，综述其核心方法及工作
  2. 实现已有源代码漏洞检测模型，在测试集上提升准确度

  中期（第11周）完成: 综述

  期末（第16周）完成: 实现

参考文档：

1. VulChecker: Graph-based Vulnerability Localization in Source Code
https://github.com/ymirsky/VulChecker
2. Devign: Effective vulnerability identification by learning comprehensive program semantics via graph neural networks
3. GPTScan: Detecting Logic Vulnerabilities in Smart Contracts by Combining GPT with Program Analysis
https://mp.weixin.qq.com/s/kZfsa7oi_e9rTTjSQR7mXg
4. Codebert: A pre-trained model for programming and natural languages[J]. arXiv preprint arXiv:2002.08155, 2020.
5. Contrabert: Enhancing code pre-trained models via contrastive learning[C]//2023 IEEE/ACM 45th International Conference on Software Engineering 


## 3.Android应用抗加固分析
背景：
随着Android应用的广泛使用，开发者为了保护其应用的知识产权和防止被分析，通常会采用加固技术，例如加壳、代码混淆、环境检测等技术。这些技术使得应用的逆向工程和动态分析变得困难，从而增加了安全分析的复杂性。然而，这些技术也可能被恶意应用利用，以逃避安全检测。因此，研究如何检测和对抗这些抗分析技术对于提升Android应用的安全性至关重要。

描述：
本项目旨在使同学们了解Android应用分析技术，深入探究Android应用分析中的抗加固技术。

里程碑：

1. 了解常见的代码混淆、加壳、环境检测等技术及其实现原理；
2. （二选一）复现一个现有的去混淆、脱壳或环境对抗的工作（复现）；
3. （二选一）实现一个能够检测Android应用使用了哪些加固技术的工具（实现）。

中期（第11周）完成 ：1

期末 （第16周） 完成：2或3

参考文档：

1. Xue, L.; Zhou, H.; Luo, X.; Zhou, Y.; Shi, Y.; Gu, G.; Zhang, F.; Au, M. H. Happer: Unpacking Android Apps via a Hardware-Assisted Approach. In 2021 IEEE Symposium on Security and Privacy (SP); IEEE: San Francisco, CA, USA, 2021; pp 1641–1658. [https://doi.org/10.1109/SP40001.2021.00105](https://doi.org/10.1109/SP40001.2021.00105).
2. Xue, L.; Zhou, H.; Luo, X.; Yu, L.; Wu, D.; Zhou, Y.; Ma, X. PackerGrind: An Adaptive Unpacking System for Android Apps. IIEEE Trans. Software Eng.2022, 48 (2), 551–570. [https://doi.org/10.1109/TSE.2020.2996433](https://doi.org/10.1109/TSE.2020.2996433).
3. Kondracki, B.; Azad, B. A.; Miramirkhani, N.; Nikiforakis, N. The Droid Is in the Details: Environment-Aware Evasion of Android Sandboxes. In *Proceedings 2022 Network and Distributed System Security Symposium*; Internet Society: San Diego, CA, USA, 2022. [https://doi.org/10.14722/ndss.2022.23056](https://doi.org/10.14722/ndss.2022.23056).
4. Gao, C.; Cai, M.; Yin, S.; Huang, G.; Li, H.; Yuan, W.; Luo, X. Obfuscation-Resilient Android Malware Analysis Based on Complementary Features. IEEE Trans.Inform.Forensic Secur. 2023, 18, 5056–5068. [https://doi.org/10.1109/TIFS.2023.3302509](https://doi.org/10.1109/TIFS.2023.3302509).

## 4.Rust/C跨语言调用分析

背景：Rust通常用于比较底层的项目，与C的语言规范相近，因此开发者为避免重写代码会重用C代码，因此会使用跨语言调用机制。如果C语言部分存在问题，或者跨语言接口抽象存在问题，都是难以修复或者滞后修复的。

描述：因此我们需要分析Rust生态中的library以及面向用户的Rust应用使用跨语言调用的情况，找到真实的CVE，同时设计PoC对CVE进行利用，并给出防护思路。

里程碑：

中期（第11周）完成：综述、PoC实现  

期末（第16周）完成：多个PoC，防护思路

参考文档： 

1. Cross-Language Attacks, NDSS 22

## 5.支持多种处理器架构的MCU Rehosting框架

背景：
大多数rehosting框架只支持ARM或x86等常见架构，但在一些特定场景下，有许多非常规架构的固件。例如智能互联网汽车的场景中，有C166，RH850，V850，SH-2A等汽车固件中的特定架构。如何针对这些架构的MCU进行rehosting具有挑战性，也同时是一项研究重点。描述:本项目旨在使同学们深入理解不同架构的MCU如何rehosting，学习和了解architecture-agnostic的MCU rehosting的框架，并在此基础上对固件进行动态分析，例如fuzzing。

描述：

1. [Chen Z等人]()通过构建新的rehosting框架，突破了传统模拟器（如QEMU）不支持非主流芯片架构的限制，实现了对相关固件的动态分析和测试。[于颖超等人]()对嵌入式设备固件的安全分析技术和相关工作进行了系统性的分类和介绍。请阅读相关论文，搜索更多相关文献，并撰写一篇关于MCU rehosting的简单但要点齐全的综述。
2. [Feng B等人]()通过外设-接口建模技术，摆脱了MCU固件运行需要依赖多个硬件外设的限制条件，实现了MCU固件的rehosting和动态分析，并发现多个漏洞。请阅读相关论文并进行复现，并发现至少一个crash。
3. 实现对附件固件goodwatch.elf(MCU msp430)的rehosting，并记录运行日志。（该固件由助教提供）
4. *（附加）对附件固件进行动态调试或模糊测试，并尝试进行漏洞挖掘。*

里程碑：

中期（第11周）完成1

期末（第16周）完成2、3

参考文档：

1. Feng B, Mera A, Lu L. {P2IM}: Scalable and hardware-independent firmware testing via automatic peripheral interface modeling[C]//29th USENIX Security Symposium (USENIX Security 20). 2020: 1237-1254.
2. Chen Z, Thomas S L, Garcia F D. Metaemu: An architecture agnostic rehosting framework for automotive firmware[C]//Proceedings of the 2022 ACM SIGSAC Conference on Computer and Communications Security. 2022: 515-529.
3. 于颖超, 陈左宁, 甘水滔, 等. 嵌入式设备固件安全分析技术研究[J]. 计算机学报, 2021.


## 6.基于大模型生成代码的评估指标设计和测试

背景：
大语言模型（LLMs）在代码生成领域已取得显著进展，涌现出大量（代码）大模型（如Qwen-Coder、DeepSeek-Coder、CodeLlama、Qwen）。这些模型在代码质量、执行效率及多语言支持等方面差异显著。虽然现有热门代码生成评估体系（如LiveCodeBench、HumanEval、MBPP）已提出多维评估指标，但他们大多仅关注**正确性**，却忽略了诸如**安全性、鲁棒性、可靠性、性能、版权与合规性**等*其他关键因素*，毕竟**可执行代码并不等同于可靠和健壮的代码**。因此，我们首先需要调研现有的热门大模型生成代码评估指标，然后总结**批判**并提出值得改进的地方。比如有人提出评估大模型**滥用API**程度的方法；也有人提出评测代码大模型**效率**的方法。

描述：
本项目通过系统性调研与实践，探索大模型代码评估的创新方法，涵盖了大模型的推理运行、评估标准创新设计运行、测试样例设计等多个关键环节。

里程碑：

1. 总结和批判现有热门大模型生成代码评估指标，不低于**5**种（综述）。
2. **自行设计**不同于热门评估指标的创新指标并**运行**这个指标。设计方面要求在上述*其他关键因素*中的一个方面创新。可参考开源代码，但不可抄袭。测试集和测试样例（如需）均需**自行设计**，数量**5~10**个即可。被测试的大模型数量不得低于**1**个（实现）。

中期（第11周）完成：综述

期末（第16周）完成：实现

参考文档：

1. DeepSeek-AI, Daya Guo, Dejian Yang, Haowei Zhang, Junxiao Song, Ruoyu Zhang, Runxin Xu, et al. 2025. “DeepSeek-R1: Incentivizing Reasoning Capability in LLMs via Reinforcement Learning.” 
2. DeepSeek-AI, Aixin Liu, Bei Feng, Bing Xue, Bingxuan Wang, Bochao Wu, Chengda Lu, et al. 2024. “DeepSeek-V3 Technical Report.” 
3. DeepSeek-AI, Qihao Zhu, Daya Guo, Zhihong Shao, Dejian Yang, Peiyi Wang, Runxin Xu, et al. 2024. “DeepSeek-Coder-V2: Breaking the Barrier of Closed-Source Models in Code Intelligence.” 
4. Hui, Binyuan, Jian Yang, Zeyu Cui, Jiaxi Yang, Dayiheng Liu, Lei Zhang, Tianyu Liu, et al. 2024. “Qwen2.5-Coder Technical Report.” 
5. Rozière, Baptiste, Jonas Gehring, Fabian Gloeckle, Sten Sootla, Itai Gat, Xiaoqing Ellen Tan, Yossi Adi, et al. 2024. “Code Llama: Open Foundation Models for Code.”
6. Austin, Jacob, Augustus Odena, Maxwell Nye, Maarten Bosma, Henryk Michalewski, David Dohan, Ellen Jiang, et al. 2021. “Program Synthesis with Large Language Models.”
7. Chen, Mark, Jerry Tworek, Heewoo Jun, Qiming Yuan, Henrique Ponde de Oliveira Pinto, Jared Kaplan, Harri Edwards, et al. 2021. “Evaluating Large Language Models Trained on Code.”
8. Jain, Naman, King Han, Alex Gu, Wen-Ding Li, Fanjia Yan, Tianjun Zhang, Sida Wang, Armando Solar-Lezama, Koushik Sen, and Ion Stoica. 2024. “LiveCodeBench: Holistic and Contamination Free Evaluation of Large Language Models for Code.”
9. Du, Mingzhe, Anh Tuan Luu, Bin Ji, Qian Liu, and See{-}Kiong Ng. 2024. “Mercury: {A} Code Efficiency Benchmark for Code Large Language Models.” In _Proceedings of the Advances in Neural Information Processing Systems 38: Annual Conference on Neural Information Processing Systems 2024_, 37:16601–22.
10. Zhong, Li, and Zilong Wang. 2024. “Can LLM Replace Stack Overflow? A Study on Robustness and Reliability of Large Language Model Code Generation.” _Proceedings of the AAAI Conference on Artificial Intelligence_ 38 (19): 21841–49.

## 7.基于MTE的内存完整性保护

背景：
内存损坏漏洞仍然是最常见且后果最严重的漏洞之一，它既包括栈溢出、堆溢出等空间维度上的漏洞，也包括重复释放（Double-free）和释放后使用（Use-after-free）等时间维度上的漏洞。硬件厂商提出了不同种类的硬件支持来高效地缓解内存损坏漏洞，而Memory Tagging Extension（MTE）就是其中之一。

Arm在2019年发布的ARMv8.5硬件规范中首次提出了MTE，它用4个比特位对每16字节的内存进行着色，而指针的高位同样有4个比特位标记指针的颜色。如此，只有当指针颜色和内存颜色一致时访存操作才是合法的。


![](img/mte-overview.png)

如上图所示，MTE同时能防护时空两个维度上的内存损坏漏洞，因此近年来受到工业界和学术界的广泛关注。然而，目前还缺乏可行的基于MTE的对内核内存进行实时保护的方法，由于内核安全的重要性和MTE硬件提供的高性能安全能力，如何将二者有机结合已经成为近年来研究的关注焦点。

描述：
本项目旨在使同学们入门硬件辅助安全（Hardware-assisted security）这一热门领域，同时深入了解MTE这一新兴的硬件安全特性。


里程碑：

1. 阅读参考文档并收集更多的相关资料和文献，总结MTE的优缺点 (综述)
2. 成功编译支持MTE的Linux内核并在QEMU上运行，同时运行一个被保护的程序 （实现）。

中期（第11周）完成：综述  

期末（第16周）完成：实现

参考文档：

1. [ARM MTE白皮书](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/Arm_Memory_Tagging_Extension_Whitepaper.pdf)
2. [内存问题的终极武器——MTE](https://juejin.cn/post/7013595058125406238)
3. [Memory Tagging and how it improves C/C++ memory safety](https://arxiv.org/pdf/1802.09517.pdf)
4. [Memory Tagging Extension (MTE) in AArch64 Linux](https://www.kernel.org/doc/html/latest/arm64/memory-tagging-extension.html)
5. [Color My World: Deterministic Tagging for Memory Safety](https://arxiv.org/pdf/2204.03781.pdf)

## 8. Mali GPU中的Page UAF漏洞
背景：
Arm Mali GPU作为移动设备专用图形处理器，广泛集成于Android智能手机、物联网设备及智能电视等终端。在Android系统中，GPU驱动程序通过用户-内核态接口向应用层开放访问权限，这使得潜在恶意应用可对内核态驱动发起攻击。据统计，当前Android设备GPU主要采用高通Adreno与Arm Mali两种架构，覆盖超过95%的市场份额。因此，针对这两类GPU驱动程序的漏洞研究具有广泛的实际意义。
GPU驱动核心功能之一是实现用户态进程与GPU硬件间的共享内存管理。由于涉及复杂的内存分配、映射与同步机制，该模块常成为安全漏洞的高发区域。此类漏洞往往导致内存损坏类风险，且现有防护机制难以有效检测。值得注意的是，Google Project Zero 2021年度报告指出，当年检测到的Android系统7个0-day漏洞中，5个均存在于GPU驱动程序模块。

描述：
在前期课程和实验中，大家已掌握了UAF（use-after-free）漏洞基本原理、触发条件及利用方式。本实验要求同学们将UAF漏洞的研究拓展至GPU驱动安全领域，GPU驱动因其直接控制硬件资源的特性（如物理页表管理、内存映射等），成为攻击者突破系统隔离机制的重要目标。通过操控GPU驱动的漏洞，攻击者可能绕过CPU侧的安全防护。

里程碑：

1. 通过公开漏洞库、学术论文等资源，自主检索近年公布的与GPU驱动相关的UAF漏洞案例（如内存管理、上下文切换等场景），分析其成因及利用链构造方式。（综述）
2. 漏洞复现与验证：搭建支持存在漏洞的Mali GPU驱动的虚拟机实验环境，并且在实验环境中尝试复现1-2个漏洞，结合调试工具（如GDB、内核日志等）观察UAF触发时的系统行为，解释漏洞如何通过GPU驱动影响物理内存或内核完整性。（实现）

中期（第11周）完成：综述  

期末（第16周）完成：实现

参考文档：

1. [GPU 驱动漏洞：窥探驱动漏洞利用的技术奥秘](https://forum.butian.net/share/3924)
2. [Mali Open Source Driver](https://linux-sunxi.org/Mali_Open_Source_Driver)
4. [GitHub Security Lab](https://github.com/github/securitylab/tree/main)
2. [The “not-Google” bug in the “all-Google” phone](https://github.blog/security/vulnerability-research/pwning-the-all-google-phone-with-a-non-google-bug/)


## 9.分组和展示
本次final project采取自由分组，每组3人。请自行组队，并从给定题目中选择一个，确定分组和选题后，3.30之前将组员名单和选题填写至钉钉群共享文件。

**注意**：每个题目最多2组选择，同选题小组间需协商确定不同研究方向，避免雷同。

实验过程中将设置两次检查：

- 中期检查：根据各自题目要求，提交调研报告，展示调研进展，并且对期末实现的具体内容作出初步规划。
- 期末检查：分组presentation，每组限时15min（10min展示+5min提问），进行调研内容的汇报和结果展示。展示后在“学在浙大”提交PPT。
