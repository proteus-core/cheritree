#include "riscv_test.h"
#include "setup_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

//Similar tests to IsUnique, but now with the memory sweep for 2 capabilities

//Set up a few caps to test overlap with
ENCLAVE_CODE_SECTION(c5, enclave_code1, enclave_code1_end)
ENCLAVE_CODE_SECTION(c6, enclave_code2, enclave_code2_end)
ENCLAVE_CODE_SECTION(c7, enclave_code3, enclave_code3_end)

ENCLAVE_CODE_SECTION(c25, store_here, store_end)
ENCLAVE_CODE_SECTION(c26, overlap_1, overlap_1_end)
ENCLAVE_CODE_SECTION(c27, overlap_1_nomo, overlap_1_end)
ENCLAVE_DATA_SECTION(c28, enclave_data, enclave_data_end)

//Restrict PCC and DDC to avoid false positives
RESTRICT_DDC_PCC_JUMP(c1, _start, enclave_code1, continue)

continue:
  //Overlapping code and data region
	TEST_CASE_START(1)
    cmove c1, c5
    einitcode c1, c1
    SHOULD_FAIL(einitdata c5, c1, c5)

	//Code region containing *any* cap
	TEST_CASE_START(2)
    sc.cap c5, (c6)
    einitcode c6, c6
    SHOULD_FAIL(einitdata c7, c6, c7)

 //Register overlap with data
	TEST_CASE_START(3)
    einitcode c7, c7
    SHOULD_FAIL(einitdata c28, c7, c28)

  //Memory overlap
	TEST_CASE_START(4)
    cmove c26, c0
    sc.cap c7, (c25)
    SHOULD_FAIL(einitdata c28, c7, c28)

  //Internal ref no more overlap
	TEST_CASE_START(5)
 		sc.cap c0, (c25)
    sc.cap c7, (c28)
   	einitdata c28, c7, c28

  TEST_PASSFAIL

	.p2align 4
enclave_code1:
  .fill 16
enclave_code1_end:
enclave_code2:
	  .fill 16
enclave_code2_end:
enclave_code3:
  .fill 16
enclave_code3_end:

RVTEST_CODE_END

RVTEST_DATA_BEGIN
.p2align 4
enclave_data:
  .fill 16
  overlap_1:
  .fill 32
  overlap_1_nomo:
enclave_data_end:
  .fill 16
  overlap_1_end:
store_here:
  .fill 16
store_end:
RVTEST_DATA_END
