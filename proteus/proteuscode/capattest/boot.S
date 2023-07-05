#include "chardev.h"

    .section .boot
    .globl _boot
_boot:
    .option push
    .option norelax
    .extern _end
    la sp, _end
    .option pop

    # stack size: 10KB
    li t0, 10240
    add sp, sp, t0
    # align sp to 16 bytes
    li t0, 0xfffffff0
    and sp, sp, t0

    # set the start of the heap to the end of the stack
    .option push
    .option norelax
    .extern heap_start
    la t0, heap_start
    la t1, heap_end
    .option pop

    sw sp, (t0)

    # heap size: 10KB
    li t0, 10240
    add t0, sp, t0
    sw t0, (t1)

    # jal _init_traps
    # jal trusted_init
    jal _start

    .globl _halt
_halt:
    li x1, CHARDEV_ADDR
    li x2, CHARDEV_EOT
    sb x2, 0(x1)
1:
    j 1b
