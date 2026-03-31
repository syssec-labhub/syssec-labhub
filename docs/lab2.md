# Linux内核漏洞攻防 - JOP攻击与防护

## 1 实验目的

了解 UAF ( Use-After-Free ) 类型的漏洞以及 JOP ( Jump-oriented programming ) 攻击原理，并在此基础上，通过现有的 UAF 漏洞和 JOP 编程，实现获取 Linux 内核的 root 权限的 PoC (Proof of Concept)，并读取一个只有 root 权限下可读的文件，获取 flag。

## 2 实验内容

1） 利用 gdb 调试内核，获取内核关键函数和 gadget 的地址。

2） 了解 Linux 设备提供的接口和其调用逻辑，并尝试使用 Linux 设备接口进行基础编程，了解 Linux 如何利用系统调用的方式触发内核设备中相应的函数。

3） 理解 UAF 漏洞原理，以及漏洞的利用方式；使用 gdb-multiarch 对所提供的未压缩的内核( vmlinux 文件)进行调试，查找设备 UAF 漏洞所在的位置及触发条件，获取内核 `tty_struct` 结构体的内容，并利用设备接口控制该结构体的内容，为 root 内核做准备。

4） 了解 JOP 攻击的原理，尝试利用设备接口触发 UAF 漏洞，并挟持控制流，通过 JOP 攻击绕过 PXN 机制，获取内核的 root 权限。

5） 利用提供的 gadget 片段，构造 JOP 攻击跳转链，获取 root 权限的 shell。

## 3 实验环境

* 实验所需工具：
  * Linux kernel 5.15
  * QEMU 模拟器 （qemu-system-aarch64）
  * gdb-multiarch 多架构调试工具调试 kernel
  * gdb 调试工具调试用户态程序
* 实验提供内容：
  * QEMUrootfs 文件（其内部包含了 gdb，vim 等工具）
  * QEMU 运行脚本（ qemu.sh ）
  * vmlinux 内核镜像(用于 gdb-multiarch 调试)

## 4 前置知识

### 4.1 UAF漏洞原理与利用

Use-After-Free，即当一块内存被释放之后被再次使用，但是这种使用会分为几种情况：

* 内存块被释放之后，对应的指针被设置成 NULL，然后程序使用空指针导致的**程序崩溃**(一般会报指针解引用错误)。
* 内存块被释放之后，对应指针没有被设置成 NULL，然后在使用了这个指针之前，没有对这块内存进行修改，**程序很可能能够正常运转**。
* 内存块被释放之后，对应指针没有被设置成 NULL，且在使用该指针之前有代码对这块内存进行了修改，那么程序再次使用这块内存，**会导致一些奇怪的问题**，比如访问了可能不属于该进程的内存块(由于释放后会被内核分配给别的进程)，甚至通过该指针对这块内存进行修改，然后导致控制流的跳转等。

我们一般所说的UAF漏洞指的都是后面两种，释放后没有被设置为 NULL 的内存指针被称为悬挂指针 ( dangling pointer)。

为了更好的理解 UAF，可以先看一段简单的 demo：

```C
#include <stdio.h>
#include <stdlib.h>
typedef struct name 
{
	char *myname;
    int a, b, c;
	void (*func)(char *str);
    int a1, b1, c1;
} NAME;
void myprint(char *str) { printf("%s\n", str); }
void printmyname(char *str) { printf("call print my name, %s\n", str); }
int main() 
{
	NAME *a;
    a = (NAME *)malloc(sizeof(struct name));
    a->func = myprint;
    a->myname = "I can also use it";
    a->func("this is my function");
    // free without modify
    free(a);
    a->func("I can also use it"); 
    // free with modify
    a->func = printmyname;
    a->func("this is my function");
    // set NULL
    a = NULL;
    // printf("this pogram will crash...\n");
    a->func("can not be printed...");
}
```

可以看到该段代码将一个 free 过后的指针继续使用，这也是前述所讲的 UAF 的基本原理。

再来看一段简单的 hello world 程序：

```C
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
int main()
{
    char *p0;
    p0 = (char *)malloc(sizeof(char)*10);   //指针p0申请内存；
    memcpy(p0,"hello",10);
    printf("p0 Addr: %p, %s\n", p0, p0);      //打印其地址与值；
    free(p0);                               //释放p0；

    char *p1;
    p1=(char *)malloc(sizeof(char)*10);
    memcpy(p1,"world",10);
    printf("p1 Addr: %p, %s\n", p1, p0);
    return 0;
}
```

该段程序先通过 malloc 分配了16字节大小的堆上内存块，随后讲该内存块 free，之后又利用 malloc 分配了一块同样大小的内存块。然后我们看一下程序运行结果：

```shell
user@user-Super-Server:~/Desktop/play$ gcc test.c 
user@user-Super-Server:~/Desktop/play$ ./a.out 
p0 Addr:0x5605b5dde2a0,hello
p1 Addr:0x5605b5dde2a0,world
```

可以发现在堆上分配同样大小的内存时候，第二次分配的地址与第一次分配的地址是一样的，都是 ` 0x5605b5dde2a0`。

> Question 1：为什么会这样？为什么两次分配的内存块地址会一样？
>
> 提示：堆上内存分配算法，注意glibc 2.26前后的不同，注意用户态与内核态的不同

由此我们便可以知道 UAF 的利用过程：

* 内存中存在一个空悬指针指向一块攻击者可控的内存。随后将该内存释放，但是不将指针置空，故攻击者仍然可以利用指针控制这块内存的内容。
* 别的进程或内核通过 malloc/kmalloc 申请了一块同样大小的内存块，会将攻击者可控的这块内存分配出去。
* 由于这块内存内容攻击者可控，就可以利用该块内存实施攻击手段，包括劫持控制流，泄露数据等，最终达到获取 root 权限的目的。

### 4.2 Linux slab 内存管理

#### 4.2.1 什么是 slab ？

slab 是 Linux 内核的内存管理组件，它用于给 Linux 内核中的对象分配内存，所谓对象就是 Linux 内部的数据结构（task_struct，tty_struct 等）。

#### 4.2.2 slab分配机制

当在内核中调用 kmalloc 时（其功能类似用户空间的malloc，分配一段给定大小的内存），会通过 slab 分配特定的大小的内存块。而 slab 对于内存块具有缓存机制，假设内核中有如下的控制流：

```c
void* a = kmalloc(BUF_SIZE, GFP_KERNEL);
// do something
kfree(a);

void* b = kmalloc(BUF_SIZE, GFP_KERNEL); 
```

即内核先通过第一行代码分配了一块 BUF_SIZE 大小的内存块，并将内存块地址赋给指针 a，随后释放了指针 a 所指向的内存块，slab分配器会将其放入一个 `kmem_cache` 缓存中，该缓存内的内存块大小都为 BUF_SIZE 大小。随后内核再次分配一块同样大小的内存块，其会将刚释放的这块内存块分配出去。

### 4.3  Linux 设备及设备驱动

在 Linux 中 `/dev` 目录下，存在很多设备文件，其中有一个 `/dev/ptmx `设备，这个设备文件主要用于打开一对伪终端设备，本次实验利用该设备进行控制流的劫持。

可能需要的头文件：

```c
#include<stdio.h> 
#include <stdlib.h> 
#include <string.h> 
#include <unistd.h> 
#include <sys/stat.h> 
#include <sys/types.h>
#include <fcntl.h> 
#include <sys/ioctl.h> 
```

#### 4.3.1 /dev/ptmx 伪终端和 tty_struct 结构的利用

进程打开 `/dev/ptmx` 设备可以通过使用代码 `open("/dev/ptmx", O_RDWR | O_NOCTTY) ` 打开，当我们执行该代码时，内核会通过以下函数调用链，分配一个 `tty_struct` 结构体：

```c
ptmx_open (drivers/tty/pty.c)
-> tty_init_dev (drivers/tty/tty_io.c)
  -> alloc_tty_struct (drivers/tty/tty_io.c)
```

