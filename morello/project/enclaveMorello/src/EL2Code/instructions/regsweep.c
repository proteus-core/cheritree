/*
 ============================================================================
 Name        : regsweep.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description :
 ============================================================================
 */
//*************************************************
// INCLUDES
//*************************************************
#include <common/capfuncs.h>
#include <common/cheri_extra.h>//CAP_LEN
#include <stdio.h>
#include <stdlib.h>

// Program defined headers
#include "cheriintrin.h"
#include <uartEL2N.h> 						// uart non secure functions
//************************************
// FUNCTIONS
//************************************

//int bounds_nonoverlap_check_twocap(void* cap1, void* cap2, void* capm)
int bounds_nonoverlap_check_twocap(ptraddr_t base1, size_t limit1, ptraddr_t base2, size_t limit2, void* capm)
{
	//-----------------------------------------------------
	//This function checks for non-overlaps between three capabilities
	//one capability from a memory location / register (capm) and two capabilities to check against
	//-----------------------------------------------------
	// Inputs:
	// cap1 - capability1 to check against memory /register
	// cap2 - capability2 to check against memory /register
	// capm - capability found in memory / register
	// if limit1 <= basem OR base1 >= limitm
	// AND ....
	// if limit2 <= basem OR base2 >= limitm
	// then all OK, else fail
	//Return:
	// 0 if no overlaps
	// -1 if overlap detected


	ptraddr_t basem; //cheri c doc says use vaddr_t(ptraddr_t)
	size_t lengthm; //cheri c doc says use size_t, so compatible with 32/64 bit architectures
	size_t limitm;


	basem = (ptraddr_t)cheri_base_get(capm); //return type is unsigned long int,so typecast to be sure compatible across architectures
	lengthm = (size_t)cheri_length_get(capm); //return type is unsigned long int, so typecast to size_t to be sure compatible across architectures
	limitm = basem + lengthm;

    if (((limit1 <= basem) || (base1 >= limitm)) && ((limit2 <= basem) || (base2 >= limitm)))
    {return 0;} //all ok, no overlaps
    else
    {return -1;} //else error, must be overlapping
}

