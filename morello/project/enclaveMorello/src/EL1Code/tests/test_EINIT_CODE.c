/*
 ============================================================================
 Name        : test_EINIT_CODE.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : testing EINIT_CODE instruction from EL1 via HVC hypervisor calls
 ============================================================================
 */

//*****************************************
// DEFINES
//*****************************************
//Need to put all non secure code into non secure memory regions
//Attributes are used to define memory sections.
//The linker script places the memory sections into the correct regions.
//Note: Attributes can only be assigned to global variables and functions
#define LOCATE_FUNC  __attribute__((__section__(".NONSECUREsection_c_el1")))
#define LOCATE_STR  __attribute__((__section__(".NONSECUREStringSection_c_el1")))

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h> //to use bool/true/false

#include <cheriintrin.h>
//#include <cheri.h>

//program includes
#include <common/cheri_extra.h> //HVC calls

//debug printing
#include <EL1Code/EL1Debug.h>//contains PRINTF_TO_UART_EL1 def so needs to come first
#ifdef PRINTF_TO_UART_EL1
#include <EL1Code/printf.h> //embedded printf function to redirect all printf in this file to uart
#endif
//output at EL1 to uart, some critical output is sent to the uart, even when debug switched off
#include <EL1Code/uartN_redirect.h> //non secure uart functions



