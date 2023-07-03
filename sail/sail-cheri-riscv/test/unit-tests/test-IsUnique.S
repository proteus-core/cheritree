#include "riscv_test.h"
#include "setup_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

//Set up a few caps to test overlap with
ENCLAVE_CODE_SECTION(c5, region_1, region_1_end)
ENCLAVE_CODE_SECTION(c6, overlap_1, overlap_1_end)
ENCLAVE_CODE_SECTION(c7, overlap_1_nomo, overlap_1_end)
ENCLAVE_CODE_SECTION(c31, store_here, store_end)

//Restrict PCC and DDC to avoid false positives
RESTRICT_DDC_PCC_JUMP(c1, _start, pcc_end, continue)

continue:
  //Register overlap
	TEST_CASE_START(1)
    IsUnique x8, c5
    bnez x8, fail

  //Memory overlap
	TEST_CASE_START(2)
    sc.cap c6, (c31)
  	cmove c6, c0
    IsUnique x8, c5
    bnez x8, fail

  //No more overlap
	TEST_CASE_START(3)
  	sc.cap c0, (c31)
    IsUnique x8, c5
    li x9, 1
    bne x8, x9, fail

  //Internal ref no more overlap
	TEST_CASE_START(4)
    sc.cap c5, (c5)
    IsUnique x8, c5
    li x9, 1
    bne x8, x9, fail

  TEST_PASSFAIL

pcc_end:

RVTEST_CODE_END

RVTEST_DATA_BEGIN

.p2align 4
region_1:
  .fill 16
overlap_1:
	.fill 32
overlap_1_nomo:
region_1_end:
  .fill 16
overlap_1_end:
store_here:
  .fill 16
store_end:

RVTEST_DATA_END