//------------------------------------
//gpreg_sweep
// sweep of general purpose registers
//------------------------------------
// Inputs:
// code_cap
// data_cap
// stack pointer for where the registers are stored on the stack
//------------------------------------
int gpreg_sweep(void* code_cap, void* data_cap, void* cspReg)
{

	void* capReg; //copy of a general capability register
	int cspOffset = CAP_LEN; //offset to increment by on the stack
	int index; //index for register for loop
	_Bool reg_tag; //tag bit of register
	int numReg = 31; //number of registers on the stack (0 to 30)

	DG(int cap_counter=0;)//debug //number of capabilities counted in memory
	DG(printf("Doing sweep of general capability registers...........\n");)//debug
	DG(printcapabilityPar(code_cap, "code_cap");)//debug
	DG(printcapabilityPar(data_cap, "data_cap");)//debug
	DG(printcapabilityPar(cspReg, "cspReg");)//debug

	//get base and limit of code cap and data cap once only to save computation
	ptraddr_t base1; //cheri c doc says use vaddr_t(ptraddr_t)
	size_t length1; //cheri c doc says use size_t, so compatible with 32/64 bit architectures
	size_t limit1;

	ptraddr_t base2; //cheri c doc says use vaddr_t(ptraddr_t)
	size_t length2; //cheri c doc says use size_t, so compatible with 32/64 bit architectures
	size_t limit2;

	base1 = (ptraddr_t)cheri_base_get(code_cap); //return type is unsigned long int,so typecast to be sure compatible across architectures
	length1 = (size_t)cheri_length_get(code_cap); //return type is unsigned long int, so typecast to size_t to be sure compatible across architectures
	limit1 = base1 + length1;

	base2 = (ptraddr_t)cheri_base_get(data_cap); //return type is unsigned long int,so typecast to be sure compatible across architectures
	length2 = (size_t)cheri_length_get(data_cap); //return type is unsigned long int, so typecast to size_t to be sure compatible across architectures
	limit2 = base2 + length2;
	//----------------------------------------------------------------------------

	DG(int result[numReg];)

//the first two are code_cap(0) and data_cap(1)
 for (index = 0; index < (numReg); index++)
 {
	//get a single capability register off the stack
	asm volatile(
			"LDR %x[capReg_ass], [%x[cspReg_ass]]\n\t" //load from stack to get cap register details
			"GCVALUE x2, %x[cspReg_ass]\n\t" //csp for registers
			"ADD x2, x2, %x[cspoffset_ass]\n\t" //inc offset
			"SCVALUE %x[cspReg_ass], %x[cspReg_ass], x2\n\t" //update csp for registers
			: [cspReg_ass]"+r"   (cspReg), //csp for registers -in/outs
			  [capReg_ass]"+r"   (capReg) //capability register
			: [cspoffset_ass]"r"	(cspOffset) //offset of csp - in only
			: "x2", "cc" //clobber list
			  );

	DG(printf("index: %u\n", index);)//debug
	DG(printcapabilityPar(capReg, "capReg");)//debug
	DG(result[index]=0;)
	//ignore the first two registers as they are code cap and data cap
    if (index > 1)
    	{
    	//check tag bit of register contents
    	reg_tag = cheri_tag_get(capReg);

    	DG(printf("tag of reg content is: 0x%01x\n", reg_tag);)//debug
    	DG(if (reg_tag == 1) {cap_counter++;};)//debug //count number of capabilities found

		if (reg_tag == 1)
			{
			  if ((bounds_nonoverlap_check_twocap(base1, limit1, base2, limit2, capReg)) != 0)
				  {
				  	DG(printf ("\n Error! Overlapping capabilities found!!\n");)//debug print
					DG(printcapabilityPar(code_cap, "code_cap");)//debug print
					DG(printcapabilityPar(data_cap, "data_cap");)//debug print
					DG(printcapabilityPar(capReg, "capReg");)//debug print
					nDG(return -1;) //WHEN NOT IN DEBUG MODE EXIT STRAIGHT AWAY ON AN OVERLAP
				  	DG(result[index]=-1;)
				  } //overlap detected
    		} //tag check
    	}//index check
    else
    {
    	DG(printf ("Ignoring check as this is either code or data cap\n");)//debug print
		DG(printf ("Do not compare against self!\n");)//debug print
    }
  }//for loop do checks
  DG(printf("Number of capabilities counted in general capability registers: %d\n", cap_counter);)//debug print
  DG(for (index = 0; index < (numReg); index++)
   {
  DG(printf("gp Register sweep result %i: %i\n", index, result[index]);) //debug print
   })
  DG(printf("Register sweep complete OK.............\n");)//debug print
  return 0; //all ok, no overlap

}


//------------------------------------
//check_reg
// check register bounds against code and data capabilities
//------------------------------------
// Inputs:
// code_cap base and limit
// data_cap base and limit
// capability register
//------------------------------------
int check_reg(ptraddr_t base1, size_t limit1, ptraddr_t base2, size_t limit2, void* capReg)
{
	_Bool reg_tag; //tag bit of register

	DG(printcapabilityPar(capReg, "capReg");)//debug print

	//check tag bit of register contents
	reg_tag = cheri_tag_get(capReg);
	DG(printf("tag of reg content is: 0x%01x\n", reg_tag);)//debug print
    //if overlap return -1, else return 0
	if (reg_tag == 1)
	{
		if ((bounds_nonoverlap_check_twocap(base1, limit1, base2, limit2, capReg)) != 0)
		{
			DG(printf ("\n Error! Overlapping capabilities found!!\n");)//debug print
			//DG(printcapabilityPar(code_cap, "code_cap");)//debug print
			//DG(printcapabilityPar(data_cap, "data_cap");)//debug print
			//DG(printcapabilityPar(capReg, "capReg");)//debug print
			return -1;
		}//overlap
	} //tag check
	return 0; //else all ok, no overlap
}


