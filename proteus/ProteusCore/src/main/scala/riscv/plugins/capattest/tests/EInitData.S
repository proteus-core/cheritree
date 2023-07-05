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

    # Remove execute permission because CInvoke doesn't allow it
    li t0, ~(1 << PERM_PERMIT_EXECUTE)
    CAndPerm c2, c2, t0

    EInitData c2, c1, c2

    CInvoke c1, c2
end_non_enclave_text:

enclave:
    lc.cap c3, (c31)
    CHECK_TAG(c3, 1)
    CHECK_LEN(c3, 2)
    CHECK_PERMS(c3, (1 << PERM_PERMIT_SEAL) | (1 << PERM_PERMIT_UNSEAL))

    # This has to be part of the enclave because otherwise, we cannot jump to
    # fail from the enclave.
    TEST_PASSFAIL
end_enclave:

RVTEST_CODE_END


    .data
    .align 8
enclave_data:
    .fill 256, 1, 0
end_enclave_data:
