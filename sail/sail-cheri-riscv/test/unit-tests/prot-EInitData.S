#include "riscv_test.h"
#include "setup_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

    # Start a test case before the init code because otherwise failures during
    # init will not fail the test
    TEST_CASE_START(1)

    ENCLAVE_CODE_SECTION(c1, enclave, end_enclave)
    ENCLAVE_DATA_SECTION(c2, enclave_data, end_enclave_data)
    RESTRICT_DDC_PCC_JUMP(c5, _start, enclave, initcode)

initcode:
    EInitCode c1, c1
    EInitData c2, c1, c2
    CInvoke c1, c2
end_non_enclave_text:

enclave:
    lc.cap c5, (c31)
    CHECK_TAG(c5, 1)
    CHECK_LEN(c5, 4)
    CHECK_PERMS(c5, (1 << PERM_GLOBAL) | (1 << PERM_PERMIT_SEAL) | (1 << PERM_PERMIT_UNSEAL))

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
