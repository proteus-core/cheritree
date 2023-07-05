#include "riscv_test.h"
#include "test_macros_cap.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

    INIT_ROOT_CAP

    # Make ddc overlap with MMIO regions so we can write to testdev but not
    # overlap with any code sections.
    li t0, 0x80000000
    CSetBoundsExact c1, ROOT, t0
    CSpecialW ddc, c1

    TEST_CASE_START(1)
        # Set-up code capability in c1
        la t0, enclave
        CSetAddr c1, ROOT, t0
        la t1, end_enclave
        sub t0, t1, t0 # Length
        CSetBoundsExact c1, c1, t0

        EInitCode c2, c1

        # Not much can be tested here, other than checking if c2 contains a
        # sealed cap
        CGetSealed t0, c2
        beq t0, zero, fail

    TEST_CASE_START(2)
        # Initialize a second enclave and verify it got a fresh seal
        EInitCode c3, c1
        CGetSealed t0, c3
        beq t0, zero, fail

        CGetType t0, c2
        CGetType t1, c3
        beq t0, t1, fail

    TEST_PASSFAIL

    enclave:
        .fill 8, 4, 0
    end_enclave:

RVTEST_CODE_END
