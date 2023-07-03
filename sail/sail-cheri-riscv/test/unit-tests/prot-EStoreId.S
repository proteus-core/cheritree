#include "riscv_test.h"
#include "setup_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

    # Start a test case before the init code because otherwise failures during
    # init will not fail the test
    TEST_CASE_START(1)
	    ENCLAVE_CODE_SECTION(c1, enclave, end_enclave)
	    ENCLAVE_DATA_SECTION(c2, enclave_data, end_enclave_data)
	    ENCLAVE_CODE_SECTION(c30, hash, end_expected_hash)
	    RESTRICT_DDC_PCC_JUMP(c5, _start, end_non_enclave_text, initcode)


initcode:
    EInitCode c1, c1
    EInitData c2, c1, c2

    cmove c4, c30
    CGetType x6, c1
    EStoreId x7, x6, c4
    beq x7, zero, fail

    //Load relative offset of `end_hash` in x6
    la x6, hash
    la x7, end_hash
    sub x6, x7, x6

    LA_OTHER(c5, expected_hash, c30)

1:
    lw.cap x7, (c4)
    lw.cap x8, (c5)
    bne x7, x8, fail
    CIncOffsetImm c4, c4, 4
    CIncOffsetImm c5, c5, 4
    CGetOffset x7, c4
    blt x7, x6, 1b

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