//------------------------------------
//scrs_sweep
// check special capability registers
//------------------------------------
// Inputs to check against:
// code_cap
// data_cap
//------------------------------------
int scrs_sweep(void* code_cap, void* data_cap)
{

	void* capReg; //copy of a capability register
	_Bool reg_tag; //tag bit of register
	int result, result_ddc_el1, result_pcc, result_elr_el2, result_csp_el1, result_celr_el1, result_ctpidr_el1, result_cvbar_el1; //result from each register check


	//get base and limit of code cap and data cap once only to save computation
	ptraddr_t base1; //cheri c doc says use vaddr_t(ptraddr_t)
	size_t length1; //cheri c doc says use size_t, so compatible with 32/64 bit architectures
	size_t limit1;

	ptraddr_t base2; //cheri c doc says use vaddr_t(ptraddr_t)
	size_t length2; //cheri c doc says use size_t, so compatible with 32/64 bit architectures
	size_t limit2;

	base1 = (ptraddr_t)cheri_base_get(code_cap); //return type is unsigned long int,so typecast to be sure compatible across architectures
	length1 = (size_t)cheri_length_get(code_cap); //return type is unsigned long int, so typecast to size_t to be sure compatible across architectures
	limit1 = base1 + length1;

	base2 = (ptraddr_t)cheri_base_get(data_cap); //return type is unsigned long int,so typecast to be sure compatible across architectures
	length2 = (size_t)cheri_length_get(data_cap); //return type is unsigned long int, so typecast to size_t to be sure compatible across architectures
	limit2 = base2 + length2;
	//----------------------------------------------------------------------------

	//get a special register
	#define GETCAP_SCRS(scrs) asm volatile("MRS %x[capReg_ass]," #scrs "\n\t" :[capReg_ass]"+r"	(capReg) ::)
	//get PCC
	#define GETPCC_SCRS(scrs) asm volatile("ADR %x[capReg_ass], #0\n\t" :[capReg_ass]"+r"	(capReg) ::)

	DG(printf("Doing Special Register sweep .............\n");) //debug print

    DG(printf("Checking DDC_EL1 register...........\n");)//debug print
	GETCAP_SCRS(DDC_EL1); //DDC_EL1 into capReg
	result_ddc_el1 = check_reg(base1, limit1, base2, limit2, capReg);

	//this is the current PCC which will be EL2 exception pcc copied from cvbar_el2
	DG(printf("Checking current PCC register (exception to EL2 PCC)...........\n");)//debug print
	GETPCC_SCRS(PCC); //PCC into capReg
	result_pcc = check_reg(base1, limit1, base2, limit2, capReg);

	//this is the capability covering el1 pcc, the offset is the return address from the el2 exception
	//note this register could also contain el2 pcc when an exception is triggered by el2 (but does not run this bit of code then)
	DG(printf("Checking CELR_EL2 exception link register (return to EL1 PCC)...........\n");)//debug print
	GETCAP_SCRS(CELR_EL2); //PCC into capReg
	result_elr_el2 = check_reg(base1, limit1, base2, limit2, capReg);

	DG(printf("Checking CSP_EL1 dedicated stack pointer register...........\n");)//debug print
	GETCAP_SCRS(CSP_EL1); //CSP_EL1 into capReg
	result_csp_el1 = check_reg(base1, limit1, base2, limit2, capReg);

	//return address and pcc capability for exception taken to el1
	DG(printf("Checking CELR_EL1 exception link register...........\n");)//debug print
	GETCAP_SCRS(CELR_EL1); //CELR_EL1 into capReg
	result_celr_el1 = check_reg(base1, limit1, base2, limit2, capReg);

	DG(printf("Checking CTPIDR_EL1 thread register...........\n");)//debug print
	GETCAP_SCRS(CTPIDR_EL1); //CTPIDR_EL1 into capReg
	result_ctpidr_el1 = check_reg(base1, limit1, base2, limit2, capReg);

	//this becomes the pcc when taking an exception to el1
	DG(printf("Checking CVBAR_EL1 vector table register...........\n");)//debug print
	GETCAP_SCRS(CVBAR_EL1); //CVBAR_EL1 into capReg
	result_cvbar_el1 = check_reg(base1, limit1, base2, limit2, capReg);

	result= result_ddc_el1 || result_pcc || result_elr_el2 || result_csp_el1 || result_celr_el1 || result_ctpidr_el1 || result_cvbar_el1;
	DG(printf("Special Register sweep result : %c\n", result ? 'F' : 'P');) //debug print

	DG(printf("Special Register sweep result_ddc_el1 : %i\n", result_ddc_el1);) //debug print
	DG(printf("Special Register sweep result_pcc_el2_exception : %i\n", result_pcc);) //debug print
	DG(printf("Special Register sweep result_pcc_el1_return : %i\n", result_elr_el2);) //debug print
	DG(printf("Special Register sweep result_csp_el1: %i\n", result_csp_el1);) //debug print
	DG(printf("Special Register sweep result_celr_el1 : %i\n", result_celr_el1);) //debug print
	DG(printf("Special Register sweep result_ctpidr_el1: %i\n", result_ctpidr_el1);) //debug print
	DG(printf("Special Register sweep result_cvbar_el1: %i\n", result_cvbar_el1);) //debug print

	DG(printf("Special Register sweep complete.............\n");) //debug print
	return result*-1; //0 all ok no overlap, -1 overlap occured
}

//------------------------------------
//sweep
// do all sweep
//------------------------------------
// Inputs:
// code_cap
// data_cap
// stack pointer for where the general purpose registers are stored on the stack
//------------------------------------
int reg_sweep(void* code_cap, void* data_cap, void* cspReg)
{
	char mesgReadText1[8] = { 'E', 'R', 'R', 'O', 'R', 'R', '\0'};
	char mesgReadText2[8] = { ' ', 'O', 'L', 'A', 'P', '\0'};
	int result, result1, result2;

	DG(printf("DOING REGSWEEP ..................\n");)

	//check general capability registers
	result1 = gpreg_sweep(code_cap, data_cap, cspReg);

	//check SCRs: DDC_EL1, PCC(current - EL2 PCC), CELR_EL2(return PCC to EL1), CELR, CSP_EL1, CELR_EL1, CTPIDR_EL1, CVBAR_EL1
	result2 = scrs_sweep(code_cap, data_cap);

	result = (result1 || result2)*-1; //calc is 0 or 1, so multiply by -1 to signify error

	if (result == -1)
		{
			nDG(uartEL2NcapTransmitString(mesgReadText1);)
			nDG(uartEL2NcapTransmitString(mesgReadText2);)
			return -1;
		}

	DG(printf("REGSWEEP COMPLETE..................\n");)
	return 0;
}

