#include "trusted_traps.h"

#define WORD_SIZE 4
#define CONTEXT_SIZE (28 * WORD_SIZE)

    .section .trusted_traps
_trusted_trap_handler:
    // Swap ct0 and mscratchc so we can use ct0 as scratch reg
    CSpecialRW ct0, mscratchc, ct0

    // Same for t0 and mscratch
    csrrw t0, mscratch, t0

    // Check if data section in c31 is large enough to hold trap data. Note that
    // the "addi" trick is because we only have one register available at this
    // point.
    CGetLen t0, c31
    addi t0, t0, -TRAP_DATA_LEN
    blt t0, zero, _clear_state

    // Load epcc from data section in c31
    li t0, TRAP_DATA_OFFSET_EPCC
    CSetOffset c31, c31, t0
    lc.cap ct0, (c31)

    // If tag is set, enclave is already in an interrupted state. Just clear
    // state and jump to untrusted handler.
    CGetTag t0, ct0
    bnez t0, _clear_state

    // Restore ct0/t0 to their original values
    CSpecialRW ct0, mscratchc, ct0
    csrrw t0, mscratch, t0

    // Store capability registers in data section
    CSetOffset c31, c31, zero
    CIncOffsetImm c31, c31, TRAP_DATA_OFFSET_CAPS
    sc.cap c1, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c2, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c3, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c4, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c5, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c6, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c7, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c8, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c9, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c10, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c11, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c12, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c13, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c14, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c15, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c16, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c17, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c18, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c19, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c20, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c21, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c22, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c23, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c24, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c25, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c26, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c27, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c28, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c29, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap c30, (c31)

    // Store GPRs in data section
    CSetOffset c31, c31, zero
    CIncOffsetImm c31, c31, TRAP_DATA_OFFSET_REGS
    sw.cap ra, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap t0, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap t1, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap t2, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s0, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s1, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap a0, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap a1, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap a2, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap a3, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap a4, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap a5, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap a6, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap a7, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s2, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s3, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s4, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s5, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s6, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s7, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s8, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s9, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s10,(c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap s11,(c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap t3, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap t4, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap t5, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    sw.cap t6, (c31)

_clear_state:
    // Clear capability registers
    CClearTag c1, c1
    CClearTag c2, c2
    CClearTag c3, c3
    CClearTag c4, c4
    CClearTag c5, c5
    CClearTag c6, c6
    CClearTag c7, c7
    CClearTag c8, c8
    CClearTag c9, c9
    CClearTag c10, c10
    CClearTag c11, c11
    CClearTag c12, c12
    CClearTag c13, c13
    CClearTag c14, c14
    CClearTag c15, c15
    CClearTag c16, c16
    CClearTag c17, c17
    CClearTag c18, c18
    CClearTag c19, c19
    CClearTag c20, c20
    CClearTag c21, c21
    CClearTag c22, c22
    CClearTag c23, c23
    CClearTag c24, c24
    CClearTag c25, c25
    CClearTag c26, c26
    CClearTag c27, c27
    CClearTag c28, c28
    CClearTag c29, c29
    CClearTag c30, c30

    // Clear GPRs
    // We don't clear special regs (sp, gp,...) and arg regs (a0...).
    mv x5, zero
    mv x6, zero
    mv x7, zero
    mv x8, zero
    mv x9, zero
    mv x18, zero
    mv x19, zero
    mv x20, zero
    mv x21, zero
    mv x22, zero
    mv x23, zero
    mv x24, zero
    mv x25, zero
    mv x26, zero
    mv x27, zero
    mv x28, zero
    mv x29, zero
    mv x30, zero
    mv x31, zero

    // Store mepcc to epcc in data section
    li t0, TRAP_DATA_OFFSET_EPCC
    CSetOffset c31, c31, t0
    CSpecialR ct0, mepcc
    sc.cap ct0, (c31)

    // NOTE t0 and t1 will be used by _untrusted_trap_handler to read mcause
    // and the sycall trap number. DO NOT OVERWRITE THEM (I just lost an hour of
    // my life because of that).
    csrr t0, mcause
    li t1, 11
    bne t0, t1, 1f
    CIncOffsetImm ct0, ct0, 4 // syscall -> return to epc + 4
1:
    sc.cap ct0, (c31)

    // Seal c31
    CSpecialR ct0, mtdc
    CSeal c31, c31, ct0
    CClearTag ct0, ct0

_jump_to_untrusted:
    lui t2, %hi(_untrusted_trap_handler)
    addi t2, t2, %lo(_untrusted_trap_handler)
    CSpecialR ct0, ddc
    CSetAddr ct0, ct0, t2

    // TODO For this to be secure, the implementation of CJALR should be fixed
    // to produce a sentry cap in cd (as per the CHERI spec).
    CJALR cra, ct0

_trusted_trap_return:
    // The above CJALR sets the return address here

    // Unseal c31
    CSpecialR ct0, mtdc
    CUnseal c31, c31, ct0
    CClearTag ct0, ct0

    // Restore mepcc from data section
    CSetOffset c31, c31, zero
    CIncOffsetImm c31, c31, TRAP_DATA_OFFSET_EPCC
    lc.cap ct0, (c31)

    // Check if the tag is set. If not, the enclave was not interrupted and we
    // should not try te restore its state.
    CGetTag t0, ct0
    beqz t0, _trusted_trap_error

    CSpecialW mepcc, ct0

    // Clear stored epcc
    sc.cap cnull, (c31)

    // Check if this was a syscall and save a0 if so.
    // FIXME since we read mcause again, this will not work for nested traps.
    csrr t0, mcause
    li t1, 11
    bne t0, t1, 1f
    li t0, TRAP_DATA_OFFSET_REGS + 6 * WORD_SIZE
    CSetOffset c31, c31, t0
    sw.cap a0, (c31)

1:
    // Restore capability registers in data section
    CSetOffset c31, c31, zero
    CIncOffsetImm c31, c31, TRAP_DATA_OFFSET_CAPS
    lc.cap c1, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c2, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c3, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c4, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c5, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c6, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c7, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c8, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c9, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c10, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c11, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c12, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c13, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c14, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c15, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c16, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c17, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c18, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c19, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c20, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c21, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c22, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c23, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c24, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c25, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c26, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c27, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c28, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c29, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    lc.cap c30, (c31)

    // Clear all stored capability values (to prevent mem sweep issues)
    CSetOffset c31, c31, zero
    CIncOffsetImm c31, c31, TRAP_DATA_OFFSET_CAPS
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)
    CIncOffsetImm c31, c31, CAP_LEN
    sc.cap cnull, (c31)

    // Restore all GPRs
    CSetOffset c31, c31, zero
    CIncOffsetImm c31, c31, TRAP_DATA_OFFSET_REGS
    lw.cap ra, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap t0, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap t1, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap t2, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s0, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s1, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap a0, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap a1, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap a2, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap a3, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap a4, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap a5, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap a6, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap a7, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s2, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s3, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s4, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s5, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s6, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s7, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s8, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s9, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s10,(c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap s11,(c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap t3, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap t4, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap t5, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE
    lw.cap t6, (c31)
    CIncOffsetImm c31, c31, WORD_SIZE

    CSetOffset c31, c31, zero

    mret

_trusted_trap_error:
    j _trusted_trap_error

    .text
_untrusted_trap_handler:

    beq t0, t1, _syscall_handler
    srli t1, t0, __riscv_xlen - 1
    bne t1, zero, _interrupt_handler
    j _unsupported_trap

_syscall_handler:
    jal syscall
    j _untrusted_trap_return

_interrupt_handler:
    slli a0, t0, 1
    srli a0, a0, 1
    jal isr
    j _untrusted_trap_return

_unsupported_trap:

_untrusted_trap_return:
    CJALR cra

    .data
_trap_stack:
    .space 1024
_trap_stack_top:
