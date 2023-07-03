#include "riscv_test.h"
#include "setup_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

ENCLAVE_CODE_SECTION(c5, enclave_code, enclave_code_end)
ENCLAVE_DATA_SECTION(c6, enclave_data, enclave_data_end)
RESTRICT_DDC_PCC_JUMP(c7, _start, enclave_code, initcode)

// Call EInitCode
initcode:
    //linearity violation
   	SHOULD_FAIL(einitcode c6, c5)
    einitcode c5, c5

    //linearity violation
   	SHOULD_FAIL(einitdata c7, c5, c6)
    einitdata c6, c5, c6

    // Not much to be tested here, other than checking if c5 and c6 are sealed with corresponding keys
    cgettype x10, c5
    cgettype x11, c6
    bne x10, x11, fail
   //Check whether x10 is unsealed
    addi x10, x10, 1
    beqz x10, fail

    // Running einitcode or einitdata on a sealed capability should not work
    SHOULD_FAIL(einitcode c5, c5)
    SHOULD_FAIL(einitdata c6, c5, c6)

    RVTEST_PASS

    fail:
        RVTEST_FAIL

// We won't call the enclave
enclave_code:
  .fill 16
enclave_code_end:
RVTEST_CODE_END


RVTEST_DATA_BEGIN
.p2align 4
enclave_data:
  .fill CAP_LEN
enclave_data_end:
RVTEST_DATA_END