int mem_sweep(void* code_cap,
                 void* data_cap,
                 void* EL1mem_cap)
{

        //---------------------------------------------
        //Load contents of memory at every location within EL1mem_cap
        //and first check to see if there is a valid tag bit
        //if valid tag bit, then do the following checks:
        //Need to do checks on both:
        // 1.code_cap against EL1mem_cap mem location capability
        // 2.data_cap against EL1mem_cap mem location capability
        // Note that need to discount check against mem location of code_cap
        //and data_cap themselves otherwise will return an error
        // Do same checks as above but with registers apart from the ones in question
        //--------------------------------------------
	   char mesgReadText1[8] = { 'E', 'R', 'R', 'O', 'R', 'M', '\0'};
	   char mesgReadText2[8] = { ' ', 'O', 'L', 'A', 'P', '\0'};
        //------------------------------------------------------------------------------------------
        // Memory Sweep
        //------------------------------------------------------------------------------------------

        DG(printf("DOING MEMORY SWEEP ..................\n");) //debug
		#define MEM_LOC_LEN CAP_LEN //each mem location 4 bytes long, but capabilities in memory are always 16 byte aligned
        _Bool mem_tag;

        size_t mem_len; //cheri c doc says use size_t, so compatible with 32/64 bit architectures
        unsigned long int mem_index;

        void** mem_cap_content; //we hypothesise that memory contents is a pointer, so need pointer to a pointer
        unsigned long int cap_counter=0; //number of capabilities counted in memory
        unsigned long int overlap_counter=0; //number of overlaps
        //check capabilities
        DG(printcapabilityPar(EL1mem_cap, "EL1mem_cap");) //debug //EL1 mem
        //DG(printcapabilityPar(code_cap, "code_cap");) //debug //code cap
        //DG(printcapabilityPar(data_cap, "data_cap");) //debug //data cap

        //get length of EL1 memory
        mem_len = cheri_length_get(EL1mem_cap);
        DG(printf("Size of memory to check in hex : 0x%lx\n", mem_len);) //debug
        DG(printf("Number of loops to do : %lu\n",(mem_len/MEM_LOC_LEN));) //debug
        DG(printf("Doing memory for loop.....................................\n");) //debug

		//**************get base and limit of code cap and data cap once only to save computation
		ptraddr_t base1; //cheri c doc says use vaddr_t(ptraddr_t)
		size_t length1; //cheri c doc says use size_t, so compatible with 32/64 bit architectures
		size_t limit1;

		ptraddr_t base2; //cheri c doc says use vaddr_t(ptraddr_t)
		size_t length2; //cheri c doc says use size_t, so compatible with 32/64 bit architectures
		size_t limit2;

		base1 = (ptraddr_t)cheri_base_get(code_cap); //return type is unsigned long int,so typecast to be sure compatible across architectures
		length1 = (size_t)cheri_length_get(code_cap); //return type is unsigned long int, so typecast to size_t to be sure compatible across architectures
		limit1 = base1 + length1;

		base2 = (ptraddr_t)cheri_base_get(data_cap); //return type is unsigned long int,so typecast to be sure compatible across architectures
		length2 = (size_t)cheri_length_get(data_cap); //return type is unsigned long int, so typecast to size_t to be sure compatible across architectures
		limit2 = base2 + length2;
		//*****----------------------------------------------------------------------------

        //EL1mem_cap points to first mem location
		//do for whole length of memory mem_len/MEM_LOC_LEN
		for (mem_index = 0; mem_index<= mem_len-MEM_LOC_LEN; mem_index=mem_index+MEM_LOC_LEN)
			{
				mem_cap_content = EL1mem_cap+mem_index;//point to memory location
				mem_tag = cheri_tag_get(*mem_cap_content); //check tag bit of memory location contents(we assume contents can be a capability)

				//debug print
		//		DG(printf("mem_index: %lu\n", mem_index);)//debug
				//DG(printcapabilityPar((EL1mem_cap+mem_index), "EL1mem_cap plus index");) //debug  //print location to load capability
				//DG(printcapabilityPar(code_cap, "code_cap");)//debug print
				//DG(printcapabilityPar(data_cap, "data_cap");)//debug print
		//		DG(printcapabilityPar((*mem_cap_content), "*mem_cap_content");) //debug  //print capability at that location
		//		DG(printf("memory location of capability mem content is: %p\n", mem_cap_content);) //debug
				//DG(printf("tag of mem content is: 0x%01x\n", mem_tag);) //debug

				DG(if (mem_tag == 1) {cap_counter++;};) //debug  //count number of capabilities found

				if (mem_tag == 1)
				{
					//DG(printcapabilityPar(code_cap, "code_cap");)//debug print
					//DG(printcapabilityPar(data_cap, "data_cap");)//debug print
					//DG(printcapabilityPar(*mem_cap_content, "*mem_cap_content");)//debug print
					//DG(printf("memory location of capability mem content is: %p\n", mem_cap_content);) //debug

                   if ((bounds_nonoverlap_check_twocap(base1, limit1, base2, limit2, *mem_cap_content)) != 0)
		    		{
						DG(printf ("\n Error! Overlapping capabilities found!!\n");)//debug print
		                DG(printf("mem_index: %lu\n", mem_index);)//debug
						//DG(printcapabilityPar(code_cap, "code_cap");)//debug print
						//DG(printcapabilityPar(data_cap, "data_cap");)//debug print
						DG(printcapabilityPar(*mem_cap_content, "*mem_cap_content");)//debug print
						DG(printf("memory location of capability mem content is: %p\n", mem_cap_content);) //debug
						//DG(printf ("\n Exiting Memory sweep!.............\n");)//debug print
						nDG(uartEL2NcapTransmitString(mesgReadText1);)
						nDG(uartEL2NcapTransmitString(mesgReadText2);)
						nDG(return -1;)//EXIT STRAIGHT AWAY IF NOT IN DEBUG MODE
						overlap_counter++;
						//DG(printf("Number of capabilities OVERLAPPING so far: %lu\n", overlap_counter);)//debug print
					} //overlap detected
				}
			} //for loop do checks
        //else all OK
        //DG(printf("Done for loop, no overlapping capabilities detected............\n");)//debug print
		//to speed up development only check to end of stack, as rest of memory unused
		//put warning here as a reminder
		DG(if (mem_index < 1073741824) {printf("\nwarning! - only doing minimal memory sweep. Check MEM_EL1N_AT_EL2N bounds if this was not intended.\n");})
		DG(printf("\nAmount of memory checked in EL1 memory (in bytes): %lu\n", mem_index);)//debug print
		DG(printf("Number of capability locations checked in EL1 memory: %lu\n", mem_index/MEM_LOC_LEN);)//debug print
		DG(printf("Number of capabilities OVERLAPPING in EL1 memory: %lu\n", overlap_counter);)//debug print
		DG(printf("Number of capabilities counted in EL1 memory: %lu\n", cap_counter);)//debug print
		DG(printf("Finished memory sweep successfully.....................................\n");)//debug print

		return (overlap_counter == 0) ? 0 : -1; //if overlap_counter is 0, return 0, else return -1

		//return 0;
}

