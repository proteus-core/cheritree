#include <machine/syscall.h>
#include <sys/types.h>
#include <sys/errno.h>
#include <unistd.h>

#include <stdio.h>

#include "chardev.h"
#include "kernel_stat.h"
#include "interrupts.h"

#define STDIN_BUF_SIZE 256

extern __attribute__((noreturn)) void _halt();

static uint8_t stdin_buf[STDIN_BUF_SIZE];
static size_t stdin_buf_rpos = 0;
static size_t stdin_buf_wpos = 0;

static size_t stdin_buf_next_pos(size_t pos)
{
    return (pos + 1) % STDIN_BUF_SIZE;
}

static int stdin_buf_is_empty()
{
    return stdin_buf_rpos == stdin_buf_wpos;
}

static int stdin_buf_is_full()
{
    return stdin_buf_next_pos(stdin_buf_wpos) == stdin_buf_rpos;
}

static void external_interrupt_isr()
{
    if (!stdin_buf_is_full())
    {
        uint8_t byte = *(uint8_t*)0xf0004000;
        stdin_buf[stdin_buf_wpos] = byte;
        stdin_buf_wpos = stdin_buf_next_pos(stdin_buf_wpos);
    }
}

static void init_stdin()
{
    register_isr(IRQ_MEI, &external_interrupt_isr);
    enable_irq(IRQ_MEI);
}

static int sys_close(int fd)
{
    if (fd != STDIN_FILENO && fd != STDOUT_FILENO)
        return -EBADF;

    return 0;
}

static off_t sys_lseek(int fd, off_t offset, int whence)
{
    if (fd != STDIN_FILENO && fd != STDOUT_FILENO)
        return -EBADF;

    return -ESPIPE;
}

static ssize_t sys_read(int fd, void* buf, size_t count)
{
    if (fd != STDIN_FILENO)
        return -EBADF;

    if (stdin_buf_is_empty())
        return -EAGAIN;

    size_t num_read = 0;
    uint8_t* byte_buf = buf;

    while (!stdin_buf_is_empty() && num_read < count)
    {
        *byte_buf = stdin_buf[stdin_buf_rpos];
        ++num_read;
        ++byte_buf;
        stdin_buf_rpos = stdin_buf_next_pos(stdin_buf_rpos);
    }

    return num_read;
}

static ssize_t sys_write(int fd, const void* buf, size_t count)
{
    if (fd != STDOUT_FILENO)
        return -EBADF;

    for (size_t i = 0; i < count; ++i)
        CHARDEV = ((const char*)buf)[i];

    return count;
}

static int sys_fstat(int fd, struct kernel_stat* statbuf)
{
    if (fd != STDOUT_FILENO)
        return -EBADF;

    statbuf->st_dev = 0;
    statbuf->st_ino = 0;
    statbuf->st_mode = 020600;
    statbuf->st_nlink = 1;
    statbuf->st_uid = 0;
    statbuf->st_gid = 0;
    statbuf->st_rdev = 0;
    statbuf->st_size = 0;
    statbuf->st_blksize = 0;
    statbuf->st_blocks = 0;
    statbuf->st_atim.tv_sec = 0;
    statbuf->st_atim.tv_nsec = 0;
    statbuf->st_mtim.tv_sec = 0;
    statbuf->st_mtim.tv_nsec = 0;
    statbuf->st_ctim.tv_sec = 0;
    statbuf->st_ctim.tv_nsec = 0;
    return 0;
}

long sys_brk(void* addr)
{
    extern void* heap_start;
    extern void* heap_end;
    static void* brk = NULL;

    if (brk == NULL)
        brk = heap_start;

    if (addr == NULL)
        return (long)brk;

    if (addr >= heap_start && addr < heap_end)
    {
        brk = addr;
        return (long)brk;
    }

    return -1;
}

__attribute__((noreturn)) static void sys_exit(long code)
{
    printf("Exiting with code %ld\n", code);
    _halt();

}

__attribute__((noreturn)) static void unsupported_syscall(long n)
{
    printf("Unsupported syscall: %li\n", n);
    _halt();
}

long syscall(long a0, long a1, long a2, long a3, long a4, long a5, long _, long n)
{
    switch (n)
    {
        case SYS_close:
            return sys_close(a0);
        case SYS_lseek:
            return sys_lseek(a0, a1, a2);
        case SYS_read:
            return sys_read(a0, (void*)a1, a2);
        case SYS_write:
            return sys_write(a0, (const void*)a1, a2);
        case SYS_fstat:
            return sys_fstat(a0, (struct kernel_stat*)a1);
        case SYS_brk:
            return sys_brk((void*)a0);
        case SYS_exit:
            sys_exit(a0);
        default:
            unsupported_syscall(n);
    }
}

__attribute__((constructor)) static void init_syscalls()
{
    init_stdin();
}
