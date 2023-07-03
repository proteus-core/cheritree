#include "riscv_test.h"
#include "setup_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

ENCLAVE_CODE_SECTION(c5, enclave_code, enclave_code_end)
RESTRICT_DDC_PCC_JUMP(c7, _start, enclave_code, initcode)

// Call EInitCode
initcode:
    einitcode c5, c5

    // Not much to be tested here, other than checking if c6 contains a sealed cap
    cgetsealed x10, c5
    beq x10, x0, fail

    RVTEST_PASS

    fail:
        RVTEST_FAIL

// We won't call the enclave
enclave_code:
  .fill CAP_LEN
enclave_code_end:
RVTEST_CODE_END
