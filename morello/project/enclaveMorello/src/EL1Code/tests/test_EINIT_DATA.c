/*
 ============================================================================
 Name        : test_EINIT_DATA.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : testing EINIT_DATA instruction from EL1 via HVC hypervisor calls
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


  //WARNING!
  //llvm doesn't seem to place "inline" in function, need to specify "static inline", or need a copy of definition without inline?
  //see https://clang.llvm.org/compatibility.html#inline
  //We know it is not inline because c0 to c4 can be cleared without affecting code and data cap
  //and c30 can not be cleared otherwise it messes up the return address from the function.
  //if the code is directly copied and placed in the function, the return address c30 can be cleared, but clearing lower
  //registers messes up the code and data cap going into the next asm block
  static inline void LOCATE_FUNC cheri_clear_all_gpcr2()
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

//this test checks a sealed data cap is created and that the seal from
//the data section can be read back correctly as the EL1 code does.
//This is not the main test function. It is called below
void SEALTest(void** code_cap, void** data_cap)
{

	void* sealed_code_cap;
	sealed_code_cap = *code_cap; //bound sealed code_cap

	void* sealed_data_cap;
	sealed_data_cap = *data_cap; //bound sealed data_cap

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


	  // clear tag bits of all capability registers
	  //WARNING!
	  //llvm doesn't seem to place "inline" in function, need to specify "static inline", or need a copy of definition without inline?
	  //see https://clang.llvm.org/compatibility.html#inline
	  //We know it is not inline because c0 to c4 can be cleared without affecting code and data cap
	  //and c30 can not be cleared otherwise it messes up the return address from the function.
	  //if the code is directly copied and placed in this function, the return address c30 can be cleared, but clearing lower
	  //registers messes up the code and data cap going into the next asm block
	 //  cheri_clear_all_gpcr2();

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

	  	  			:[data_cap_out]"+r"	(sealed_data_cap) // this is data_cap (address, so use mov instruction)
					:[hvc_call_einitdata]"I" (HVC_EINITDATA), // (I - means immediate value)
					 [code_cap_in]"r"	(sealed_code_cap), //make read only for testing as don't want this to change, otherwise corrupts next test
					 [data_cap_in]"r"	(data_cap) //make read only for testing as don't want this to change, otherwise corrupts next test
					  : "c0", "c1"
	  	  			);

	//check if sealed_data_cap is a sealed capability
	printcapabilityPar_EL1(sealed_data_cap, "sealed_data_cap");
	bool result_data_sealed = cheri_is_sealed(sealed_data_cap);
	if (result_data_sealed == false) {printf("FAILED EINIT_DATA hashTest\n");}
	else {printf("PASS EINIT_DATA - got a sealed data cap\n");}

    //---------------------------------------------------------------------------
	//seals to check
	unsigned long int num1[2]; //2 elements, 8 bytes each
	num1[0] = 0;
	num1[1] = 0;
	unsigned long int num2[2]; //2 elements, 8 bytes each
	num2[0] = 0;
	num2[1] = 0;

	void* encCheck;
	void* signCheck;

	encCheck = &num1[0]; //bounded to 16 bytes
	signCheck = &num2[0]; //bounded to 16 bytes

	//check enc seal and sign seal are at start of data section
	//just use the unsealed data_cap
	//they are written together so need to separate back out like the main code at EL1 will do

	//Note:
	//The proteus core generates the signSeal as the otype with offset 0, and the encSeal with the otype with offset 1,
	//This is followed by the instruction code written here for EL2.
	//but when the seal capability is read in from the data section by enclave_init in enclave_entry.S,
	//the code is labelled as reading encSeal in first as the zero offset which is used for the sealing,
	//and signSeal as offset + 1, which is used for the unsealing. see asm test block below.

	asm volatile(//EXTRACT FROM enclave_entry.S, enclave_init:
			// # Load full enc/sign seal in ct0 (c9) from first capability at top of data section
			//WHERE IS C31 SET? - CInvoke,
			// lc.cap ct0, (c31) //(riscv) c31 is unsealed data capability from CInvoke
			//c9 points to first part of data section which is seal capability
			// ****GET TEST INPUT DATA_CAP*********
			//"B . \n\t"
			"MOV c2, %x[asm_data_cap]\n\t"
			"LDR c9, [c2]\n\t" //(Morello) c29 is unsealed data capability from BRS
			//----------------------------------------
		    	// create enc/sign seal
		    	//----------------------------------------
		    	//# Create public enc seal in ca0 (c0) as a return ARG: seal=base seal, perms=only seal
		    	//enc/sign seal is in ct0 (c9)//(riscv)
		    	//CSetBoundsImm ca0, ct0, 1//(riscv)
		    	//li t0, (1 << PERM_PERMIT_SEAL)//(riscv)
		    	//CAndPerm ca0, ca0, t0//(riscv)
		    	"MOV X13, #1\n\t" //(Immediate to reg first) //(Morello)
		    	"SCBNDSE c0, c9, x13\n\t" //(no immediate, reg only)//(Morello)
		    	// we need to remove all permissions except seal so need to invert
		    	//"ORN x13, xzr, #(0x1 << PERM_PERMIT_SEAL)\n\t"
			"ORN x13, xzr, #(0x1 << 11)\n\t"

			// *****CHECK C0 - ENC SEAL*******NOTE THIS SHOULD BE SIGN SEAL (4) ON FIRST ITERATION
		    	"CLRPERM c0, c0, x13\n\t" //(reduce permissions)

			//PUT BACK OUT TO CHECK
			"MOV %x[asm_sign_seal], c0\n\t"

		    	//# Create public sign seal in ca1 (c1) as a return ARG: seal=base seal+1, perms=only unseal
		    	//CIncOffsetImm ca1, ct0, 1//(riscv)
		    	//CSetBoundsImm ca1, ca1, 1//(riscv)
		    	//li t0, (1 << PERM_PERMIT_UNSEAL)//(riscv)
		    	//CAndPerm ca1, ca1, t0//(riscv)
		    	//inc offset
		    	"GCOFF x13, c9\n\t" //(get current offset)
		    	"ADD x13, x13, #1\n\t" //(add offset)
		    	"SCOFF c1, c9, x13\n\t" //(set offset)
		    	//set bounds
		    	"MOV X13, #1\n\t" //(Immediate to reg first) //(Morello)
		    	"SCBNDSE c1, c1, x13\n\t" //(no immediate, reg only)//(Morello)
		     	// we need to remove all permissions except unseal so need to invert
		    	//"ORN x13, xzr, #(0x1 << PERM_PERMIT_UNSEAL)\n\t"//(Morello)
			"ORN x13, xzr, #(0x1 << 10)\n\t"//(Morello)

			// *****CHECK C1 - SIGN SEAL **********NOTE THIS SHOULD BE ENC SEAL (5) ON FIRST ITERATION
		    	"CLRPERM c1, c1, x13 //(reduce permissions)\n\t"//(Morello)
			"MOV %x[asm_enc_seal], c1\n\t"

			: [asm_sign_seal]"+r" (signCheck), //outputs use MOV as not &
			  [asm_enc_seal]"+r" (encCheck)
			: [asm_data_cap]"r"	(*data_cap) //inputs data_cap, use LDR to get sign seal data_cap content
			: "c2", "c9", "c0", "c1", "x13", "cc", "memory"//clobber list
			);

	//To check for enclave when id = 0
	//check c0 reg -> enc seal -> otype + 1 -> id << 2 + 1 -> 0(count value) << 2 + 1 -> b001 -> 1dec
	//check c1 reg -> sign seal -> otype -> id << 2 -> 0(first count value) << 2 -> b000 -> 0dec

	//To check for enclave when id = 1
	//check c0 reg -> enc seal -> otype + 1 -> id << 2 + 1 -> 1(count value) << 2 + 1 -> b101 -> 5dec
	//check c1 reg -> sign seal -> otype -> id << 2 -> 1(first count value) << 2 -> b100 -> 4dec

	//To check for enclave when id = 2
	//check c0 reg -> enc seal -> otype + 1 -> id << 2 + 1 -> 2(count value) << 2 + 1 -> b1001 -> 9dec
	//check c1 reg -> sign seal -> otype -> id << 2 -> 1(first count value) << 2 -> b1000 -> 8dec

if (result_code_sealed == false) {printf("FAILED EINIT_CODE hashTest\n");}
else {printf("\n\nPASS EINIT_CODE - got a sealed code cap\n");}

if (result_data_sealed == false) {printf("FAILED EINIT_DATA hashTest\n");}
else {printf("PASS EINIT_DATA - got a sealed data cap\n");}

if (!((cheri_address_get(signCheck)==4) && (cheri_address_get(encCheck)==5)))	{printf("FAILED sign/enc seal test\n");}
else {printf("PASS EINIT_DATA - got two correct seals\n");}



return;

}




//main test function
int LOCATE_FUNC test_EINIT_DATA(void** code_cap, void** data_cap)
{

	int testNum = 1;

	switch(testNum)
	{
		case 1:
		{
			//test creates sealed data cap and can read back the seal from the data section as the EL1 code does.
			SEALTest(code_cap, data_cap);
			break;
		}
		default:
		{
			break;
		}
	}
	return 0;
}
