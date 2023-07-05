#include "riscv_test.h"
#include "test_macros_capattest.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

    # Start a test case before the init code because otherwise failures during
    # init will not fail the test
    TEST_CASE_FREE(1)

    INIT_CAPATTEST

    # ROOT=[enclave, ...)
    la s0, enclave
    CAP_SET_BASE(ROOT, ROOT, s0)

    # c1=[enclave, end_enclave), ROOT=[end_enclave, ...)
    la s1, end_enclave
    sub s2, s1, s0
    CAP_SPLIT(c1, ROOT, ROOT, s2)

    EInitCode c1, c1

    # ROOT=[enclave_data, ...)
    la s0, enclave_data
    CAP_SET_BASE(ROOT, ROOT, s0)

    # c2=[enclave_data, end_enclave_data), ROOT=[end_enclave_data, ...)
    la s1, end_enclave_data
    sub s2, s1, s0
    CAP_SPLIT(c2, ROOT, ROOT, s2)

    EInitData c2, c1, c2

    la t0, hash
    CSetAddr c3, ROOT, t0
    CGetType t1, c1
    EStoreId t2, t1, c3
    beq t2, zero, fail

    la t1, end_hash
    la t2, expected_hash
    CSetAddr c4, ROOT, t2

1:
    lw.cap t3, (c3)
    lw.cap t4, (c4)
    bne t3, t4, fail
    CIncOffsetImm c3, c3, 4
    CIncOffsetImm c4, c4, 4
    CGetAddr t0, c3
    blt t0, t1, 1b

    TEST_PASSFAIL
end_non_enclave_text:

enclave:
    .word 0x12345678
    .word 0xabcdef12
end_enclave:

RVTEST_CODE_END


    .data
    .align 8
enclave_data:
    .fill 256, 1, 0
end_enclave_data:

hash:
    .fill 32, 1, 0
end_hash:
expected_hash:
    .byte 0x28, 0xc1, 0xf6, 0x13, 0x69, 0xa8, 0x83, 0x13
    .byte 0xde, 0xe9, 0x55, 0x1a, 0xfc, 0x2b, 0x00, 0x47
    .byte 0xd2, 0x64, 0x40, 0x07, 0x48, 0x90, 0x1d, 0xcf
    .byte 0x7c, 0x9c, 0x7a, 0xef, 0xa6, 0xf4, 0xe4, 0x6c
end_expected_hash:
