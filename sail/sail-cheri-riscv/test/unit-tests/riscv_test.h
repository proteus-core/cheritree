#ifndef RISCV_TEST_H
#define RISCV_TEST_H

#include "encoding.h"
#include "setup_macros.h"

#define RVTEST_RV32U                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_RV64U                                                    \
  .macro init;                                                          \
  .endm

// Set up code such that exceptions are caught by the trap vector, at which point the handler jumps to fail
// Note: using mtvec_handler fails if it is not included in the bounds of PCC
// `_start` sets up mtvec to be maximally tight, to avoid overlap with the enclave
#define RVTEST_CODE_BEGIN                                               \
    .text;                                                              \
    .weak mtvec_handler;                                                \
    .globl _start;                                                      \
_start:                                                                 \
    ENCLAVE_INIT;                                                       \
    la tp, trap_vector;                                                 \
    la t0, start_tests;                                                 \
    cspecialr c1, pcc ;                                                 \
    sub t0, t0, tp    ;                                                 \
    csetoffset c1, c1, tp;                                              \
    csetboundsexact c1, c1, t0;                                         \
    cspecialw mtcc, c1;                                                 \
  	cmove c1, c0      ;                                                 \
    j start_tests;                                                      \
trap_vector:                                                            \
    la tp, mtvec_handler;                                               \
    cspecialr c1, pcc;                                                  \
    cgetbase t1, c1;                                                    \
    add t1, t1, tp;                                                     \
    beqz t1, 1f;                                                        \
    jr tp;                                                              \
1:  csrr t5, mcause;                                                    \
    li t6, CAUSE_MACHINE_ECALL;                                         \
    beq t5, t6, _exit;                                                  \
    RVTEST_REPORT_TESTNUM;                                              \
_exit:                                                                  \
    LA_PCC(c4, tohost);                                                 \
    sw.cap TESTNUM, (c4);                                               \
    j       _exit;                                                      \
.p2align 6; .global tohost; tohost: .dword 0;                           \
start_tests:

#define RVTEST_CODE_END                                                 \

#define TESTNUM gp

#define RVTEST_PASS                                                     \
    li  TESTNUM, 1;                                                     \
    ecall

#define RVTEST_REPORT_TESTNUM                                                     \
    bnez TESTNUM, 1f;                                                   \
    addi TESTNUM, TESTNUM, 1; /* If no TESTNUM has been set, this is implicitly defined as test 1 */ \
1:  sll TESTNUM, TESTNUM, 1;                                            \
    or TESTNUM, TESTNUM, 1;                                             \

#define RVTEST_FAIL \
    RVTEST_REPORT_TESTNUM ;\
    ecall

#define RVTEST_DATA_BEGIN                                               \
    .data;

#define RVTEST_DATA_END

//Initialize all special registers (except DDC/PCC) that do not contain the null capability in Sail's initial state
//Note that this unsets all exception handlers, and forces setting the necessary handlers manually after
//UEPCC and UTCC are not present unless the N-extension is active
#define ENCLAVE_INIT \
    cmove c1, c0; \
    cspecialw mepcc, c1 ;\
    cspecialw mtcc, c1 ;\
    cspecialw sepcc, c1; \
    cspecialw stcc, c1; \

//macros that depend on the concrete implementation being tested
#define CAP_LEN 16
#define HASH_LEN 32

#endif