int codeCap_sweep(void* code_cap)
{

        //---------------------------------------------
		//Verify code_cap does not contain any capabilities
        //Load contents of memory at every location within code_cap
        //and check to see if there is a valid tag bit, if there
		//is a valid tag bit, we need to fail the test.
        //--------------------------------------------
	   char mesgReadText1[8] = { 'E', 'R', 'R', 'O', 'R', 'C', '\0'};
	   char mesgReadText2[8] = { ' ', 'O', 'L', 'A', 'P', '\0'};

        DG(printf("Checking code_cap for capabilities ..................\n");) //debug
		#define MEM_LOC_LEN CAP_LEN //each mem location 4 bytes long, but capabilities in memory are always 16 byte aligned
        _Bool mem_tag;

        size_t mem_len; //cheri c doc says use size_t, so compatible with 32/64 bit architectures
        unsigned long int mem_index = 0;
        void** mem_cap_content; //we hypothesise that memory contents is a pointer/capability, so need pointer to a pointer
        unsigned long int cap_counter=0; //number of capabilities counted in memory

        //check capability
        //DG(printcapabilityPar(code_cap, "code_cap");) //debug //code cap

        //get length of code_cap memory
        mem_len = cheri_length_get(code_cap);
        DG(printf("Size of memory to check in hex : 0x%lx\n", mem_len);) //debug
        DG(printf("Number of loops to do : %lu\n",(mem_len/MEM_LOC_LEN));) //debug

		//check size of code_cap is at least big enough to contain a capability,
		//else is too small to check and will not contain one anyway
		if (mem_len >= MEM_LOC_LEN)
		{

        DG(printf("Doing memory for loop.....................................\n");) //debug

        //point to first mem location
		//do for whole length of memory mem_len/MEM_LOC_LEN
		for (mem_index = 0; mem_index<= mem_len-MEM_LOC_LEN; mem_index=mem_index+MEM_LOC_LEN)
			{
				mem_cap_content = code_cap+mem_index;//point to memory location
				mem_tag = cheri_tag_get(*mem_cap_content); //check tag bit of memory location contents(we assume contents can be a capability)
		//		DG(printf("mem_index: %lu\n", mem_index);)//debug
		//		DG(printcapabilityPar((*mem_cap_content), "*mem_cap_content");) //debug  //print capability at that location
		//		DG(printf("memory location of capability mem content is: %p\n", mem_cap_content);) //debug
				//DG(printf("tag of mem content is: 0x%01x\n", mem_tag);) //debug
				DG(if (mem_tag == 1) {cap_counter++;};) //debug  //count number of capabilities found

				if (mem_tag == 1)
				{
					DG(printf ("\n Error! capabilities found in code_cap!!\n");)//debug print
					DG(printf("mem_index: %lu\n", mem_index);)//debug
					DG(printcapabilityPar(*mem_cap_content, "*mem_cap_content");)//debug print
					DG(printf("memory location of capability mem content is: %p\n", mem_cap_content);) //debug
					nDG(uartEL2NcapTransmitString(mesgReadText1);)
					nDG(uartEL2NcapTransmitString(mesgReadText2);)
					nDG(return -1;) //DIRECT EXIT IN NON DEBUG MODE
				}
			} //for loop do checks
		} //code_cap size check
        //else all OK
        //DG(printf("Done for loop, no capabilities detected............\n");)//debug print
		DG(printf("\nAmount of memory checked in code_cap (in bytes): %lu\n", mem_index);)//debug print
		DG(printf("Number of potential capability locations checked: %lu\n", mem_index/MEM_LOC_LEN);)//debug print
		DG(printf("Number of capabilities DETECTED in code_cap: %lu\n", cap_counter);)//debug print
		DG(printf("Finished code_cap memory sweep successfully.....................................\n");)//debug print

		return (cap_counter == 0) ? 0 : -1; //if cap_counter is 0, return 0, else return -1
		//return 0;
}

int sweep(void* code_cap, void* data_cap, void* cspReg, void* EL1mem_cap)
{
	//register sweep
	int result_reg = reg_sweep(code_cap, data_cap, cspReg);
	//memory sweep
	int result_mem = mem_sweep(code_cap, data_cap, EL1mem_cap);
	//Verify code_cap does not contain any capabilities
	int result_codeSweep = codeCap_sweep(code_cap);

	int result= (result_reg || result_mem || result_codeSweep)*-1; //calc is 0 or 1, so multiply by -1 to signify error

	DG(printf("Final sweep result : %c\n", result ? 'F' : 'P');) //debug print

	return result;
}

