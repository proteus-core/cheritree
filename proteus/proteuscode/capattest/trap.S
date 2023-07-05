#define WORD_SIZE 4
#define CONTEXT_SIZE (28 * WORD_SIZE)

    .text
    .globl _init_traps
_init_traps:
    la  t0, _trap_handler
    csrw mtvec, t0
    ret

    .globl _trap_handler
_trap_handler:
    addi sp, sp, -CONTEXT_SIZE
    sw ra,   0 * WORD_SIZE(sp)
    sw t0,   1 * WORD_SIZE(sp)
    sw t1,   2 * WORD_SIZE(sp)
    sw t2,   3 * WORD_SIZE(sp)
    sw s0,   4 * WORD_SIZE(sp)
    sw s1,   5 * WORD_SIZE(sp)
    sw a0,   6 * WORD_SIZE(sp)
    sw a1,   7 * WORD_SIZE(sp)
    sw a2,   8 * WORD_SIZE(sp)
    sw a3,   9 * WORD_SIZE(sp)
    sw a4,  10 * WORD_SIZE(sp)
    sw a5,  11 * WORD_SIZE(sp)
    sw a6,  12 * WORD_SIZE(sp)
    sw a7,  13 * WORD_SIZE(sp)
    sw s2,  14 * WORD_SIZE(sp)
    sw s3,  15 * WORD_SIZE(sp)
    sw s4,  16 * WORD_SIZE(sp)
    sw s5,  17 * WORD_SIZE(sp)
    sw s6,  18 * WORD_SIZE(sp)
    sw s7,  19 * WORD_SIZE(sp)
    sw s8,  20 * WORD_SIZE(sp)
    sw s9,  21 * WORD_SIZE(sp)
    sw s10, 22 * WORD_SIZE(sp)
    sw s11, 23 * WORD_SIZE(sp)
    sw t3,  24 * WORD_SIZE(sp)
    sw t4,  25 * WORD_SIZE(sp)
    sw t5,  26 * WORD_SIZE(sp)
    sw t6,  27 * WORD_SIZE(sp)

    csrr t0, mcause
    srli t1, t0, __riscv_xlen - 1
    bne t1, zero, _interrupt_handler
    li t1, 11
    beq t0, t1, _syscall_handler
    j _unsupported_trap

_trap_return:
    lw ra,   0 * WORD_SIZE(sp)
    lw t0,   1 * WORD_SIZE(sp)
    lw t1,   2 * WORD_SIZE(sp)
    lw t2,   3 * WORD_SIZE(sp)
    lw s0,   4 * WORD_SIZE(sp)
    lw s1,   5 * WORD_SIZE(sp)
    lw a0,   6 * WORD_SIZE(sp)
    lw a1,   7 * WORD_SIZE(sp)
    lw a2,   8 * WORD_SIZE(sp)
    lw a3,   9 * WORD_SIZE(sp)
    lw a4,  10 * WORD_SIZE(sp)
    lw a5,  11 * WORD_SIZE(sp)
    lw a6,  12 * WORD_SIZE(sp)
    lw a7,  13 * WORD_SIZE(sp)
    lw s2,  14 * WORD_SIZE(sp)
    lw s3,  15 * WORD_SIZE(sp)
    lw s4,  16 * WORD_SIZE(sp)
    lw s5,  17 * WORD_SIZE(sp)
    lw s6,  18 * WORD_SIZE(sp)
    lw s7,  19 * WORD_SIZE(sp)
    lw s8,  20 * WORD_SIZE(sp)
    lw s9,  21 * WORD_SIZE(sp)
    lw s10, 22 * WORD_SIZE(sp)
    lw s11, 23 * WORD_SIZE(sp)
    lw t3,  24 * WORD_SIZE(sp)
    lw t4,  25 * WORD_SIZE(sp)
    lw t5,  26 * WORD_SIZE(sp)
    lw t6,  27 * WORD_SIZE(sp)
    addi sp, sp, CONTEXT_SIZE
    mret

_syscall_handler:
    jal syscall
    sw a0, 6 * WORD_SIZE(sp)
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    j _trap_return

_interrupt_handler:
    slli a0, t0, 1
    srli a0, a0, 1
    jal isr
    j _trap_return

_unsupported_trap:
    mv a0, t0
    jal exception
    j _halt
