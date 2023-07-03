#include "riscv_test.h"
#include "setup_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN


ENCLAVE_CODE_SECTION(c1, enclave, end_enclave)
ENCLAVE_DATA_SECTION(c2, enclave_data, enclave_data_end)
RESTRICT_DDC_PCC_JUMP(c5, _start, enclave, initcode)

// Call einitcode and einitdata and jump to enclave
initcode:
   	TEST_CASE_START(1)
      einitcode c1, c1

      // Try to access temporary entry using enter cap's otype
      cgettype x10, c1
      estoreid x12, x10, c0
      bnez x12, fail //Jumping to fail here causes an exception, which also causes failure

      // Finish and call enclave
      einitdata c2, c1, c2
      cinvoke c1, c2

RVTEST_CODE_END

.align 4
enclave:
	    // Load keys
	    lc.cap c5, (c31)

	    // Set up cap to store hash in c30
	    LA_OTHER(c30,hash,c31)

      // Point c31 to the expected hash
	    LA_OTHER(c29,expected_hash,c31)

	    //Load relative offset of `end_hash` in x6
	    la x6, enclave_data
	    la x7, end_hash
	    sub x6, x7, x6

      /////////////////////////////////////////////
      // Test retrieving the ID
      /////////////////////////////////////////////

      TEST_CASE_START(2)

      // We store the id in our own data section (c30) for convenience
      cgetaddr x10, c5
      estoreid x10, x10, c30
      beqz x10, fail // Should be 1

      1:
          lw.cap x7, (c30)
          lw.cap x8, (c29)
          bne x7, x8, fail
          CIncOffsetImm c30, c30, 4
          CIncOffsetImm c29, c29, 4
          CGetOffset x7, c30
          blt x7, x6, 1b

      TEST_PASSFAIL

end_enclave:

.data
.p2align 4
enclave_data:
	.fill CAP_LEN //reserve space for the seals
hash:
  .fill HASH_LEN //reserve space for final hash
end_hash:
expected_hash:
	//hash of code section will be written here during make
  .fill HASH_LEN
enclave_data_end:
