/*
 ============================================================================
 Name        : test_ESTORE_ID.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : instruction testing
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
#include <EL2Code/instructions/hash.h>

//debug printing
#include <EL1Code/EL1Debug.h>//contains PRINTF_TO_UART_EL1 def so needs to come first
#ifdef PRINTF_TO_UART_EL1
#include <EL1Code/printf.h> //embedded printf function to redirect all printf in this file to uart
#endif
//output at EL1 to uart, some critical output is sent to the uart, even when debug switched off
#include <EL1Code/uartN_redirect.h> //non secure uart functions


extern bool ESTORE_ID(size_t any_otype, hashValType* memHash_cap);
extern void* EINIT_CODE(void* code_cap);
extern void* EINIT_DATA(void* sealed_code_cap, void* data_cap);

  //WARNING!
  //llvm doesn't seem to place "inline" in function, need to specify "static inline", or need a copy of definition without inline?
  //see https://clang.llvm.org/compatibility.html#inline
  //We know it is not inline because c0 to c4 can be cleared without affecting code and data cap
  //and c30 can not be cleared otherwise it messes up the return address from the function.
  //if the code is directly copied and placed in the function, the return address c30 can be cleared, but clearing lower
  //registers messes up the code and data cap going into the next asm block
  static inline void LOCATE_FUNC cheri_clear_all_gpcr3()
  {
  #define CLEAR_GPCR(gpcr) asm volatile("CLRTAG " #gpcr ", " #gpcr)

	CLEAR_GPCR(c0); //need to do c0 in Morello, c0 hard wired to zero in riscv
	CLEAR_GPCR(c1);
      	CLEAR_GPCR(c2);
      	CLEAR_GPCR(c3);
      	CLEAR_GPCR(c4);
      	CLEAR_GPCR(c5);
      	CLEAR_GPCR(c6);
      	CLEAR_GPCR(c7);
      	CLEAR_GPCR(c8);
      	CLEAR_GPCR(c9);
      	CLEAR_GPCR(c10);
      	CLEAR_GPCR(c11);
      	CLEAR_GPCR(c12);
      	CLEAR_GPCR(c13);
      	CLEAR_GPCR(c14);
      	CLEAR_GPCR(c15);
      	CLEAR_GPCR(c16);
      	CLEAR_GPCR(c17);
      	CLEAR_GPCR(c18);
      	CLEAR_GPCR(c19);
      	CLEAR_GPCR(c20);
      	CLEAR_GPCR(c21);
      	CLEAR_GPCR(c22);
      	CLEAR_GPCR(c23);
      	CLEAR_GPCR(c24);
      	CLEAR_GPCR(c25);
      	CLEAR_GPCR(c26);
      	CLEAR_GPCR(c27);
      	CLEAR_GPCR(c28);
      	CLEAR_GPCR(c29);
     	// CLEAR_GPCR(c30); //this is the return address
      	//CLEAR_GPCR(c31); there is not a gp c31 in Morello

      #undef CLEAR_GPCR
  }

//test function
//this function sets up a memory capability to store a hash value
//If working correctly ESTORE_ID will retrieve the hash from the
//table for a given otype and write it to the hash memory
//the before and after is displayed
int hashTest(void** code_cap, void** data_cap)
{

	void* sealed_code_cap;
	sealed_code_cap = *code_cap; //bound sealed code_cap

	void* sealed_data_cap;
	sealed_data_cap = *code_cap; //bound sealed data_cap

	//check initial code cap
	printcapabilityPar_EL1(*code_cap, "code_cap");
	//check initial data_cap
	printcapabilityPar_EL1(*data_cap, "data_cap");

	//-----------------------------------------
	//call instruction EINIT_CODE first to get sealed code_cap
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

	  	  			:[code_cap_out]"+r"	(sealed_code_cap)// this is &code_cap (address, so use store instruction)
	  	  			:[hvc_call_einitcode]"I" (HVC_EINITCODE), // (I - means immediate value)
					 [code_cap_in]"r"	(code_cap) //make read only for testing as don't want this to change, otherwise corrupts next test
					 : "c0"
	  	  			);


	//check if sealed_code_cap is a sealed capability
	printcapabilityPar_EL1(sealed_code_cap, "sealed_code_cap");
	bool result_code_sealed = cheri_is_sealed(sealed_code_cap);
	if (result_code_sealed == false) {printf("FAILED EINIT_CODE hashTest\n");}
	else {printf("PASS EINIT_CODE - got a sealed code cap\n");}


	//-----------------------------------------
	//call instruction EINIT_DATA
	//sealed_data_cap = EINIT_DATA(sealed_code_cap, data_cap);
    //------------------------------------------

		//   cheri_clear_all_gpcr3();

		   //clear return address separately
	    // #define CLEAR_GPCR(gpcr) asm volatile("CLRTAG " #gpcr ", " #gpcr)
		//   CLEAR_GPCR(c30);

			//--------------------------------------------------
			  	  //Test EINIT_DATA from EL1 through HVC
			  	  	asm volatile(
			  	  			//-------------------------------------
			  	  	    		// set up sealed code capability
			  	  	    		//-------------------------------------
			  	  		    	// move sealed code capability into first func arg c0
			  	  		    	"MOV c0, %x[code_cap_in]\n\t"
			  	  			// Clear the given code capability
			  	  			//"SC cnull, (%[code_cap_in])\n\t"//(riscv)
			  	  			//"STR xzr, [%x[code_cap_in]]\n\t" //dont do this for testing else can't get a fresh seal

			  	  		    	//-------------------------------------
			  	  		    	// set up data capability
			  	  		    	//-------------------------------------
			  	  		    	// Set ca1 (c1) to the enclave's data section
			  	  		    	//"LC ca1, (%[data_cap_in])\n\t"//(riscv)
			  	  		    	"LDR c1, [%x[data_cap_in]]\n\t"
			  	  		    	// Clear the data capability on the stack
			  	  		    	//"SC cnull, (%[data_cap_in])\n\t"//(riscv)
			  	  		    	//"STR xzr, [%x[data_cap_in]]\n\t"//dont do this for testing, else can't do later test


			  	  			//-------------------------------------
			  	  			//NEW EINIT_DATA INSTRUCTION TO GO HERE
			  	  			//-------------------------------------
			  	  			"HVC #%[hvc_call_einitdata]\n\t"

			  	  			//-------------------------------------
			  	  			// get sealed capability
			  	  			//-------------------------------------
			  	  			// Set ca1 (c1) to the enclave's data section
			  	  			//"LC ca1, (%[data_cap_in])\n\t"//(riscv)
			  	  			//"STR c0, [%x[code_cap_out]]\n\t"
			  	  		    	"MOV %x[data_cap_out], c0\n\t"

			  	  			:[data_cap_out]"+r"	(sealed_data_cap)			// this is data_cap (address, so use mov instruction)
							:[hvc_call_einitdata]"I" (HVC_EINITDATA), // (I - means immediate value)
							 [code_cap_in]"r"	(sealed_code_cap), //make read only for testing as don't want this to change, otherwise corrupts next test
							 [data_cap_in]"r"	(data_cap)	//make read only for testing as don't want this to change, otherwise corrupts next test
							  : "c0", "c1"
			  	  			);

			//check if sealed_data_cap is a sealed capability
			printcapabilityPar_EL1(sealed_data_cap, "sealed_data_cap");
			bool result_data_sealed = cheri_is_sealed(sealed_data_cap);
			if (result_data_sealed == false) {printf("FAILED EINIT_DATA hashTest\n");}
			else {printf("PASS EINIT_DATA - got a sealed data cap\n");}



    	//if id counter starts at 0 first value in table can be with otype 0,1,2,3
	//if id counter starts at 1 first value in table can be with otype 4,5,6,7
	//size_t any_otype = 0;
	size_t any_otype = 4;

	//create a space in memory to store the hash from the TCB table
    	//bound memory cap
	hashValType memHash_cap;
	setRandomHashVal(memHash_cap); //initialise to a hash value
	printcapabilityPar_EL1(memHash_cap, "memHash_cap");
	//printf("initialised hash in memory is: %llu\n", *((unsigned long long*)memHash_cap));

	//printf("initialised hash in memory is:\n");
	//for (int i=0; i<hashByteWidth; i++)
	//{printf(" 0x%lu",(unsigned long)memHash_cap[i]);}
	//printf("\n");

	//-----------------------------------------
	//call instruction ESTORE_ID
	//bool result_estore = ESTORE_ID(any_otype, memHash_cap);
    	//------------------------------------------

	bool result_estore = false; //initialise output result
	printf("result_estore before : %i\n", result_estore);

	//need to do this first - assign locally because the llvm asm compiler just can't
	//cope with doing a &
	hashValType* memHash_cap_addr=&memHash_cap;
	//--------------------------------------------------
	  	  //Test ESTORE_ID from EL1 through HVC
	  	  	asm volatile(
	  	  			//-------------------------------------
	  	  	    		// set up o-type
	  	  	    		//-------------------------------------
	  	  		    	// move o-type into first func arg x0
	  	  			//"B .\n\t"
	  	  		    	"MOV x0, %x[otype_in]\n\t"

	  	  		    	//-------------------------------------
	  	  		    	// set up memHash capability
	  	  		    	//-------------------------------------
	  	  		    	//"LDR c1, [%x[data_cap_in]]\n\t"
	  	  		    	// move hash address into second func arg c1
	  	  		    	"MOV c1, %x[hash_cap]\n\t"

	  	  			//-------------------------------------
	  	  			//NEW ESTORE_ID INSTRUCTION TO GO HERE
	  	  			//-------------------------------------
	  	  			"HVC #%[hvc_call_estoreid]\n\t"

	  	  			//-------------------------------------
	  	  			// get result out
	  	  			//-------------------------------------
	  	  		    	"MOV %x[result_out], x0\n\t"

	  	  			:[result_out]"+r"	(result_estore)			// this is a value, so use mov instruction)
					:[hvc_call_estoreid]"I" (HVC_ESTOREID), // (I - means immediate value)
					 [hash_cap]"r"	(memHash_cap_addr),
					 [otype_in]"r"	(any_otype)
					  : "c0", "c1"
	  	  			);

	printcapabilityPar_EL1(memHash_cap, "memHash_cap");
	//printf("new hash in memory is: %llu\n", *((unsigned long long*)memHash_cap));

	//printf("new hash in memory is:\n");
	//for (int i=0; i<hashByteWidth; i++)
	//{printf(" 0x%lu",(unsigned long)memHash_cap[i]);}
	//printf("\n");

	printf("result_estore after : %i\n", result_estore);

	//results

	if (result_code_sealed == false) {printf("FAILED EINIT_CODE hashTest\n");}
	else {printf("PASS EINIT_CODE hashTest - got a sealed code cap\n");}

	if (result_data_sealed == false) {printf("FAILED EINIT_DATA hashTest\n");}
	else {printf("PASS EINIT_DATA hashTest - got a sealed data cap\n");}

	if (result_estore == false) {printf("FAILED EStore_ID hashTest\n");}
	else {printf("PASS ESTORE_ID hashTest\n");}

	int result = result_code_sealed && result_data_sealed && result_estore;

	while(1);

	return result;
}


//main test function
int LOCATE_FUNC test_ESTORE_ID(void** code_cap, void** data_cap)
{
			//quick hash test to step through code and see it does the right checks
			//if working correctly a hash is taken from the table for the given otype
			//and placed in the hash memory
			//step through code to check
			printf("hashTest test\n");
			int result = hashTest(code_cap, data_cap);
			printf("Final test result : %c\n", result ? 'P' : 'F');

	return 0;
}
