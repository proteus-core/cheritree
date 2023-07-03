#include "riscv_test.h"
#include "setup_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

ENCLAVE_CODE_SECTION(c5, enclave_code, enclave_code_end)
ENCLAVE_DATA_SECTION(c6, enclave_data, enclave_data_end)
RESTRICT_DDC_PCC_JUMP(c7, _start, enclave_code, initcode)

// Call einitcode and einitdata and jump to enclave
initcode:
    einitcode c5, c5
    einitdata c6, c5, c6
    cinvoke c5, c6

.p2align 4
enclave_code:

    // Load keys into c7
    lc.cap c7, (c31)

    // Set up cap to store hash in c30
    LA_OTHER(c30,hash,c31)

    /////////////////////////////////////////////
    // Test EDeinit
    /////////////////////////////////////////////

    //1. Check existence of otypes pre-deinit
   	TEST_CASE_START(1)

      //Try to find the first otype
	    cgetaddr x13, c7
	    estoreid x14, x13, c30
	    beqz x14, fail

	  	//Try to find the last otype
	    addi x13, x13, 3
	    estoreid x14, x13, c30
	    beqz x14, fail

    //2. Deinitialize enclave
   	TEST_CASE_START(2)
    	edeinit x10, c7
	    beqz x10, fail

    //3. Retry looking up otypes; should no longer be found
   	TEST_CASE_START(3)

      //Try to find the last otype
	    estoreid x14, x13, c30
	    bnez x14, fail

      //Try to find the first otype
	    addi x13, x13, -3
	    estoreid x14, x13, c30
	    bnez x14, fail

    //Test has passed
    TEST_PASSFAIL

enclave_code_end:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.p2align 4
enclave_data:
.fill CAP_LEN //reserve space for the seals
hash:
    .fill HASH_LEN //32 bytes for the hash in 64-bit risc-v
enclave_data_end:
RVTEST_DATA_END