`tty_struct` 的结构可以[参考链接](https://elixir.bootlin.com/linux/v5.15/source/include/linux/tty.h#L143)所示,在5.15版本的内核中，其大小为 `0x2B8`(696字节) 大小。

其中第5个字段为 `const struct tty_operations *ops`,结构体 `tty_operations`可[参考链接](https://elixir.bootlin.com/linux/v5.15/source/include/linux/tty_driver.h#L247)，该结构体实际上是多个函数指针的集合。在打开了设备终端之后，可以通过系统调用，调用该结构体中的函数，下面代码给了一个使用设备的 demo :

```c
... //some head file && main struct
fd = open("/dev/ptmx", O_RDWR | O_NOCTTY); //open a dev
err = read(fd, &buf, count);
if(err < 0)
{
  // read err
}
err = write(fd, &buf, count);
if(err < 0)
{
  // write err
}
err = ioctl(fd, cmd, &arg);
if(err < 0)
{
  // ioctl err
}
close(fd);
```

#### 4.3.2 利用 ioctl 控制寄存器

    `tty_operations` 结构体中有一个 ioctl 函数，其第一个参数为所对应终端设备的 tty_struct 结构体指针，第二个参数和第三个参数分别是 命令号(cmd) 和 参数所在地址(arg) 如下所示：

```c
	int  (*ioctl)(struct tty_struct *tty,
		    unsigned int cmd, unsigned long arg);
```

    同时用户态程序中 ioctl 系统调用函数原型和调用方式如下所示：

```c
//函数原型：
int ioctl (int __fd, unsigned long int __request, ...)
//调用方式：
#include <sys/ioctl.h>
err = ioctl(fd, cmd, &arg);
```

    可以发现用户态调用 ioctl 时会将 cmd 和 arg 两个参数原封不动地传递给内核中的 ioctl，而 ARM64 架构下函数调用的参数存放在 x0, x1, x2...... 寄存器中，于是我们可以通过修改用户态 ioctl 的参数，从而控制 x1, x2 两个寄存器，并利用这两个寄存器和内核中一些 gadget，可以进而控制更多的寄存器，从而便可以构造函数的参数进行调用。例如：假如内核中存在`mov x1, x0` 的代码片段，由于 x1 寄存器是我们所控制的，而执行该代码片段之后，x0 寄存器内容我们也可以控制。

为了控制ioctl函数，如果我们能够控制其所在结构体 `tty_operation`,或者构造一个假的 `tty_operation` 结构体，并控制 `tty_struct`结构体，将其中 `tty_operation` 成员对应的指针篡改成我们构造的假的结构体地址，这样当我们在用户态执行 `ioctl` 函数时，便可以跳转执行到我们想要执行的地址。

### 4.4 JOP 基础

JOP([参考论文](https://www.comp.nus.edu.sg/~liangzk/papers/asiaccs11.pdf) ) 攻击是类似ROP攻击的一种，只不过ROP通过在栈上构造返回地址来形成攻击链，而JOP攻击不需要利用栈，可以使用跳转的方式来进行攻击，x86 下是通过 `jmp` 指令([参考链接](https://www.anquanke.com/post/id/151571))，ARM 上通过 `BR/BLR` 指令([参考链接](https://developer.arm.com/documentation/102433/0100/Jump-oriented-programming))。当JOP跳转的指令以 ret 指令结尾，其也能转化成 ROP 攻击。

### 4.5 利用 cred 结构体获取 root 权限

从 user 获取 root 权限的方式有很多，本实验涉及利用 cred 结构体获取 root 权限的方式，更多方式可以参考 [github项目](https://github.com/xairy/linux-kernel-exploitation) 或者浏览器搜索引擎搜索关键字 `linux kernel exploitation` 进行了解。

#### 4.5.1 struct cred的作用

linux kernel 记录了每一个进程的权限，是用 [cred](https://elixir.bootlin.com/linux/v5.15/source/include/linux/cred.h#L110) 结构体记录的，每个进程中都有一个 cred 结构，（ Linux 用 task_struct 结构来管理每个进程，该结构体中有个 cred 类型的指针成员）这个结构保存了该进程的权限等信息（uid，gid 等），如果能修改某个进程的 cred，那么也就修改了这个进程的权限。

所以如果能够获取到当前进程的 task_struct 结构的地址，并通过偏移获取到相应的 cred_struct 的地址，就可以通过直接修改内存的方式，将 cred 中的 uid 和 gid 等字段都设置成0，从而当前进程即变成了 root 权限。此种方式较为困难但是可行，学生可以自行尝试。

同时在kernel有两个函数可以很方便地修改进程的权限：

* [struct cred\* prepare_kernel_cred\(struct task_struct\* daemon\)](https://elixir.bootlin.com/linux/v5.15/source/kernel/cred.c#L718)
* [int commit_creds\(struct cred \*new\)](https://elixir.bootlin.com/linux/v5.15/source/kernel/cred.c#L447)

当给 `prepare_kernel_cred()` 函数传递一个NULL参数时，该函数会构造一个 kernel 权限的 cred 结构体，即 uid=0，gid=0，并返回该结构体地址。随后可以把该结构体地址作为参数传给 `commit_creds` 函数,即 `commit_creds(prepare_kernel_cred(0))`，这样就可以把当前进程的权限改为 root 权限。

## 5 实验介绍

本次实验虚拟机内提供的文件：

```
user@user-Super-Server:~/Desktop/experiment$ tree
.
├── qemu.sh
├── rootfs.img
└── vmlinux

0 directories, 3 files
```

其中 qemu.sh 是运行 qemu 的脚本，rootfs.img 为文件系统镜像，vmlinux 为未压缩的内核。可以利用 gdb-multiarch 和 qemu 对vmlinux 进行调试。

同时提供了有 BUG 的设备驱动代码，同学们可以自行查看。

### 5.1 实验环境搭建

通过[浙大云盘](https://pan.zju.edu.cn/share/913fb168cf0dc795da62abe451) 或 [百度网盘](https://pan.baidu.com/s/1fu6NFVSgFaL3mt4ivRi6Ug?pwd=9egt)下载本次实验压缩包，并解压到lab1的 virtual box 实验镜像中。

解压之后路径如下

```shell
syssec@VM:~/lab2$ tree
.
├── kernel
│   ├── cfi
│   │   ├── Image
│   │   ├── System.map
│   │   ├── uafdriver.c
│   │   └── vmlinux
│   └── nocfi
│       ├── drivers
│       │   └── misc
│       │       └── uafdriver.c
│       ├── Image
│       ├── System.map
│       └── vmlinux
├── qemu.sh
└── rootfs.img

5 directories, 10 files

```

主要实验在 `nocfi` 文件夹中进行。其中 `uafdriver.c` 为包含 UAF bug 的驱动文件，可以通过查看其源码理解 UAF 漏洞原理。

>  注意⚠️：**本次实验环境既没有KASLR也没有SMAP防护**

我们提供了编译好的内核镜像(Image)和gdb调试用的vmlinux（symbol可能会有问题）。也可以尝试自己将 `uafdriver.c` 驱动放到lab1所在的内核源码中(`drivers/misc/` 路径下)，再修改同文件夹下的 `Makefile`，增加一行

```c
obj-y          +=      uafdriver.o
```

然后重新交叉编译内核源码即可。
（这样能够方便gdb调试，看到执行流和对应的c代码，直接运行 qemu 脚本也是可以的）

直接运行 qemu 脚本，并输入用户名与密码进入实验环境，可以在 qemu 虚拟机内部直接通过vim编写PoC，并通过gcc进行编译，gdb进行调试。

```shell
sh qemu.sh

username：ubuntu
password：123
```

### 5.2 zjudev接口

本实验在 `/dev/`目录下提供一个 `zjudev` 的设备，该设备在内核维护一个结构体作为字符设备缓冲区，设备缓冲区如下所示，其中 `dev_buf` 字段为打开的设备分配缓冲区，`buf_len` 字段为缓冲区大小（为了防止缓冲区溢出，实际只能使用 `buf_len - 1`）：

```c
struct zjudev_struct
{
    char *dev_buf;
    size_t buf_len;
} zjudev;
```

同时该设备向用户暴露了几个关键接口：

* **open**：

  * 功能：打开 `zjudev` 设备，在内核中为该设备分配64字节的缓冲区大小。
  * 用户态使用范例：

    ```c
    int fd;
    fd = open("/dev/zjudev", O_RDWR); //打开设备，权限为read/write，并返回fd作为文件句柄。（linux万物皆文件）
    ```
* **read**：

  * 功能：读取内核缓冲区中规定长度的内容，但是长度小于 `buf_len`。
  * 用户态使用范例：

    ```c
    char *buf = (char*) malloc(1024);
    read(fd, buf, 40);//从设备中读取40字节到buf字符数组中
    ```
* **write**：

  * 功能：写入一定长度的内容到内核缓冲区中，但长度不能超过内核缓冲区大小。
  * 用户态使用范例：

    ```c
    char *buf = "hello, world!";
    write(fd, buf, sizeof(buf)); //将buf数组的内容写入设备缓冲区
    ```
* **ioctl**:

  * 功能：利用命令控制设备，本实验提供命令号为 `0x0001` 的命令，该功能为释放内核缓冲区，并重新分配一个要求大小的缓冲区，但是该缓冲区大小不能超过8K字节。
  * 用户态使用范例：

    ```c
    ioctl(fd, 0x0001, BUF_SIZE); //其中0x0001为命令号，BUF_SIZE为要求的内核缓冲区大小。
    ```
* **close**:

  * 功能:关闭该设备，释放内核缓冲区。
  * 用户态使用范例：

    ```c
    close(fd); //通过close系统调用关闭文件句柄。
    ```

> 我们代码中写了有printk打印，但其可能并不会被直接打印显示，解决办法有两种
>
> - 使用dmesg命令查看
> - 如果你~~财力~~时间~~雄厚~~充足，可以给printk加入诸如KERN_EMERG/ALERT的参数然后重新编译kernel才能在命令行直接显示printk的消息：  `printk(KERN_EMERG “halo~~\n”);`

### 5.3 UAF漏洞介绍

由于内核中该设备只有全局一个缓冲区，如果将设备打开两次，第二次打开的设备会覆盖第一次打开设备的缓冲区，且两次打开设备时候，我们可以获得指向同一个设备缓冲区的两个指针。此时如果释放其中一个设备，由于在释放的时候指针没有置空，此时便可以通过另一个文件描述符操作该缓冲区对应的内存，即存在 UAF 漏洞。

同时实验提供的 ioctl 接口能够调整这个缓冲区大小如果将其调整成内核中某个数据结构的大小，当内核分配相同大小的数据结构时，便会使用这块由我们控制的缓冲区，由此我们便可以控制内核的关键数据结构，最终达到 root 权限的目的。

### 5.4 struct结构介绍

`tty_struct`：

```c
/* offset    |  size */  type = struct tty_struct {
/*    0      |     4 */    int magic;
/*    4      |     4 */    struct kref {
/*    4      |     4 */        refcount_t refcount;

                               /* total size (bytes):    4 */
                           } kref;
/*    8      |     8 */    struct device *dev;
/*   16      |     8 */    struct tty_driver *driver;
/*   24      |     8 */    const struct tty_operations *ops;
/*   32      |     4 */    int index;
/* XXX  4-byte hole  */
/*   40      |    48 */    struct ld_semaphore {
/*   40      |     8 */        atomic_long_t count;
/*   48      |     4 */        raw_spinlock_t wait_lock;
/*   52      |     4 */        unsigned int wait_readers;
/*   56      |    16 */        struct list_head {
/*   56      |     8 */            struct list_head *next;
/*   64      |     8 */            struct list_head *prev;

                                   /* total size (bytes):   16 */
                               } read_wait;
/*   72      |    16 */        struct list_head {
/*   72      |     8 */            struct list_head *next;
/*   80      |     8 */            struct list_head *prev;

                                   /* total size (bytes):   16 */
                               } write_wait;
...

```

## 6 实验任务

本次实验分为三个小任务，每个小任务难度逐层递进，实验最终要求是获取 root 权限下可读文件中的 flag，并写入自己的实验报告中提交。**本次实验可能会涉及 ASLR，为了简化实验，本次实验提供了 gdb 和 System.map 文件，可以间接绕过。**

### 6.1 Task1：设备接口的使用。

* 编写程序，尝试使用设备接口。
* 尝试利用**章节5.2**的介绍触发 UAF 漏洞，并利用**章节4.4**所提的 `/dev/ptmx `设备(打开该设备内核会分配一个 `tty_struct`结构体, 但是因为 Linux 多核的关系，可能需要堆喷技术，多次打开结构体，多次分配，直到分配到我们UAF指针所控制的那块内存空间为止)，尝试控制一个 `tty_struct` 结构体，并且能够读取和修改所控制的 `tty_struct` 结构体的内容。（触发过程可能会造成 kernel crash，重启 qemu 即可）。

> 提示🌟：同一个设备符被close之后就不要再使用read等函数了。这里需要想办法保证在能够close的情况下，继续读取，该怎么做呢？

> Question 2：如何确定自己所控制的指针一定被分配给 tty_struct结构体 ?
>
> 提示：tty_struct 结构体里有些字段比较特殊。

### 6.2 Task2：简单获取root shell

为了方便同学们获得 root 权限的 shell，本实验在内核中提供一个预先设置的函数 `hack_cred`，其定义如下所示，可以直接利用**章节4.4**所提的 `/dev/ptmx `设备,想办法劫持控制流，使其运行该函数获取 root 权限。

```c
int hack_cred(struct tty_struct *tty, const unsigned char *buf, int c)
{
    struct cred *root_cred = prepare_kernel_cred(NULL);
    commit_creds(root_cred);
    return -1;
}
```

具体步骤如下：

* 利用 gdb-multiarch 调试 kernel，获取该函数地址。
* 根据前述知识和 `/dev/ptmx` 设备，将 `/dev/zjudev` 设备的缓冲区修改为 `tty_struct`结构体大小，并想办法控制该结构体，读取该结构内字段。
* 利用 `write` 系统调用控制该结构体内 `tty_operation` 成员，并将其中某个函数指针地址修改为 `hack_cred` 的地址
* 利用系统调用触发该函数，形成一次跳转的JOP攻击

> 提示🌟：这里没有开启smap保护，所以内核可以访问用户态的内存
>
> Question 3: 为什么不能直接通过 UAF 控制 cred 结构体直接修改其内容？有没有办法能够通过 UAF 来利用新版本的 cred 结构体呢？
>
> 提示：prepare_kernel_cred 函数源码，以及 linux 内核堆内存分配器机制。

### 6.3 Task3：gadget 获取 root shell

第三个小任务在第二个任务的基础上增加了一点难度，要求不使用我们提供的 `hack_cred` 函数，而是使用零碎的以 `br/blr` 指令结尾的汇编代码片段（称为gadget）实现获取root权限。

为了降低实验难度，我们提供了三个gadget (可以利用工具自行在内核镜像中寻找可利用的代码片段) ，如下所示。利用这三个 gadget 以及前述知识，修改我们所控制的 `tty_struct` 和 `tty_operation` 结构体的内容，并多次使用 `tty_operation` 接口获取一些信息，并最终获得root权限。

```c
void zju_gadget1(void)
{
    __asm__ __volatile__ ( 
    "ldr x1, [x0, #0x38]     \n\t"
    "mov x0,x2     \n\t"
    "br x1 \n\t"
    );
}


void zju_gadget2(void)
{
    __asm__ __volatile__ ( 
    "mov x0,0     \n\t"
    "ldr x1, [x2, #0x28]     \n\t"
    "br x1 \n\t"
    );
}


void zju_gadget3(void)
{
    __asm__ __volatile__ ( 
    "ret     \n\t"
    );
}
```

具体步骤如下：

* 利用 gdb-multiarch 获取三个gadget代码片段地址，以及 `prepare_kernel_cred` 和 `commit_creds` 函数地址。
* 利用 `zju_gadget3`，获取 `tty_struct` 结构体的地址。（注意：返回的结构体地址为 x0 寄存器的内容，但是会和真实值不一样，找到原因并获取真实的结构体地址）
* 利用剩下两个gadget控制寄存器 x0，x1，x2，并想办法设置tty operations构造 0 参数，跳转执行 `prepare_kernel_cred` 函数，获取其返回地址。
* 利用剩下两个gadget控制寄存器 x0，x1，x2，并想办法将x0寄存器的值控制成上一步所获得的cred的地址，并调用 `commit_creds` 函数。
* 获取 root shell 之后读取flag文件。

> 提示🌟：不要忘了ioctl的参数类型(fd, int, arg)
>
> Question 4:为什么第二步可以直接ret获取到 `tty_struct`结构体的地址？ret 执行前后的控制流是什么样的？

### 6.4 Task4: 内核 CFI 保护

为了抵御上述劫持内核控制流的JOP攻击，安全研究人员提出了控制流完整性的保护方案（[Control-Flow Integrity](https://lwn.net/Articles/810077/)）。目前内核支持匹配函数类型的CFI保护，需要利用 Clang/LLVM 编译器编译内核源码，最后得到支持CFI的内核镜像。对于每个间接调用，编译器通过匹配其函数指针和函数的类型，提前计算出潜在的目标函数集合，生成跳转表，限制间接调用的目标函数必须在集合中。

实验内容如下：

* 使用objdump反汇编开启CFI的内核镜像 `vmlinux`，获得汇编代码，**提交任意一个间接调用的汇编代码**，并详细解释CFI是如何防御JOP攻击。
* 重新运行JOP攻击程序，查看是否CFI是否能起作用。**提交dmesg中包含CFI Failure截图**。

## 7. 实验提交

请同学们在学在浙大上提交实验报告。格式要求为 pdf，命名为学号+姓名+ lab2.pdf。实验报告需要包含以下内容：

* flag 文件的内容
* Task2 和 Task3 的 PoC 代码
* Task4 中要求提交的内容
* 回答Question1~4