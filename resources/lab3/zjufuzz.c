// SPDX-License-Identifier: GPL-2.0
/*
 * zjufuzz: teaching character driver for Lab 3 (kernel fuzzing, KASAN and
 * crash triage).
 *
 * The driver intentionally contains ONE seeded bug: zjufuzz_write() does not
 * bound the user-supplied length against the kernel buffer, so a write larger
 * than the allocation produces a heap out-of-bounds write that Generic KASAN
 * reports. This file is only meant to run inside the isolated course VM.
 *
 * Build note: the build script copies this file into drivers/misc/ and adds
 * "obj-y += zjufuzz.o" to drivers/misc/Makefile, so it is built into the
 * kernel image. No separate module load is required.
 */
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/ioctl.h>

#define ZJU_BUF_INIT	64
#define ZJU_BUF_MAX	4096

/* ioctl: free the current buffer and allocate one of `arg` bytes. */
#define ZJU_RESIZE	_IO('Z', 1)

static int zjufuzz_major;
static struct class *zjufuzz_class;

static char *zjufuzz_buf;
static size_t zjufuzz_len;

static int zjufuzz_open(struct inode *inode, struct file *file)
{
	zjufuzz_buf = kmalloc(ZJU_BUF_INIT, GFP_KERNEL);
	if (!zjufuzz_buf)
		return -ENOMEM;
	zjufuzz_len = ZJU_BUF_INIT;
	pr_info("zjufuzz: open, buffer is %zu bytes\n", zjufuzz_len);
	return 0;
}

static ssize_t zjufuzz_read(struct file *file, char __user *ubuf,
			    size_t len, loff_t *offset)
{
	if (!zjufuzz_buf)
		return -EINVAL;
	if (len > zjufuzz_len)
		len = zjufuzz_len;
	if (copy_to_user(ubuf, zjufuzz_buf, len))
		return -EFAULT;
	return len;
}

static ssize_t zjufuzz_write(struct file *file, const char __user *ubuf,
			     size_t len, loff_t *offset)
{
	if (!zjufuzz_buf)
		return -EINVAL;

	/*
	 * SEEDED BUG: len is never compared against zjufuzz_len. A write that
	 * is larger than the current allocation overflows the heap buffer.
	 */
	if (copy_from_user(zjufuzz_buf, ubuf, len))
		return -EFAULT;
	return len;
}

static long zjufuzz_ioctl(struct file *file, unsigned int cmd,
			  unsigned long arg)
{
	switch (cmd) {
	case ZJU_RESIZE:
		if (arg == 0 || arg > ZJU_BUF_MAX)
			return -EINVAL;
		kfree(zjufuzz_buf);
		zjufuzz_buf = kmalloc(arg, GFP_KERNEL);
		if (!zjufuzz_buf)
			return -ENOMEM;
		zjufuzz_len = arg;
		pr_info("zjufuzz: resized buffer to %lu bytes\n", arg);
		return 0;
	default:
		return -ENOTTY;
	}
}

static int zjufuzz_release(struct inode *inode, struct file *file)
{
	kfree(zjufuzz_buf);
	zjufuzz_buf = NULL;
	zjufuzz_len = 0;
	return 0;
}

static const struct file_operations zjufuzz_fops = {
	.owner		= THIS_MODULE,
	.open		= zjufuzz_open,
	.read		= zjufuzz_read,
	.write		= zjufuzz_write,
	.unlocked_ioctl	= zjufuzz_ioctl,
	.release	= zjufuzz_release,
};

static int __init zjufuzz_init(void)
{
	int ret;
	struct device *dev;

	zjufuzz_major = register_chrdev(0, "zjufuzz", &zjufuzz_fops);
	if (zjufuzz_major < 0)
		return zjufuzz_major;

	zjufuzz_class = class_create("zjufuzz");
	if (IS_ERR(zjufuzz_class)) {
		ret = PTR_ERR(zjufuzz_class);
		goto err_chrdev;
	}

	dev = device_create(zjufuzz_class, NULL, MKDEV(zjufuzz_major, 0),
			    NULL, "zjufuzz");
	if (IS_ERR(dev)) {
		ret = PTR_ERR(dev);
		goto err_class;
	}

	pr_info("zjufuzz: loaded, major %d\n", zjufuzz_major);
	return 0;

err_class:
	class_destroy(zjufuzz_class);
err_chrdev:
	unregister_chrdev(zjufuzz_major, "zjufuzz");
	return ret;
}

static void __exit zjufuzz_exit(void)
{
	device_destroy(zjufuzz_class, MKDEV(zjufuzz_major, 0));
	class_destroy(zjufuzz_class);
	unregister_chrdev(zjufuzz_major, "zjufuzz");
	pr_info("zjufuzz: unloaded\n");
}

module_init(zjufuzz_init);
module_exit(zjufuzz_exit);

MODULE_AUTHOR("ZJU syssec course");
MODULE_DESCRIPTION("Lab 3 teaching driver with a seeded heap OOB write");
MODULE_LICENSE("GPL");
