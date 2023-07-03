#include "riscv_test.h"
#include "setup_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

    TEST_CASE_START(1)

      ENCLAVE_CODE_SECTION(c1, enclave, end_enclave)

      cmove c2, c1
      EInitCode c2, c2

      # Not much can be tested here, other than checking if c2 contains a
      # sealed cap
      CGetSealed t0, c2
      beq t0, zero, fail

    TEST_CASE_START(2)

      # Initialize a second enclave and verify it got a fresh seal

      cmove c3, c1
      EInitCode c3, c3
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