//similar to enclave_init
  int LOCATE_FUNC test_EINIT_CODE(void** code_cap)
    {


	//TEST_CASE_START(1)........................


	void* sealed_code_cap;
	sealed_code_cap = *code_cap; //bound sealed code_cap

	//check initial code cap
	printcapabilityPar_EL1(*code_cap, "code_cap");

	//-----------------------------------------
	//call instruction
	//sealed_code_cap = EINIT_CODE(code_cap);
    //------------------------------------------

	//--------------------------------------------------
	  	  //Test EINIT_CODE from EL1 through HVC
	  	  	asm volatile(
	  	  			//-------------------------------------
	  	  	    		// set up code capability
	  	  	    		//-------------------------------------
	  	  	        	//"LC ca0, (%[code_cap_in])\n\t"//(riscv)
	  	  	    		// Load code capability into first func arg c0
	  	  	    		// (set ca0 (c0) to the enclave's code section)
	  	  			"LDR c0, [%x[code_cap_in]]\n\t" /*put code cap in c0 */
	  	  			// Clear the given code capability
	  	  			//"SC cnull, (%[code_cap_in])\n\t"//(riscv)
	  	  			//"STR xzr, [%x[code_cap_in]]\n\t" //dont do this for testing else can't get a fresh seal

	  	  			//-------------------------------------
	  	  			//NEW EINIT_CODE INSTRUCTION TO GO HERE
	  	  			//-------------------------------------
	  	  			"HVC #%[hvc_call_einitcode]\n\t"

	  	  			//-------------------------------------
	  	  			// get sealed capability
	  	  			//-------------------------------------
	  	  			// Set ca1 (c1) to the enclave's data section
	  	  			//"LC ca1, (%[data_cap_in])\n\t"//(riscv)
	  	  			//"STR c0, [%x[code_cap_out]]\n\t"
	  	  		    	"MOV %x[code_cap_out], c0\n\t"

	  	  			:[code_cap_out]"+r"	(sealed_code_cap) // this is &code_cap (address, so use store instruction)
	  	  			:[hvc_call_einitcode]"I" (HVC_EINITCODE), // (I - means immediate value)
					 [code_cap_in]"r"	(code_cap) //make read only for testing as don't want this to change, otherwise corrupts next test
					 : "c0"
	  	  			);


	//check if sealed_code_cap is a sealed capability
	//printcapabilityPar(sealed_code_cap, "sealed_code_cap");
	bool result_code_sealed = cheri_is_sealed(sealed_code_cap);
	if (result_code_sealed == false) {printf("FAILED EINIT_CODE -not a sealed capability\n");}
	else {printf("PASS EINIT_CODE - got a sealed code cap\n");}
	size_t result_code_otype1 = cheri_type_get(sealed_code_cap);
	printf("o-type first seal: %lu\n",result_code_otype1);


	//to check the result:
	//the seal base address / otype field of code_cap_mod
	//counter(id) = 1
	//otype = id << 2 = 4
	//identSeal = otype + 2 = 6


	//TEST_CASE_START(2)...................
	//Initialize a second enclave and verify it got a fresh seal

    void* sealed_code_cap2;
	sealed_code_cap2 = *code_cap; //bound sealed code_cap first

	//check initial code cap
	printcapabilityPar_EL1(*code_cap, "code_cap");

	//-----------------------------------------
	//call instruction
	//sealed_code_cap2 = EINIT_CODE(code_cap);
	//------------------------------------------

	//--------------------------------------------------
		  	  //Test EINIT_CODE from EL1 through HVC
		  	  	asm volatile(
		  	  			//-------------------------------------
		  	  	    		// set up code capability
		  	  	    		//-------------------------------------
		  	  	        	//"LC ca0, (%[code_cap_in])\n\t"//(riscv)
		  	  	    		// Load code capability into first func arg c0
		  	  	    		// (set ca0 (c0) to the enclave's code section)
		  	  			"LDR c0, [%x[code_cap_in]]\n\t" /*put code cap in c0 */
		  	  			// Clear the given code capability
		  	  			//"SC cnull, (%[code_cap_in])\n\t"//(riscv)
		  	  			//"STR xzr, [%x[code_cap_in]]\n\t" //don't do for testing or can't do third test

		  	  			//-------------------------------------
		  	  			//NEW EINIT_CODE INSTRUCTION TO GO HERE
		  	  			//-------------------------------------
		  	  			"HVC #%[hvc_call_einitcode]\n\t"
		  	  			//-------------------------------------
		  	  			// get sealed capability
		  	  			//-------------------------------------
		  	  			// Set ca1 (c1) to the enclave's data section
		  	  			//"LC ca1, (%[data_cap_in])\n\t"//(riscv)
		  	  			//"STR c0, [%x[code_cap_out]]\n\t"
		  	  		    	"MOV %x[code_cap_out], c0\n\t"

		  	  			:[code_cap_out]"+r"	(sealed_code_cap2)// this is &code_cap (address, so use store instruction)
		  	  			:[hvc_call_einitcode]"I" (HVC_EINITCODE), // (I - means immediate value)
						 [code_cap_in]"r"	(code_cap) //make read only for testing as don't want this to change, otherwise corrupts next test
						 : "c0"
		  	  			);

	//check if sealed_code_cap is a sealed capability
	//printcapabilityPar(sealed_code_cap2, "sealed_code_cap2");
	bool result_code_sealed2 = cheri_is_sealed(sealed_code_cap2);
	if (result_code_sealed2 == false) {printf("FAILED EINIT_CODE \n");}
	else {printf("PASS EINIT_CODE - got a fresh sealed_code_cap\n");}
	size_t result_code_otype2 = cheri_type_get(sealed_code_cap2);
	printf("o-type second seal: %lu\n",result_code_otype2);

	if (result_code_otype2 > result_code_otype1) {printf("PASS EINIT_CODE - got a fresh seal\n");}
	else {printf("FAIL EINIT_CODE - fresh seal not correct!\n");}

	//to check the result:
	//the seal base address / otype field of code_cap_mod
	//counter(id) = 2
	//otype = id << 2 = 1000 = 8
	//identSeal = otype + 2 = 8 + 2 = 10


	//TEST_CASE_START(3)...................
	//check what happens if exceed number of enclaves 32
	printf("Check stops producing valid code_caps after 32 enclaves (index = 32) :\n");
	int idx;
	//start at two as done two previously already
	for(idx=2; idx < 36; idx++)
	{
		void* sealed_code_cap3;
		sealed_code_cap3 = *code_cap; //bound sealed code_cap first

		//-----------------------------------------
		//call instruction
		//code_cap_mod3 = EINIT_CODE(code_cap);
		//------------------------------------------

		//--------------------------------------------------
			  	  //Test EINIT_CODE from EL1 through HVC
			  	  	asm volatile(
			  	  			//-------------------------------------
			  	  	    		// set up code capability
			  	  	    		//-------------------------------------
			  	  	        	//"LC ca0, (%[code_cap_in])\n\t"//(riscv)
			  	  	    		// Load code capability into first func arg c0
			  	  	    		// (set ca0 (c0) to the enclave's code section)
			  	  			"LDR c0, [%x[code_cap_in]]\n\t" /*put code cap in c0 */
			  	  			// Clear the given code capability
			  	  			//"SC cnull, (%[code_cap_in])\n\t"//(riscv)
			  	  			//"STR xzr, [%x[code_cap_in]]\n\t" //don't do for testing or can't do third test

			  	  			//-------------------------------------
			  	  			//NEW EINIT_CODE INSTRUCTION TO GO HERE
			  	  			//-------------------------------------
			  	  			"HVC #%[hvc_call_einitcode]\n\t"

			  	  			//-------------------------------------
			  	  			// get sealed capability
			  	  			//-------------------------------------
			  	  			// Set ca1 (c1) to the enclave's data section
			  	  			//"LC ca1, (%[data_cap_in])\n\t"//(riscv)
			  	  			//"STR c0, [%x[code_cap_out]]\n\t"
			  	  		    	"MOV %x[code_cap_out], c0\n\t"

			  	  			:[code_cap_out]"+r"	(sealed_code_cap3)// this is &code_cap (address, so use store instruction)
			  	  			:[hvc_call_einitcode]"I" (HVC_EINITCODE), // (I - means immediate value)
							 [code_cap_in]"r"	(code_cap) //make read only for testing as don't want this to change, otherwise corrupts next test
							 : "c0"
			  	  			);



		//check otype and tag of new cap, see if exits out
		printf("index : %u\n", idx);
		printf("otype: 0x%lx, tag: 0x%i\n", cheri_type_get(sealed_code_cap3), cheri_tag_get(sealed_code_cap3));
	}

return 0;
}
